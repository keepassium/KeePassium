//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

protocol DatabaseLoaderDelegate: class {
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
        withWarnings warnings: DatabaseLoadingWarnings)
    
    func databaseLoaderDidFinish(
        _ databaseLoader: DatabaseLoader,
        for dbRef: URLReference,
        withResult databaseDocument: DatabaseDocument?
    )
}

public class DatabaseLoader: ProgressObserver {
    fileprivate enum ProgressSteps {
        static let all: Int64 = 100 
        static let didReadDatabaseFile: Int64 = -1 
        static let didReadKeyFile: Int64 = -1 
        static let willDecryptDatabase: Int64 = 0
        static let didDecryptDatabase: Int64 = 100
        
        static let willMakeBackup: Int64 = -1 
    }
    
    weak var delegate: DatabaseLoaderDelegate?
    
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
    
    init(
        dbRef: URLReference,
        compositeKey: CompositeKey,
        progress: ProgressEx,
        delegate: DatabaseLoaderDelegate)
    {
        assert(compositeKey.state != .empty)
        self.dbRef = dbRef
        self.compositeKey = compositeKey
        self.delegate = delegate
        self.warnings = DatabaseLoadingWarnings()
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
    
    
    override func progressDidChange(progress: ProgressEx) {
        delegate?.databaseLoader(self, didChangeProgress: progress, for: dbRef)
    }
    
    
    func load() {
        startBackgroundTask()
        startObservingProgress()
        delegate?.databaseLoader(self, willLoadDatabase: dbRef)
        progress.status = LString.Progress.contactingStorageProvider
        dbRef.resolveAsync { result in 
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
        delegate?.databaseLoader(
            self,
            didFailLoading: dbRef,
            message: LString.Error.cannotFindDatabaseFile,
            reason: error.localizedDescription
        )
        delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
        endBackgroundTask()
    }
    
    private func onDatabaseURLResolved(url: URL, fileProvider: FileProvider?) {
        let dbDoc = DatabaseDocument(fileURL: url, fileProvider: fileProvider)
        progress.status = LString.Progress.loadingDatabaseFile
        dbDoc.open(queue: operationQueue) { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                self.onDatabaseDocumentOpened(dbDoc: dbDoc, data: docData)
            case .failure(let fileAccessError):
                Diag.error("Failed to open database document [error: \(fileAccessError.localizedDescription)]")
                self.stopObservingProgress()
                if self.progress.isCancelled {
                    self.delegate?.databaseLoader(self, didCancelLoading: self.dbRef)
                } else {
                    self.delegate?.databaseLoader(
                        self,
                        didFailLoading: self.dbRef,
                        message: LString.Error.cannotOpenDatabaseFile,
                        reason: fileAccessError.localizedDescription
                    )
                }
                self.delegate?.databaseLoaderDidFinish(self, for: self.dbRef, withResult: nil)
                self.endBackgroundTask()
            }
        }
    }
    
    private func onDatabaseDocumentOpened(dbDoc: DatabaseDocument, data: ByteArray) {
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
                delegate?.databaseLoader(self, didCancelLoading: dbRef)
            } else {
                delegate?.databaseLoader(
                    self,
                    didFailLoading: dbRef,
                    message: LString.Error.unrecognizedDatabaseFormat,
                    reason: nil
                )
            }
            delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
            endBackgroundTask()
            return
        }
        
        dbDoc.database = db
        guard compositeKey.state == .rawComponents else {
            
            progress.completedUnitCount = ProgressSteps.didReadKeyFile
            Diag.info("Using a ready composite key")
            onCompositeKeyComponentsProcessed(dbDoc: dbDoc, compositeKey: compositeKey)
            return
        }
        
        guard let keyFileRef = compositeKey.keyFileRef else {
            onKeyFileDataReady(dbDoc: dbDoc, keyFileData: ByteArray())
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
                    dbDoc: dbDoc)
            case .failure(let accessError):
                self.onKeyFileURLResolveError(accessError)
            }
        }
    }
    
    private func onKeyFileURLResolveError(_ error: FileAccessError) {
        Diag.error("Failed to resolve key file URL reference [error: \(error.localizedDescription)]")
        stopObservingProgress()
        if progress.isCancelled {
            delegate?.databaseLoader(self, didCancelLoading: dbRef)
        } else {
            delegate?.databaseLoader(
                self,
                didFailLoading: dbRef,
                message: LString.Error.cannotFindKeyFile,
                reason: error.localizedDescription
            )
        }
        delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
        endBackgroundTask()
    }
    
    private func onKeyFileURLResolved(url: URL, fileProvider: FileProvider?, dbDoc: DatabaseDocument) {
        let keyDoc = BaseDocument(fileURL: url, fileProvider: fileProvider)
        keyDoc.open(queue: operationQueue) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                self.onKeyFileDataReady(dbDoc: dbDoc, keyFileData: docData)
            case .failure(let fileAccessError):
                Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                self.stopObservingProgress()
                if self.progress.isCancelled {
                    self.delegate?.databaseLoader(self, didCancelLoading: self.dbRef)
                } else {
                    self.delegate?.databaseLoader(
                        self,
                        didFailLoading: self.dbRef,
                        message: LString.Error.cannotOpenKeyFile,
                        reason: fileAccessError.localizedDescription
                    )
                }
                self.delegate?.databaseLoaderDidFinish(self, for: self.dbRef, withResult: nil)
                self.endBackgroundTask()
            }
        }
    }
    
    private func onKeyFileDataReady(dbDoc: DatabaseDocument, keyFileData: ByteArray) {
        guard let database = dbDoc.database else { fatalError() }
        
        progress.completedUnitCount = ProgressSteps.didReadKeyFile
        let keyHelper = database.keyHelper
        let passwordData = keyHelper.getPasswordData(password: compositeKey.password)
        if passwordData.isEmpty && keyFileData.isEmpty && compositeKey.challengeHandler == nil {
            Diag.error("Both password and key file are empty")
            stopObservingProgress()
            delegate?.databaseLoader(
                self,
                didFailLoading: dbRef,
                withInvalidMasterKeyMessage: LString.Error.needPasswordOrKeyFile
            )
            delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
            endBackgroundTask()
            return
        }
        compositeKey.setProcessedComponents(passwordData: passwordData, keyFileData: keyFileData)
        onCompositeKeyComponentsProcessed(dbDoc: dbDoc, compositeKey: compositeKey)
    }
    
    private func addFileLocationWarnings(to warnings: DatabaseLoadingWarnings) {
        guard let dbFileInfo = dbRef.getCachedInfoSync(canFetch: false) else {
            return
        }
        
        if dbFileInfo.isInTrash {
            let trashWarning = String.localizedStringWithFormat(
                LString.Warning.fileIsInTrashTemplate,
                dbFileInfo.fileName
            )
            Diag.warning(trashWarning)
            warnings.messages.insert(trashWarning, at: 0)
        }
        if dbRef.location == .internalBackup {
            let temporaryBackupWarning = LString.Warning.temporaryBackupDatabase
            Diag.warning(temporaryBackupWarning)
            warnings.messages.insert(temporaryBackupWarning, at: 0)
        }
    }
    
    func onCompositeKeyComponentsProcessed(dbDoc: DatabaseDocument, compositeKey: CompositeKey) {
        assert(compositeKey.state >= .processedComponents)
        guard let db = dbDoc.database else { fatalError() }
        
        progress.completedUnitCount = ProgressSteps.willDecryptDatabase
        let remainingUnitCount = ProgressSteps.didDecryptDatabase - ProgressSteps.willDecryptDatabase
        do {
            progress.addChild(db.initProgress(), withPendingUnitCount: remainingUnitCount)
            Diag.info("Loading database")
            try db.load(
                dbFileName: dbDoc.fileURL.lastPathComponent,
                dbFileData: dbDoc.data,
                compositeKey: compositeKey,
                warnings: warnings)
            Diag.info("Database loaded OK")
            
            let shouldUpdateBackup = Settings.current.isBackupDatabaseOnLoad
                && DatabaseManager.shouldUpdateLatestBackup(for: dbRef)
            if shouldUpdateBackup {
                Diag.debug("Updating latest backup")
                progress.completedUnitCount = ProgressSteps.willMakeBackup
                progress.status = LString.Progress.makingDatabaseBackup
                assert(dbRef.url != nil)
                FileKeeper.shared.makeBackup(
                    nameTemplate: dbRef.url?.lastPathComponent ?? "Backup",
                    mode: .latest,
                    contents: dbDoc.data)
            }
            
            addFileLocationWarnings(to: warnings)

            progress.completedUnitCount = ProgressSteps.all
            progress.localizedDescription = LString.Progress.done
            delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: dbDoc)
            stopObservingProgress()
            delegate?.databaseLoader(self, didLoadDatabase: dbRef, withWarnings: warnings)
            endBackgroundTask()
            
        } catch let error as DatabaseError {
            dbDoc.database = nil
            dbDoc.close(completionHandler: nil)
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
                    delegate?.databaseLoader(self, didCancelLoading: dbRef)
                } else {
                    delegate?.databaseLoader(
                        self,
                        didFailLoading: dbRef,
                        message: error.localizedDescription,
                        reason: error.failureReason
                    )
                }
            case .invalidKey:
                Diag.error("Invalid master key. [message: \(error.localizedDescription)]")
                stopObservingProgress()
                delegate?.databaseLoader(
                    self,
                    didFailLoading: dbRef,
                    withInvalidMasterKeyMessage: error.localizedDescription
                )
            case .saveError:
                Diag.error("saveError while loading?!")
                fatalError("Database saving error while loading?!")
            }
            delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
            endBackgroundTask()
        } catch let error as ProgressInterruption {
            dbDoc.database = nil
            dbDoc.close(completionHandler: nil)
            switch error {
            case .cancelled(let reason):
                Diag.info("Database loading was cancelled. [reason: \(reason.localizedDescription)]")
                stopObservingProgress()
                switch reason {
                case .userRequest:
                    delegate?.databaseLoader(self, didCancelLoading: dbRef)
                case .lowMemoryWarning:
                    delegate?.databaseLoader(
                        self,
                        didFailLoading: dbRef,
                        message: error.localizedDescription,
                        reason: nil
                    )
                }
                delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
                endBackgroundTask()
            }
        } catch {
            assertionFailure("Unprocessed exception")
            dbDoc.database = nil
            dbDoc.close(completionHandler: nil)
            Diag.error("Unexpected error [message: \(error.localizedDescription)]")
            stopObservingProgress()
            if progress.isCancelled {
                delegate?.databaseLoader(self, didCancelLoading: dbRef)
            } else {
                delegate?.databaseLoader(
                    self,
                    didFailLoading: dbRef,
                    message: error.localizedDescription,
                    reason: nil
                )
            }
            delegate?.databaseLoaderDidFinish(self, for: dbRef, withResult: nil)
            endBackgroundTask()
        }
    }
}
