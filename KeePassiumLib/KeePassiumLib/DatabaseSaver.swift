//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
        completion: @escaping DatabaseSaver.ConflictResolutionHandler
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
    public typealias ConflictResolutionHandler =
        (_ targetData: ByteArray?, _ overwrite: Bool) -> Void

    public enum RelatedTasks: CaseIterable {
        case backupOriginal
        case updateLatestBackup
        case updateQuickAutoFill
    }
    
    fileprivate enum ProgressSteps {
        static let all: Int64 = 100 
        
        static let willStart: Int64 = -1
        static let willMakeBackup: Int64 = -1
        static let willEncryptDatabase: Int64 = 0
        static let didEncryptDatabase: Int64 = 90
        static let didWriteDatabase: Int64 = 100
    }
    
    private let databaseFile: DatabaseFile
    private let relatedTasks: Set<RelatedTasks>
    private var progressKVO: NSKeyValueObservation?
    
    public weak var delegate: DatabaseSaverDelegate?
    private let delegateQueue: DispatchQueue
    
    private let operationQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.keepassium.DatabaseSaver"
        q.maxConcurrentOperationCount = 2
        q.qualityOfService = .userInitiated
        return q
    }()
    
    public init(
        databaseFile: DatabaseFile,
        skipTasks: [RelatedTasks] = [],
        delegate: DatabaseSaverDelegate,
        delegateQueue: DispatchQueue = .main
    ) {
        self.databaseFile = databaseFile
        self.delegate = delegate
        self.delegateQueue = delegateQueue
        self.relatedTasks = Set(RelatedTasks.allCases).subtracting(skipTasks)
        
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
        
        if relatedTasks.contains(.backupOriginal) {
            maybeBackupOriginal(originalData: databaseFile.data)
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
            var isSaveCancelled = false
            var isSaveToSameFile = true
            FileDataProvider.readThenWrite(
                to: databaseFile.fileURL,
                fileProvider: databaseFile.fileProvider,
                queue: operationQueue,
                outputDataSource: { [self] remoteURL, remoteData -> ByteArray? in 
                    assert(operationQueue.isCurrent)
                    let dataToWrite = resolveConflict(
                        localData: outData,
                        remoteURL: remoteURL,
                        remoteData: remoteData,
                        saveToSameFile: &isSaveToSameFile
                    )
                    isSaveCancelled = (dataToWrite == nil)
                    if isSaveToSameFile {
                        return dataToWrite
                    } else {
                        return nil
                    }
                },
                completionQueue: operationQueue,
                completion: { [self] result in 
                    switch result {
                    case .success(_):
                        if isSaveCancelled {
                            Diag.debug("Saving aborted after sync conflict.")
                            finalize(withError: nil)
                            return
                        }
                        progress.status = LString.Progress.done
                        progress.completedUnitCount = ProgressSteps.didWriteDatabase
                        
                        if isSaveToSameFile {
                            databaseFile.setData(databaseFile.data, updateHash: true)
                            Diag.info("Database saved OK")
                            performPostSaveTasks(savedData: databaseFile.data)
                            notifyDidSaveDatabase()
                            finalize(withError: nil)
                        } else {
                            performPostSaveTasks(savedData: databaseFile.data)
                            finalize(withError: nil)
                        }
                    case .failure(let fileAccessError):
                        finalize(withError: fileAccessError)
                    }
                }
            )
        } catch {
            finalize(withError: error)
        }
    }
    
    
    private func resolveConflict(
        localData: ByteArray,
        remoteURL: URL,
        remoteData: ByteArray,
        saveToSameFile: inout Bool
    ) -> ByteArray? {
        assert(operationQueue.isCurrent)
        if remoteData.isEmpty || remoteData.sha512 == databaseFile.storedDataSHA512 {
            saveToSameFile = true
            return localData
        }
        
        var resolvedData: ByteArray?
        var shouldOverwrite = true 

        let semaphore = DispatchSemaphore(value: 0)
        notifyShouldResolveConflict(remoteURL: remoteURL, remoteData: remoteData) {
            (_resolvedData: ByteArray?, _shouldOverwrite: Bool) in
            resolvedData = _resolvedData
            shouldOverwrite = _shouldOverwrite
            semaphore.signal()
        }
        semaphore.wait() 

        saveToSameFile = shouldOverwrite
        return resolvedData
    }
    
    
    private func maybeBackupOriginal(originalData: ByteArray) {
        assert(self.operationQueue.isCurrent)
        guard Settings.current.isBackupDatabaseOnSave else {
            return
        }
        progress.completedUnitCount = ProgressSteps.willMakeBackup
        progress.status = LString.Progress.makingDatabaseBackup
        
        let nameTemplate = databaseFile.visibleFileName
        FileKeeper.shared.makeBackup(
            nameTemplate: nameTemplate,
            mode: .timestamped,
            contents: originalData)
    }
    
    private func performPostSaveTasks(savedData: ByteArray) {
        if relatedTasks.contains(.updateLatestBackup) {
            updateLatestBackup(with: savedData)
        }
        
        if relatedTasks.contains(.updateQuickAutoFill) {
            updateQuickAutoFillStorage()
        }
    }
    
    private func updateQuickAutoFillStorage() {
        assert(self.operationQueue.isCurrent)
        let dbSettingsManager = DatabaseSettingsManager.shared
        if dbSettingsManager.isQuickTypeEnabled(databaseFile) {
            let quickTypeDatabaseCount = dbSettingsManager.getQuickTypeDatabaseCount()
            let isReplaceExisting = quickTypeDatabaseCount == 1
            Diag.debug("Updating QuickType AutoFill records [replacing: \(isReplaceExisting)]")
            QuickTypeAutoFillStorage.saveIdentities(
                from: databaseFile,
                replaceExisting: isReplaceExisting
            )
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
        completion: @escaping ConflictResolutionHandler
    ) {
        delegateQueue.async { [weak self] in
            guard let self = self else { return }
            assert(self.delegate != nil, "There is no delegate to handle sync conflict")
            self.delegate?.databaseSaverResolveConflict(
                self,
                local: self.databaseFile,
                remoteURL: remoteURL,
                remoteData: remoteData,
                completion: { [self] (resolvedData, shouldOverwrite) in
                    self.operationQueue.addOperation {
                        completion(resolvedData, shouldOverwrite)
                    }
                }
            )
        }
    }
}
