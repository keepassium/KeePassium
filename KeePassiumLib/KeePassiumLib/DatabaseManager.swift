//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

enum DatabaseLockReason {
    case userRequest
    case timeout
}

fileprivate enum ProgressSteps {
    static let start: Int64 = -1 
    static let all: Int64 = 100 

}


public class DatabaseManager {
    public static let shared = DatabaseManager()

    public var progress = ProgressEx()
    
    public private(set) var databaseRef: URLReference?
    public var database: Database? { return databaseDocument?.database }

    public var isDatabaseOpen: Bool { return database != nil }
    
    private var databaseDocument: DatabaseDocument?
    private var databaseLoader: DatabaseLoader?
    private var databaseSaver: DatabaseSaver?
    
    private var serialDispatchQueue = DispatchQueue(
        label: "com.keepassium.DatabaseManager",
        qos: .userInitiated)
    
    public init() {
    }

    
    
    public func closeDatabase(
        clearStoredKey: Bool,
        ignoreErrors: Bool,
        completion callback: ((FileAccessError?) -> Void)?)
    {
        guard database != nil else {
            callback?(nil)
            return
        }
        Diag.verbose("Will queue close database")

        if clearStoredKey, let urlRef = databaseRef {
            DatabaseSettingsManager.shared.updateSettings(for: urlRef) { (dbSettings) in
                dbSettings.clearMasterKey()
                Diag.verbose("Master key cleared")
            }
        }

        serialDispatchQueue.async {
            guard let dbDoc = self.databaseDocument else {
                DispatchQueue.main.async {
                    callback?(nil)
                }
                return
            }
            Diag.debug("Will close database")
            
            let completionSemaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                dbDoc.close { [self] result in 
                    switch result {
                    case .success:
                        self.handleDatabaseClosing()
                        callback?(nil)
                        completionSemaphore.signal()
                    case .failure(let fileAccessError):
                        Diag.error("Failed to close database document [message: \(fileAccessError.localizedDescription)]")
                        if ignoreErrors {
                            Diag.warning("Ignoring errors and closing anyway")
                            self.handleDatabaseClosing()
                            callback?(nil) 
                        } else {
                            callback?(fileAccessError)
                        }
                        completionSemaphore.signal()
                    }
                }
            }
            completionSemaphore.wait()
        }
    }
    
    private func handleDatabaseClosing() {
        guard let dbRef = self.databaseRef else { assertionFailure(); return }
        
        self.notifyDatabaseWillClose(database: dbRef)
        self.databaseDocument = nil
        self.databaseRef = nil
        self.notifyDatabaseDidClose(database: dbRef)
        Diag.info("Database closed")
    }

    public func startLoadingDatabase(
        database dbRef: URLReference,
        password: String,
        keyFile keyFileRef: URLReference?,
        challengeHandler: ChallengeHandler?)
    {
        Diag.verbose("Will queue load database")
        let compositeKey = CompositeKey(
            password: password,
            keyFileRef: keyFileRef,
            challengeHandler: challengeHandler
        )
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: compositeKey)
        }
    }
    
    public func startLoadingDatabase(
        database dbRef: URLReference,
        compositeKey: CompositeKey,
        canUseFinalKey: Bool)
    {
        Diag.verbose("Will queue load database")
        
        let compositeKeyClone = compositeKey.clone()
        if !canUseFinalKey {
            compositeKeyClone.eraseFinalKeys()
        }
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: compositeKeyClone)
        }
    }
    
    private func _loadDatabase(dbRef: URLReference, compositeKey: CompositeKey) {
        precondition(database == nil, "Can only load one database at a time")

        Diag.info("Will load database")
        progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = ProgressSteps.start
        
        precondition(databaseLoader == nil)
        databaseLoader = DatabaseLoader(
            dbRef: dbRef,
            compositeKey: compositeKey,
            progress: progress,
            delegate: self)
        databaseLoader!.load()
    }

    public func rememberDatabaseKey(onlyIfExists: Bool = false) throws {
        guard let databaseRef = databaseRef, let database = database else { return }
        let dsm = DatabaseSettingsManager.shared
        let dbSettings = dsm.getOrMakeSettings(for: databaseRef)
        if onlyIfExists && !dbSettings.hasMasterKey {
            return
        }
        
        Diag.info("Saving database key in keychain.")
        dbSettings.setMasterKey(database.compositeKey)
        dsm.setSettings(dbSettings, for: databaseRef)
    }
    
    public func startSavingDatabase() {
        guard let databaseDocument = databaseDocument, let dbRef = databaseRef else {
            Diag.warning("Tried to save database before opening one.")
            assertionFailure("Tried to save database before opening one.")
            return
        }
        serialDispatchQueue.async {
            self._saveDatabase(databaseDocument, dbRef: dbRef)
            Diag.info("Async database saving finished")
        }
    }
    
    private func _saveDatabase(
        _ dbDoc: DatabaseDocument,
        dbRef: URLReference)
    {
        precondition(database != nil, "No database to save")
        Diag.info("Saving database")
        
        progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = ProgressSteps.start
        
        precondition(databaseSaver == nil)
        databaseSaver = DatabaseSaver(
            databaseDocument: dbDoc,
            databaseRef: dbRef,
            progress: progress,
            delegate: self)
        databaseSaver!.save()
    }
    
    
    public func changeCompositeKey(to newKey: CompositeKey) {
        database?.changeCompositeKey(to: newKey)
        Diag.info("Database composite key changed")
    }
    
    public static func createCompositeKey(
        keyHelper: KeyHelper,
        password: String,
        keyFile keyFileRef: URLReference?,
        challengeHandler: ChallengeHandler?,
        success successHandler: @escaping((_ compositeKey: CompositeKey) -> Void),
        error errorHandler: @escaping((_ errorMessage: String) -> Void))
    {
        let mainQueueSuccessHandler: (_ compositeKey: CompositeKey)->Void = { (compositeKey) in
            DispatchQueue.main.async {
                successHandler(compositeKey)
            }
        }
        let mainQueueErrorHandler: (_ errorMessage: String)->Void = { (errorMessage) in
            DispatchQueue.main.async {
                errorHandler(errorMessage)
            }
        }
        
        let dataReadyHandler = { (keyFileData: ByteArray) -> Void in
            let passwordData = keyHelper.getPasswordData(password: password)
            if passwordData.isEmpty && keyFileData.isEmpty && challengeHandler == nil {
                Diag.error("Password and key file are both empty")
                mainQueueErrorHandler(LString.Error.passwordAndKeyFileAreBothEmpty)
                return
            }
            do {
                let staticComponents = try keyHelper.combineComponents(
                    passwordData: passwordData, 
                    keyFileData: keyFileData    
                ) 
                let compositeKey = CompositeKey(
                    staticComponents: staticComponents,
                    challengeHandler: challengeHandler)
                Diag.debug("New composite key created successfully")
                mainQueueSuccessHandler(compositeKey)
            } catch let error as KeyFileError {
                Diag.error("Key file error [reason: \(error.localizedDescription)]")
                mainQueueErrorHandler(error.localizedDescription)
            } catch {
                let message = "Caught unrecognized exception" 
                assertionFailure(message)
                Diag.error(message)
                mainQueueErrorHandler(message)
            }
        }
        
        guard let keyFileRef = keyFileRef else {
            dataReadyHandler(ByteArray())
            return
        }
        
        keyFileRef.resolveAsync { result in 
            switch result {
            case .success(let keyFileURL):
                let keyDoc = BaseDocument(fileURL: keyFileURL, fileProvider: keyFileRef.fileProvider)
                keyDoc.open { result in
                    switch result {
                    case .success(let keyFileData):
                        dataReadyHandler(keyFileData)
                    case .failure(let fileAccessError):
                        Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                        mainQueueErrorHandler(LString.Error.failedToOpenKeyFile)
                    }
                }
            case .failure(let accessError):
                Diag.error("Failed to open key file [error: \(accessError.localizedDescription)]")
                mainQueueErrorHandler(LString.Error.failedToOpenKeyFile)
            }
        }
    }
    
    public func createDatabase(
        databaseURL: URL,
        password: String,
        keyFile: URLReference?,
        challengeHandler: ChallengeHandler?,
        template templateSetupHandler: @escaping (Group2) -> Void,
        success successHandler: @escaping () -> Void,
        error errorHandler: @escaping ((String?) -> Void))
    {
        assert(database == nil)
        assert(databaseDocument == nil)
        let db2 = Database2.makeNewV4()
        guard let root2 = db2.root as? Group2 else { fatalError() }
        templateSetupHandler(root2)

        self.databaseDocument = DatabaseDocument(fileURL: databaseURL, fileProvider: nil)
        self.databaseDocument!.database = db2
        DatabaseManager.createCompositeKey(
            keyHelper: db2.keyHelper,
            password: password,
            keyFile: keyFile,
            challengeHandler: challengeHandler,
            success: { 
                (newCompositeKey) in
                DatabaseManager.shared.changeCompositeKey(to: newCompositeKey)
                
                do {
                    self.databaseRef = try URLReference(from: databaseURL, location: .internalInbox)
                    successHandler()
                } catch {
                    Diag.error("Failed to create reference to temporary DB file [message: \(error.localizedDescription)]")
                    errorHandler(error.localizedDescription)
                }
            },
            error: { 
                (message) in
                assert(self.databaseRef == nil)
                self.abortDatabaseCreation()
                Diag.error("Error creating composite key for a new database [message: \(message)]")
                errorHandler(message)
            }
        )
    }

    public func abortDatabaseCreation() {
        assert(self.databaseDocument != nil)
        self.databaseDocument?.database = nil
        self.databaseDocument = nil
        self.databaseRef = nil

    }
    
    internal static func shouldUpdateLatestBackup(for dbRef: URLReference) -> Bool {
        switch dbRef.location {
        case .external, .internalDocuments:
            return true
        case .internalBackup, .internalInbox:
            return false
        }
    }
    
    
    fileprivate struct WeakObserver {
        weak var observer: DatabaseManagerObserver?
    }
    private var observers = [ObjectIdentifier: WeakObserver]()
    private var notificationQueue = DispatchQueue(
        label: "com.keepassium.DatabaseManager.notifications",
        qos: .default
    )
    
    public func addObserver(_ observer: DatabaseManagerObserver) {
        let id = ObjectIdentifier(observer)
        notificationQueue.async(flags: .barrier) { 
            self.observers[id] = WeakObserver(observer: observer)
        }
    }
    
    public func removeObserver(_ observer: DatabaseManagerObserver) {
        let id = ObjectIdentifier(observer)
        notificationQueue.async(flags: .barrier) { 
            self.observers.removeValue(forKey: id)
        }
    }

    
    fileprivate func notifyDatabaseWillCreate(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willCreateDatabase: urlRef)
                }
            }
        }
    }

    fileprivate func notifyDatabaseWillClose(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willCloseDatabase: urlRef)
                }
            }
        }
    }
    
    fileprivate func notifyDatabaseDidClose(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didCloseDatabase: urlRef)
                }
            }
        }
    }
}

fileprivate extension DatabaseManager {
    func databaseOperationProgressDidChange(
        database dbRef: URLReference,
        progress: ProgressEx)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(progressDidChange: progress)
                }
            }
        }
    }
    
    func databaseOperationCancelled(database dbRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(database: dbRef, isCancelled: true)
                }
            }
        }
    }
}

extension DatabaseManager: DatabaseLoaderDelegate {
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        willLoadDatabase dbRef: URLReference)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willLoadDatabase: dbRef)
                }
            }
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference)
    {
        databaseOperationProgressDidChange(database: dbRef, progress: progress)
    }
    
    func databaseLoader(_ databaseLoader: DatabaseLoader, didCancelLoading dbRef: URLReference) {
        databaseOperationCancelled(database: dbRef)
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        withInvalidMasterKeyMessage message: String)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(database: dbRef, invalidMasterKey: message)
                }
            }
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        message: String,
        reason: String?)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(
                        database: dbRef,
                        loadingError: message,
                        reason: reason)
                }
            }
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URLReference,
        withWarnings warnings: DatabaseLoadingWarnings)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didLoadDatabase: dbRef, warnings: warnings)
                }
            }
        }
    }
    
    func databaseLoaderDidFinish(
        _ databaseLoader: DatabaseLoader,
        for dbRef: URLReference,
        withResult databaseDocument: DatabaseDocument?)
    {
        self.databaseRef = dbRef
        self.databaseDocument = databaseDocument
        self.databaseLoader = nil
    }
}

extension DatabaseManager: DatabaseSaverDelegate {
    func databaseSaver(_ databaseSaver: DatabaseSaver, willSaveDatabase dbRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willSaveDatabase: dbRef)
                }
            }
        }
    }
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference)
    {
        databaseOperationProgressDidChange(database: dbRef, progress: progress)
    }
    
    func databaseSaver(_ databaseSaver: DatabaseSaver, didCancelSaving dbRef: URLReference) {
        databaseOperationCancelled(database: dbRef)
    }
    
    func databaseSaver(_ databaseSaver: DatabaseSaver, didSaveDatabase dbRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didSaveDatabase: dbRef)
                }
            }
        }
    }
    
    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didFailSaving dbRef: URLReference,
        error: Error,
        data: ByteArray?
    ) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(
                        database: dbRef,
                        savingError: error,
                        data: data)
                }
            }
        }
    }
    
    func databaseSaverDidFinish(_ databaseSaver: DatabaseSaver, for dbRef: URLReference) {
        self.databaseSaver = nil
    }
}
