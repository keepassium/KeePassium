//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
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
    
    func databaseLoader(_ databaseLoader: DatabaseLoader, didCancelLoading dbRef: URLReference)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        withInvalidMasterKeyMessage message: String)

    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        message: String,
        reason: String?)
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URLReference,
        databaseFile: DatabaseFile,
        withWarnings warnings: DatabaseLoadingWarnings)
}

public class DatabaseLoader: ProgressObserver {
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
        delegate: DatabaseLoaderDelegate,
        delegateQueue: DispatchQueue = .main
    ) {
        assert(compositeKey.state != .empty)
        self.dbRef = dbRef
        self.compositeKey = compositeKey.clone()
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
        Diag.info("Will load database [fileProvider: \(dbRef.fileProvider?.rawValue ?? "nil")]")
        startBackgroundTask()
        startObservingProgress()
        notifyWillLoadDatabase()
        progress.status = LString.Progress.contactingStorageProvider
        dbRef.resolveAsync(callbackQueue: operationQueue) { result in 
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
        notifyDidFailLoading(
            message: LString.Error.cannotFindDatabaseFile,
            reason: error.localizedDescription
        )
        endBackgroundTask()
    }
    
    private func onDatabaseURLResolved(url: URL, fileProvider: FileProvider?) {
        progress.status = LString.Progress.loadingDatabaseFile
        BaseDocument.read(url, queue: operationQueue, completionQueue: operationQueue) {
            [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                self.onDatabaseDocumentReadComplete(data: docData, fileURL: url, fileProvider: fileProvider)
            case .failure(let fileAccessError):
                Diag.error("Failed to open database document [error: \(fileAccessError.localizedDescription)]")
                self.stopObservingProgress()
                if self.progress.isCancelled {
                    self.notifyDidCancelLoading()
                } else {
                    self.notifyDidFailLoading(
                        message: LString.Error.cannotOpenDatabaseFile,
                        reason: fileAccessError.localizedDescription
                    )
                }
                self.endBackgroundTask()
            }
        }
    }
    
    private func onDatabaseDocumentReadComplete(
        data: ByteArray,
        fileURL: URL,
        fileProvider: FileProvider?
    ) {
        progress.completedUnitCount = ProgressSteps.didReadDatabaseFile
        
        guard let db = initDatabase(signature: data) else {
            let hexPrefix = data.prefix(8).asHexString
            Diag.error("Unrecognized database format [firstBytes: \(hexPrefix)]")
            if hexPrefix == "7b226572726f7222" {
                let fullResponse = String(data: data.asData, encoding: .utf8) ?? "nil"
                Diag.debug("Full error content for DS file: \(fullResponse)")
            }
            stopObservingProgress()
            if progress.isCancelled {
                self.notifyDidCancelLoading()
            } else {
                self.notifyDidFailLoading(
                    message: LString.Error.unrecognizedDatabaseFormat,
                    reason: nil
                )
            }
            endBackgroundTask()
            return
        }
        
        let dbFile = DatabaseFile(
            database: db,
            data: data,
            fileURL: fileURL,
            fileReference: dbRef
        )
        guard compositeKey.state == .rawComponents else {
            
            progress.completedUnitCount = ProgressSteps.didReadKeyFile
            Diag.info("Using a ready composite key")
            onCompositeKeyComponentsProcessed(dbFile: dbFile, compositeKey: compositeKey)
            return
        }
        
        guard let keyFileRef = compositeKey.keyFileRef else {
            onKeyFileDataReady(dbFile: dbFile, keyFileData: ByteArray())
            return
        }
        
        Diag.debug("Loading key file")
        progress.localizedDescription = LString.Progress.loadingKeyFile
        keyFileRef.resolveAsync { result in 
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
        stopObservingProgress()
        if progress.isCancelled {
            notifyDidCancelLoading()
        } else {
            notifyDidFailLoading(
                message: LString.Error.cannotFindKeyFile,
                reason: error.localizedDescription
            )
        }
        endBackgroundTask()
    }
    
    private func onKeyFileURLResolved(url: URL, fileProvider: FileProvider?, dbFile: DatabaseFile) {
        let keyDoc = BaseDocument(fileURL: url, fileProvider: fileProvider)
        keyDoc.open(queue: operationQueue, completionQueue: operationQueue) {
            [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                self.onKeyFileDataReady(dbFile: dbFile, keyFileData: docData)
            case .failure(let fileAccessError):
                Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                self.stopObservingProgress()
                if self.progress.isCancelled {
                    self.notifyDidCancelLoading()
                } else {
                    self.notifyDidFailLoading(
                        message: LString.Error.cannotOpenKeyFile,
                        reason: fileAccessError.localizedDescription
                    )
                }
                self.endBackgroundTask()
            }
        }
    }
    
    private func onKeyFileDataReady(dbFile: DatabaseFile, keyFileData: ByteArray) {
        progress.completedUnitCount = ProgressSteps.didReadKeyFile
        let keyHelper = dbFile.database.keyHelper
        let passwordData = keyHelper.getPasswordData(password: compositeKey.password)
        if passwordData.isEmpty && keyFileData.isEmpty && compositeKey.challengeHandler == nil {
            Diag.error("Both password and key file are empty")
            stopObservingProgress()
            notifyDidFailLoading(withInvalidMasterKeyMessage: LString.Error.needPasswordOrKeyFile)
            endBackgroundTask()
            return
        }
        compositeKey.setProcessedComponents(passwordData: passwordData, keyFileData: keyFileData)
        onCompositeKeyComponentsProcessed(dbFile: dbFile, compositeKey: compositeKey)
    }
    
    private func addFileLocationWarnings(to warnings: DatabaseLoadingWarnings) {
        guard let dbFileInfo = dbRef.getCachedInfoSync(canFetch: false) else {
            return
        }
        
        if dbFileInfo.isInTrash {
            warnings.addIssue(.databaseFileIsInTrash(fileName: dbFileInfo.fileName))
        }
        if dbRef.location == .internalBackup {
            let issue = DatabaseLoadingWarnings.IssueType.temporaryBackupDatabase
            warnings.addIssue(issue)
            Diag.warning(warnings.getDescription(for: issue))
        }
    }
    
    func onCompositeKeyComponentsProcessed(dbFile: DatabaseFile, compositeKey: CompositeKey) {
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
                warnings: warnings)
            Diag.info("Database loaded OK")
            
            let shouldUpdateBackup = Settings.current.isBackupDatabaseOnLoad
                && DatabaseManager.shouldBackupFiles(from: dbRef.location)
            if shouldUpdateBackup {
                Diag.debug("Updating latest backup")
                progress.completedUnitCount = ProgressSteps.willMakeBackup
                progress.status = LString.Progress.makingDatabaseBackup
                FileKeeper.shared.makeBackup(
                    nameTemplate: dbFile.visibleFileName,
                    mode: .latest,
                    contents: dbFile.data)
            }
            
            addFileLocationWarnings(to: warnings)

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
                stopObservingProgress()
                if progress.isCancelled {
                    notifyDidCancelLoading()
                } else {
                    notifyDidFailLoading(
                        message: error.localizedDescription,
                        reason: error.failureReason
                    )
                }
            case .invalidKey:
                Diag.error("Invalid master key. [message: \(error.localizedDescription)]")
                stopObservingProgress()
                notifyDidFailLoading(withInvalidMasterKeyMessage: error.localizedDescription)
            case .saveError:
                Diag.error("saveError while loading?!")
                fatalError("Database saving error while loading?!")
            }
            endBackgroundTask()
        } catch let error as ProgressInterruption {
            dbFile.erase()
            switch error {
            case .cancelled(let reason):
                Diag.info("Database loading was cancelled. [reason: \(reason.localizedDescription)]")
                stopObservingProgress()
                switch reason {
                case .userRequest:
                    notifyDidCancelLoading()
                case .lowMemoryWarning:
                    notifyDidFailLoading(
                        message: error.localizedDescription,
                        reason: nil
                    )
                }
                endBackgroundTask()
            }
        } catch {
            assertionFailure("Unprocessed exception")
            dbFile.erase()
            Diag.error("Unexpected error [message: \(error.localizedDescription)]")
            stopObservingProgress()
            if progress.isCancelled {
                notifyDidCancelLoading()
            } else {
                notifyDidFailLoading(
                    message: error.localizedDescription,
                    reason: nil
                )
            }
            endBackgroundTask()
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
    
    private func notifyDidCancelLoading() {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(self, didCancelLoading: self.dbRef)
        }
    }
    
    private func notifyDidFailLoading(withInvalidMasterKeyMessage message: String) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(
                self,
                didFailLoading: self.dbRef,
                withInvalidMasterKeyMessage: message
            )
        }
    }

    private func notifyDidFailLoading(message: String, reason: String?) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseLoader(
                self,
                didFailLoading: self.dbRef,
                message: message,
                reason: reason
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
