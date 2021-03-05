//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

protocol DatabaseSaverDelegate: class {
    func databaseSaver(_ databaseSaver: DatabaseSaver, willSaveDatabase dbRef: URLReference)
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference)
    
    func databaseSaver(_ databaseSaver: DatabaseSaver, didCancelSaving dbRef: URLReference)
    
    func databaseSaver(_ databaseSaver: DatabaseSaver, didSaveDatabase dbRef: URLReference)
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didFailSaving dbRef: URLReference,
        error: Error,
        data: ByteArray?
    )
    
    func databaseSaverDidFinish(
        _ databaseSaver: DatabaseSaver,
        for dbRef: URLReference)
}

public class DatabaseSaver: ProgressObserver {
    fileprivate enum ProgressSteps {
        static let all: Int64 = 100 
        
        static let willMakeBackup: Int64 = -1
        static let willEncryptDatabase: Int64 = 0
        static let didEncryptDatabase: Int64 = 90
        static let didWriteDatabase: Int64 = 100
    }
    
    private let dbDoc: DatabaseDocument
    private let dbRef: URLReference
    private var progressKVO: NSKeyValueObservation?
    private unowned var notifier: DatabaseManager
    
    weak var delegate: DatabaseSaverDelegate?
    
    init(
        databaseDocument dbDoc: DatabaseDocument,
        databaseRef dbRef: URLReference,
        progress: ProgressEx,
        delegate: DatabaseSaverDelegate)
    {
        assert(dbDoc.documentState.contains(.normal))
        self.dbDoc = dbDoc
        self.dbRef = dbRef
        notifier = DatabaseManager.shared
        self.delegate = delegate
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
        delegate?.databaseSaver(self, didChangeProgress: progress, for: dbRef)
    }
    
    
    func save() {
        guard let database = dbDoc.database else { fatalError("Database is nil") }
        
        startBackgroundTask()
        startObservingProgress()
        delegate?.databaseSaver(self, willSaveDatabase: dbRef)
        do {
            if Settings.current.isBackupDatabaseOnSave {
                progress.completedUnitCount = ProgressSteps.willMakeBackup
                progress.status = LString.Progress.makingDatabaseBackup
                
                assert(dbRef.url != nil)
                let nameTemplate = dbRef.url?.lastPathComponent ?? "Backup"
                FileKeeper.shared.makeBackup(
                    nameTemplate: nameTemplate,
                    mode: .timestamped,
                    contents: dbDoc.data)
            }
            
            Diag.info("Encrypting database")
            progress.completedUnitCount = ProgressSteps.willEncryptDatabase
            let encryptionUnitCount = ProgressSteps.didEncryptDatabase - ProgressSteps.willEncryptDatabase
            progress.addChild(
                database.initProgress(),
                withPendingUnitCount: encryptionUnitCount)
            let outData = try database.save() 
            progress.completedUnitCount = ProgressSteps.didEncryptDatabase
            
            Diag.info("Writing database document")
            dbDoc.data = outData
            dbDoc.save { [self, outData] result in 
                switch result {
                case .success:
                    self.progress.status = LString.Progress.done
                    self.progress.completedUnitCount = ProgressSteps.didWriteDatabase
                    Diag.info("Database saved OK")
                    self.updateLatestBackup(with: outData)
                    self.stopObservingProgress()
                    self.delegate?.databaseSaver(self, didSaveDatabase: self.dbRef)
                    self.delegate?.databaseSaverDidFinish(self, for: self.dbRef)
                    self.endBackgroundTask()
                case .failure(let fileAccessError):
                    Diag.error("Database saving error. [message: \(fileAccessError.localizedDescription)]")
                    self.stopObservingProgress()
                    if progress.isCancelled {
                        self.delegate?.databaseSaver(self, didCancelSaving: self.dbRef)
                    } else {
                        self.delegate?.databaseSaver(
                            self,
                            didFailSaving: self.dbRef,
                            error: fileAccessError,
                            data: outData)
                    }
                    self.delegate?.databaseSaverDidFinish(self, for: self.dbRef)
                    self.endBackgroundTask()
                }
            }
        } catch let error as DatabaseError {
            Diag.error("""
                Database saving error. [
                    isCancelled: \(progress.isCancelled),
                    message: \(error.localizedDescription),
                    reason: \(String(describing: error.failureReason))]
                """)
            stopObservingProgress()
            if progress.isCancelled {
                delegate?.databaseSaver(self, didCancelSaving: dbRef)
            } else {
                delegate?.databaseSaver(
                    self,
                    didFailSaving: dbRef,
                    error: error,
                    data: nil
                )
            }
            delegate?.databaseSaverDidFinish(self, for: dbRef)
            endBackgroundTask()
        } catch let error as ProgressInterruption {
            stopObservingProgress()
            switch error {
            case .cancelled(let reason):
                Diag.error("Database saving was cancelled. [reason: \(reason.localizedDescription)]")
                switch reason {
                case .userRequest:
                    delegate?.databaseSaver(self, didCancelSaving: dbRef)
                case .lowMemoryWarning:
                    delegate?.databaseSaver(
                        self,
                        didFailSaving: dbRef,
                        error: error,
                        data: nil
                    )
                }
                delegate?.databaseSaverDidFinish(self, for: dbRef)
                endBackgroundTask()
            }
        } catch { 
            Diag.error("Database saving error. [isCancelled: \(progress.isCancelled), message: \(error.localizedDescription)]")
            stopObservingProgress()
            if progress.isCancelled {
                delegate?.databaseSaver(self, didCancelSaving: dbRef)
            } else {
                delegate?.databaseSaver(
                    self,
                    didFailSaving: dbRef,
                    error: error,
                    data: nil
                )
            }
            delegate?.databaseSaverDidFinish(self, for: dbRef)
            endBackgroundTask()
        }
    }
    
    private func updateLatestBackup(with data: ByteArray) {
        guard Settings.current.isBackupDatabaseOnSave,
              DatabaseManager.shouldUpdateLatestBackup(for: dbRef) else
        {
            return
        }
        
        Diag.debug("Updating latest backup")
        progress.status = LString.Progress.makingDatabaseBackup
        
        assert(dbRef.url != nil)
        let nameTemplate = dbRef.url?.lastPathComponent ?? "Backup"
        FileKeeper.shared.makeBackup(
            nameTemplate: nameTemplate,
            mode: .latest,
            contents: data)
    }
}
