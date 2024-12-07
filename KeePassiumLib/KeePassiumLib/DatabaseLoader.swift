//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public protocol DatabaseLoaderDelegate: AnyObject {
    func databaseLoader(_ databaseLoader: DatabaseLoader, willLoadDatabase dbRef: URLReference)

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference)

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        with error: DatabaseLoader.Error)

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URLReference,
        databaseFile: DatabaseFile,
        withWarnings warnings: DatabaseLoadingWarnings)
}

public class DatabaseLoader: ProgressObserver {
    public enum Error: LocalizedError {
        case cancelledByUser
        case databaseUnreachable(_ reason: DatabaseUnreachableReason)
        case keyFileUnreachable(_ reason: KeyFileUnreachableReason)
        case permissionError(message: String)
        case emptyKey
        case invalidKey(message: String)
        case wrongFormat(fileFormat: CommonFileFormat)
        case unrecognizedFormat(hexSignature: String)
        case lowMemory
        case databaseError(reason: DatabaseError)
        case otherError(message: String)

        public var errorDescription: String? {
            switch self {
            case .cancelledByUser:
                return ProgressEx.CancellationReason.userRequest.localizedDescription
            case .databaseUnreachable(let reason):
                return reason.localizedDescription
            case .keyFileUnreachable(let reason):
                return reason.localizedDescription
            case .permissionError(let message):
                return message
            case .emptyKey:
                return LString.Error.needPasswordOrKeyFile
            case .invalidKey(let message):
                return message
            case .wrongFormat(let fileFormat):
                return String.localizedStringWithFormat(
                    LString.Error.incorrectDatabaseFormatTemplate,
                    fileFormat.description
                )
            case .unrecognizedFormat(let hexSignature):
                return String.localizedStringWithFormat(
                    LString.Error.incorrectDatabaseFormatTemplate,
                    hexSignature
                )
            case .lowMemory:
                return ProgressEx.CancellationReason.lowMemoryWarning.localizedDescription
            case .databaseError(let reason):
                return reason.localizedDescription
            case .otherError(let message):
                return message
            }
        }
        public var failureReason: String? {
            switch self {
            case .cancelledByUser:
                return nil
            case .databaseUnreachable(reason: let reason):
                return reason.failureReason
            case .keyFileUnreachable(reason: let reason):
                return reason.failureReason
            case .permissionError:
                return nil
            case .emptyKey:
                return nil
            case .invalidKey:
                return nil
            case .wrongFormat:
                return nil
            case .unrecognizedFormat:
                return nil
            case .lowMemory:
                return nil
            case .databaseError(reason: let reason):
                return reason.failureReason
            case .otherError:
                return nil
            }
        }

        public enum DatabaseUnreachableReason: LocalizedError {
            case cannotFindDatabaseFile(reason: FileAccessError)
            case cannotOpenDatabaseFile(reason: FileAccessError)

            public var errorDescription: String? {
                switch self {
                case .cannotFindDatabaseFile:
                    return LString.Error.cannotFindDatabaseFile
                case .cannotOpenDatabaseFile:
                    return LString.Error.cannotOpenDatabaseFile
                }
            }

            public var failureReason: String? {
                switch self {
                case .cannotFindDatabaseFile(let reason),
                     .cannotOpenDatabaseFile(let reason):
                    return reason.localizedDescription
                }
            }
        }

        public enum KeyFileUnreachableReason: LocalizedError {
            case cannotFindKeyFile(reason: FileAccessError)
            case cannotOpenKeyFile(reason: FileAccessError)

            public var errorDescription: String? {
                switch self {
                case .cannotFindKeyFile:
                    return LString.Error.cannotFindKeyFile
                case .cannotOpenKeyFile:
                    return LString.Error.cannotOpenKeyFile
                }
            }

            public var failureReason: String? {
                switch self {
                case .cannotFindKeyFile(let reason),
                     .cannotOpenKeyFile(let reason):
                    return reason.localizedDescription
                }
            }
        }
    }

    fileprivate enum ProgressSteps {
        static let all: Int64 = 100 
        static let willStart: Int64 = -1 
        static let didReadDatabaseFile: Int64 = -1 
        static let didReadKeyFile: Int64 = -1 
        static let willDecryptDatabase: Int64 = 0
        static let didDecryptDatabase: Int64 = 100

        static let willMakeBackup: Int64 = -1 
    }

    public weak var delegate: DatabaseLoaderDelegate?
    private let delegateQueue: DispatchQueue

    private let dbRef: URLReference
    private let compositeKey: CompositeKey
    public let status: DatabaseFile.Status
    public let timeout: Timeout

    private var isReadOnly: Bool {
        status.contains(.readOnly)
    }

    private let warnings: DatabaseLoadingWarnings

    private let operationQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.keepassium.DatabaseLoader"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()

    private var startTime: Date?

    public init(
        dbRef: URLReference,
        compositeKey: CompositeKey,
        status: DatabaseFile.Status,
        timeout: Timeout,
        delegate: DatabaseLoaderDelegate,
        delegateQueue: DispatchQueue = .main
    ) {
        assert(compositeKey.state != .empty)
        self.dbRef = dbRef
        self.compositeKey = compositeKey.clone()
        self.status = status
        self.timeout = timeout
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        self.warnings = DatabaseLoadingWarnings()

        let progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = ProgressSteps.willStart
        super.init(progress: progress)
    }

    private func initDatabase(signature data: ByteArray) -> Database? {
        if Database1.isSignatureMatches(data: data) {
            Diag.info("DB signature: KDB")
            return Database1()
        } else if Database2.isSignatureMatches(data: data) {
            Diag.info("DB signature: KDBX")
            return Database2()
        } else {
            Diag.info("DB signature: no match")
            return nil
        }
    }


    private var backgroundTask: UIBackgroundTaskIdentifier?
    private func startBackgroundTask() {
        guard let appShared = AppGroup.applicationShared else { return }

        print("Starting background task")
        backgroundTask = appShared.beginBackgroundTask(withName: "DatabaseLoading") {
            Diag.warning("Background task expired, loading cancelled")
            self.progress.cancel()
            self.endBackgroundTask()
        }
        startTime = Date.now
    }

    private func endBackgroundTask() {
        guard let appShared = AppGroup.applicationShared else { return }
        if let startTime = startTime {
            let duration = Date.now.timeIntervalSince(startTime)
            print(String(format: "Done in %.2f s", arguments: [duration]))
        }

        guard let bgTask = backgroundTask else { return }
        print("ending background task")
        backgroundTask = nil
        appShared.endBackgroundTask(bgTask)
    }


    public func cancel(reason: ProgressEx.CancellationReason) {
        progress.cancel(reason: reason)
    }

    override func progressDidChange(progress: ProgressEx) {
        notifyDidChangeProgress(progress)
    }


    public func load() {
        operationQueue.addOperation { [self] in
            self.loadInBackgroundQueue()
        }
    }

    private func loadInBackgroundQueue() {
        assert(!Thread.isMainThread)
        Diag.info("Will load database [location: \(dbRef.location), fileProvider: \(dbRef.fileProvider?.rawValue ?? "nil")]")
        startBackgroundTask()
        startObservingProgress()
        notifyWillLoadDatabase()
        progress.status = LString.Progress.contactingStorageProvider
        dbRef.resolveAsync(timeout: timeout, callbackQueue: operationQueue) { result in 
            switch result {
            case .success(let dbURL):
                self.onDatabaseURLResolved(url: dbURL, fileProvider: self.dbRef.fileProvider)
            case .failure(let accessError):
                self.onDatabaseURLResolveError(accessError)
            }
        }
    }

    private func onDatabaseURLResolveError(_ error: FileAccessError) {
        Diag.error("Failed to resolve database URL reference [error: \(error.localizedDescription)]")
        stopObservingProgress()
        notifyDidFailLoading(with: .databaseUnreachable(.cannotFindDatabaseFile(reason: error)))
        endBackgroundTask()
    }

    private func onDatabaseURLResolved(url: URL, fileProvider: FileProvider?) {
        assert(operationQueue.isCurrent)
        progress.status = LString.Progress.loadingDatabaseFile
        FileDataProvider.read(
            url,
            fileProvider: fileProvider,
            queue: operationQueue,
            timeout: timeout,
            completionQueue: operationQueue,
            completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let docData):
                    self.onDatabaseDocumentReadComplete(data: docData, fileURL: url, fileProvider: fileProvider)
                case .failure(let fileAccessError):
                    Diag.error("Failed to open database document [error: \(fileAccessError.localizedDescription)]")
                    self.stopAndNotify(
                        .databaseUnreachable(.cannotOpenDatabaseFile(reason: fileAccessError))
                    )
                }
            }
        )
    }

    private func onDatabaseDocumentReadComplete(
        data: ByteArray,
        fileURL: URL,
        fileProvider: FileProvider?
    ) {
        assert(operationQueue.isCurrent)
        progress.completedUnitCount = ProgressSteps.didReadDatabaseFile

        guard let db = initDatabase(signature: data) else {
            let fileSignature = data.prefix(8)
            if let wrongFormat = FileFormatRecognizer.recognize(fileSignature) {
                Diag.error("Wrong file format, not a database [looksLike: \(wrongFormat.description)]")
                stopAndNotify(.wrongFormat(fileFormat: wrongFormat))
            } else {
                let hexPrefix = fileSignature.asHexString
                Diag.error("Unrecognized database format [firstBytes: \(hexPrefix)]")
                stopAndNotify(.unrecognizedFormat(hexSignature: hexPrefix))
            }
            return
        }

        let dbFile = DatabaseFile(
            database: db,
            data: data,
            fileURL: fileURL,
            fileReference: dbRef,
            status: status
        )
        guard compositeKey.state == .rawComponents else {

            progress.completedUnitCount = ProgressSteps.didReadKeyFile
            Diag.info("Using a ready composite key")
            onCompositeKeyComponentsProcessed(dbFile: dbFile, compositeKey: compositeKey)
            return
        }

        guard let keyFileRef = compositeKey.keyFileRef else {
            onKeyFileDataReady(dbFile: dbFile, keyFileData: SecureBytes.empty())
            return
        }

        Diag.debug("Loading key file")
        progress.localizedDescription = LString.Progress.loadingKeyFile
        keyFileRef.resolveAsync(timeout: timeout, callbackQueue: operationQueue) { result in 
            switch result {
            case .success(let keyFileURL):
                self.onKeyFileURLResolved(
                    url: keyFileURL,
                    fileProvider: keyFileRef.fileProvider,
                    dbFile: dbFile)
            case .failure(let accessError):
                self.onKeyFileURLResolveError(accessError)
            }
        }
    }

    private func onKeyFileURLResolveError(_ error: FileAccessError) {
        Diag.error("Failed to resolve key file URL reference [error: \(error.localizedDescription)]")
        stopAndNotify(.keyFileUnreachable(.cannotFindKeyFile(reason: error)))
    }

    private func onKeyFileURLResolved(url: URL, fileProvider: FileProvider?, dbFile: DatabaseFile) {
        assert(operationQueue.isCurrent)
        FileDataProvider.read(
            url,
            fileProvider: fileProvider,
            queue: operationQueue,
            timeout: timeout,
            completionQueue: operationQueue,
            completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let docData):
                    self.onKeyFileDataReady(dbFile: dbFile, keyFileData: SecureBytes.from(docData))
                case .failure(let fileAccessError):
                    Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                    self.stopAndNotify(
                        .keyFileUnreachable(.cannotOpenKeyFile(reason: fileAccessError))
                    )
                }
            }
        )
    }

    private func onKeyFileDataReady(dbFile: DatabaseFile, keyFileData: SecureBytes) {
        assert(operationQueue.isCurrent)
        progress.completedUnitCount = ProgressSteps.didReadKeyFile
        let keyHelper = dbFile.database.keyHelper
        let passwordData = keyHelper.getPasswordData(password: compositeKey.password)
        if passwordData.isEmpty && keyFileData.isEmpty && compositeKey.challengeHandler == nil {
            Diag.error("Both password and key file are empty")
            stopObservingProgress()
            notifyDidFailLoading(with: .emptyKey)
            endBackgroundTask()
            return
        }
        compositeKey.setProcessedComponents(passwordData: passwordData, keyFileData: keyFileData)
        onCompositeKeyComponentsProcessed(dbFile: dbFile, compositeKey: compositeKey)
    }

    private func addFileLocationWarnings(to warnings: DatabaseLoadingWarnings) {
        let isFallbackFile = status.contains(.localFallback)
        if dbRef.location == .internalBackup && !isFallbackFile {
            let issue = DatabaseLoadingWarnings.IssueType.temporaryBackupDatabase
            warnings.addIssue(issue)
            Diag.warning(warnings.getDescription(for: issue))
        }

        guard let dbFileInfo = dbRef.getCachedInfoSync(canFetch: false) else {
            Diag.warning("Could not refresh file info, some warnings might be missing")
            return
        }
        if dbFileInfo.isInTrash {
            let issue = DatabaseLoadingWarnings.IssueType
                .databaseFileIsInTrash(fileName: dbFileInfo.fileName)
            warnings.addIssue(issue)
            Diag.warning(warnings.getDescription(for: issue))
        }
    }

    func onCompositeKeyComponentsProcessed(dbFile: DatabaseFile, compositeKey: CompositeKey) {
        assert(operationQueue.isCurrent)
        assert(compositeKey.state >= .processedComponents)

        progress.completedUnitCount = ProgressSteps.willDecryptDatabase
        let remainingUnitCount = ProgressSteps.didDecryptDatabase - ProgressSteps.willDecryptDatabase
        do {
            let db = dbFile.database
            progress.addChild(db.initProgress(), withPendingUnitCount: remainingUnitCount)
            Diag.info("Loading database")
            try db.load(
                dbFileName: dbFile.visibleFileName,
                dbFileData: dbFile.data,
                compositeKey: compositeKey,
                useStreams: dbFile.status.contains(.useStreams),
                warnings: warnings)
            Diag.info("Database loaded OK")

            addFileLocationWarnings(to: warnings)

            performAfterLoadTasks(dbFile)

            progress.completedUnitCount = ProgressSteps.all
            progress.localizedDescription = LString.Progress.done
            stopObservingProgress()
            notifyDidLoadDatabase(databaseFile: dbFile, warnings: warnings)
            endBackgroundTask()
        } catch let error as DatabaseError {
            dbFile.erase()
            switch error {
            case .loadError:
                Diag.error("""
                        Database load error. [
                            isCancelled: \(progress.isCancelled),
                            message: \(error.localizedDescription),
                            reason: \(String(describing: error.failureReason))]
                    """)
                stopAndNotify(.databaseError(reason: error))
            case .invalidKey:
                Diag.error("Invalid master key. [message: \(error.localizedDescription)]")
                stopAndNotify(.invalidKey(message: error.localizedDescription))
            case .saveError:
                Diag.error("saveError while loading?!")
                fatalError("Database saving error while loading?!")
            }
        } catch let error as ProgressInterruption {
            dbFile.erase()
            switch error {
            case .cancelled(let reason):
                Diag.info("Database loading was cancelled. [reason: \(reason.localizedDescription)]")
                switch reason {
                case .userRequest:
                    stopAndNotify(.cancelledByUser)
                case .lowMemoryWarning:
                    stopAndNotify(.lowMemory)
                }
            }
        } catch {
            assertionFailure("Unprocessed exception")
            dbFile.erase()
            Diag.error("Unexpected error [message: \(error.localizedDescription)]")
            stopAndNotify(.otherError(message: error.localizedDescription))
        }
    }

    private func performAfterLoadTasks(_ dbFile: DatabaseFile) {
        assert(operationQueue.isCurrent)
        maybeUpdateLatestBackup(dbFile)

        let dbSettingsManager = DatabaseSettingsManager.shared
        if dbSettingsManager.isQuickTypeEnabled(dbFile),
           !dbFile.status.contains(.localFallback)
        {
            let quickTypeDatabaseCount = dbSettingsManager.getQuickTypeDatabaseCount()
            let isReplaceExisting = quickTypeDatabaseCount == 1
            Diag.debug("Updating QuickType AutoFill records [replacing: \(isReplaceExisting)]")
            QuickTypeAutoFillStorage.saveIdentities(
                from: dbFile,
                replaceExisting: isReplaceExisting
            )
        }
    }

    private func maybeUpdateLatestBackup(_ dbFile: DatabaseFile) {
        assert(operationQueue.isCurrent)
        let shouldUpdateBackup = Settings.current.isBackupDatabaseOnLoad
            && DatabaseManager.shouldBackupFiles(from: dbRef.location)
        if shouldUpdateBackup {
            Diag.debug("Updating latest backup")
            progress.completedUnitCount = ProgressSteps.willMakeBackup
            progress.status = LString.Progress.makingDatabaseBackup
            FileKeeper.shared.makeBackup(
                nameTemplate: dbFile.visibleFileName,
                mode: .renameLatest,
                contents: dbFile.data)
        }
    }

    private func stopAndNotify(_ error: DatabaseLoader.Error) {
        stopObservingProgress()
        defer {
            endBackgroundTask()
        }
        guard progress.isCancelled else {
            notifyDidFailLoading(with: error)
            return
        }
        switch progress.cancellationReason {
        case .userRequest:
            notifyDidFailLoading(with: .cancelledByUser)
        case .lowMemoryWarning:
            notifyDidFailLoading(with: .lowMemory)
        }
    }
}

extension DatabaseLoader {
    private func notifyWillLoadDatabase() {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(self, willLoadDatabase: self.dbRef)
        }
    }

    private func notifyDidChangeProgress(_ progress: ProgressEx) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(self, didChangeProgress: progress, for: self.dbRef)
        }
    }

    private func notifyDidFailLoading(with error: Error) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(
                self,
                didFailLoading: self.dbRef,
                with: error
            )
        }
    }

    private func notifyDidLoadDatabase(
        databaseFile: DatabaseFile,
        warnings: DatabaseLoadingWarnings
    ) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(
                self,
                didLoadDatabase: self.dbRef,
                databaseFile: databaseFile,
                withWarnings: warnings
            )
        }
    }
}
