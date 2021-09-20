//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public protocol DatabaseSaverDelegate: AnyObject {
    func databaseSaver(_ databaseSaver: DatabaseSaver, willSave databaseFile: DatabaseFile)
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didChangeProgress progress: ProgressEx,
        for databaseFile: DatabaseFile)
    
    func databaseSaverResolveConflict(
        _ databaseSaver: DatabaseSaver,
        local: DatabaseFile,
        remoteURL: URL,
        remoteData: ByteArray,
        completion: @escaping ((ByteArray?) -> Void)
    )
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didCancelSaving databaseFile: DatabaseFile
    )
    
    func databaseSaver(_ databaseSaver: DatabaseSaver, didSave databaseFile: DatabaseFile)
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didFailSaving databaseFile: DatabaseFile,
        with error: Error
    )
}

public class DatabaseSaver: ProgressObserver {
    typealias ConflictResolutionCallback = ((ByteArray?) -> Void)
    
    fileprivate enum ProgressSteps {
        static let all: Int64 = 100 
        
        static let willStart: Int64 = -1
        static let willMakeBackup: Int64 = -1
        static let willEncryptDatabase: Int64 = 0
        static let didEncryptDatabase: Int64 = 90
        static let didWriteDatabase: Int64 = 100
    }
    
    private let databaseFile: DatabaseFile
    private var progressKVO: NSKeyValueObservation?
    
    public weak var delegate: DatabaseSaverDelegate?
    private let delegateQueue: DispatchQueue
    
    private let operationQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.keepassium.DatabaseSaver"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInitiated
        return q
    }()
    
    public init(
        databaseFile: DatabaseFile,
        delegate: DatabaseSaverDelegate,
        delegateQueue: DispatchQueue = .main
    ) {
        self.databaseFile = databaseFile
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        
        let progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = ProgressSteps.willStart
        super.init(progress: progress)
    }
    
    
    private var backgroundTask: UIBackgroundTaskIdentifier?
    private func startBackgroundTask() {
        guard let appShared = AppGroup.applicationShared else { return }
        
        print("Starting background task")
        backgroundTask = appShared.beginBackgroundTask(withName: "DatabaseSaving") {
            self.progress.cancel()
            self.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        guard let appShared = AppGroup.applicationShared else { return }
        
        guard let bgTask = backgroundTask else { return }
        backgroundTask = nil
        appShared.endBackgroundTask(bgTask)
    }
    
    
    override func progressDidChange(progress: ProgressEx) {
        notifyDidChangeProgress(progress: progress)
    }
    
    
    public func save() {
        operationQueue.addOperation { [self] in
            self.saveOnBackgroundQueue()
        }
    }
    
    private func saveOnBackgroundQueue() {
        assert(operationQueue.isCurrent)
        Diag.debug("Will save database")
        startBackgroundTask()
        startObservingProgress()
        notifyWillSaveDatabase()
        
        databaseFile.resolveFileURL(completionQueue: operationQueue) { [self] in
            self.didResolveURL()
        }
    }
    
    private func didResolveURL() {
        assert(operationQueue.isCurrent)
        if Settings.current.isBackupDatabaseOnSave {
            progress.completedUnitCount = ProgressSteps.willMakeBackup
            progress.status = LString.Progress.makingDatabaseBackup
            
            let nameTemplate = databaseFile.visibleFileName
            FileKeeper.shared.makeBackup(
                nameTemplate: nameTemplate,
                mode: .timestamped,
                contents: databaseFile.data)
        }
        
        databaseFile.setData(ByteArray(), updateHash: false)
        do {
            Diag.info("Encrypting database")
            let database = databaseFile.database
            progress.completedUnitCount = ProgressSteps.willEncryptDatabase
            let encryptionUnitCount = ProgressSteps.didEncryptDatabase - ProgressSteps.willEncryptDatabase
            progress.addChild(
                database.initProgress(),
                withPendingUnitCount: encryptionUnitCount)
            let outData = try database.save() 
            databaseFile.setData(outData, updateHash: false)
            progress.completedUnitCount = ProgressSteps.didEncryptDatabase
            
            Diag.info("Writing database document")
            let document = BaseDocument(fileURL: databaseFile.fileURL, fileProvider: databaseFile.fileProvider)
            document.open(queue: operationQueue, completionQueue: operationQueue) {
                [self] (result) in 
                switch result {
                case .success(_):
                    self.didOpenRemote(document: document)
                case .failure(let fileAccessError):
                    finalize(withError: fileAccessError)
                }
            }
        } catch {
            finalize(withError: error)
        }
    }
    
    private func didOpenRemote(document: BaseDocument) {
        assert(operationQueue.isCurrent)
        let remoteData = document.data
        let remoteDataHash = remoteData.sha512
        let localDataHash = databaseFile.storedDataSHA512
        if remoteData.isEmpty || (localDataHash == remoteDataHash) {
            overwriteRemote(document: document)
            return
        }
        
        notifyShouldResolveConflict(
            remoteURL: document.fileURL,
            remoteData: document.data,
            completion: { [self, document] newData in
                assert(self.operationQueue.isCurrent)
                guard let newData = newData else {
                    Diag.debug("Saving aborted after sync conflict.")
                    document.close(completionQueue: nil, completion: nil)
                    finalize(withError: nil)
                    return
                }
                self.databaseFile.setData(newData, updateHash: false)
                document.data = newData
                self.overwriteRemote(document: document)
            }
        )
        
    }
    
    private func overwriteRemote(document: BaseDocument) {
        assert(operationQueue.isCurrent)
        assert(document.documentState.contains(.normal))
        document.data = databaseFile.data
        document.saveAndClose(completionQueue: operationQueue) { [self] result in
            switch result {
            case .success:
                self.progress.status = LString.Progress.done
                self.progress.completedUnitCount = ProgressSteps.didWriteDatabase
                self.databaseFile.setData(self.databaseFile.data, updateHash: true)
                Diag.info("Database saved OK")
                self.updateLatestBackup(with: document.data)
                notifyDidSaveDatabase()
                finalize(withError: nil)
            case .failure(let fileAccessError):
                Diag.error("Database saving error. [message: \(fileAccessError.localizedDescription)]")
                finalize(withError: fileAccessError)
            }
        }
    }
    
    private func updateLatestBackup(with data: ByteArray) {
        assert(self.operationQueue.isCurrent)
        guard Settings.current.isBackupDatabaseOnSave else {
            return
        }
        let location = FileKeeper.shared.getLocation(for: databaseFile.fileURL)
        guard DatabaseManager.shouldBackupFiles(from: location) else {
            return
        }
        
        Diag.debug("Updating latest backup")
        progress.status = LString.Progress.makingDatabaseBackup
        
        let nameTemplate = databaseFile.visibleFileName
        FileKeeper.shared.makeBackup(
            nameTemplate: nameTemplate,
            mode: .latest,
            contents: data)
    }
    
    private func finalize(withError error: Error?) {
        stopObservingProgress()
        defer {
            endBackgroundTask()
        }
        
        guard let error = error else {
            return
        }
        
        switch error {
        case ProgressInterruption.cancelled(let reason):
            Diag.error("Database saving was cancelled. [reason: \(reason.localizedDescription)]")
            switch reason {
            case .userRequest:
                notifyDidCancelSaving()
            case .lowMemoryWarning:
                notifyDidFailSaving(with: error)
            }
            return 
        case let dbError as DatabaseError:
            Diag.error("""
                Database saving error. [
                    isCancelled: \(progress.isCancelled),
                    message: \(error.localizedDescription),
                    reason: \(String(describing: dbError.failureReason))]
                """)
        case let fileAccessError as FileAccessError:
            Diag.error("Failed to open remote file [message: \(fileAccessError.localizedDescription)]")
        default: 
            Diag.error("Database saving error. [isCancelled: \(progress.isCancelled), message: \(error.localizedDescription)]")
        }
        
        if progress.isCancelled {
            notifyDidCancelSaving()
        } else {
            notifyDidFailSaving(with: error)
        }
    }
}

extension DatabaseSaver {
    private func notifyWillSaveDatabase() {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseSaver(self, willSave: self.databaseFile)
        }
    }
    
    private func notifyDidChangeProgress(progress: ProgressEx) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseSaver(self, didChangeProgress: progress, for: self.databaseFile)
        }
    }
    
    private func notifyDidCancelSaving() {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseSaver(self, didCancelSaving: self.databaseFile)
        }
    }
    
    private func notifyDidSaveDatabase() {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseSaver(self, didSave: self.databaseFile)
        }
    }
    
    private func notifyDidFailSaving(with error: Error) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.databaseSaver(self, didFailSaving: self.databaseFile, with: error)
        }
    }
    
    private func notifyShouldResolveConflict(
        remoteURL: URL,
        remoteData: ByteArray,
        completion: @escaping ConflictResolutionCallback
    ) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            assert(self.delegate != nil, "There is no delegate to handle sync conflict")
            self.delegate?.databaseSaverResolveConflict(
                self,
                local: self.databaseFile,
                remoteURL: remoteURL,
                remoteData: remoteData,
                completion: { [self] resolvedData in
                    self.operationQueue.addOperation {
                        completion(resolvedData)
                    }
                }
            )
        }
    }
}
