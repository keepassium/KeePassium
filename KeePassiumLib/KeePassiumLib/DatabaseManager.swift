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
    static let all: Int64 = 100
    
    static let readDatabase: Int64 = 5
    static let readKeyFile: Int64 = 5
    static let decryptDatabase: Int64 = 90
    
    static let encryptDatabase: Int64 = 90
    static let writeDatabase: Int64 = 10
}


public class DatabaseManager {
    public static let shared = DatabaseManager()

    public var progress = ProgressEx()
    
    public private(set) var databaseRef: URLReference?
    public var database: Database? { return databaseDocument?.database }

    public var isDatabaseOpen: Bool { return database != nil }
    
    private var databaseDocument: DatabaseDocument?
    private var serialDispatchQueue = DispatchQueue(
        label: "com.keepassium.DatabaseManager",
        qos: .userInitiated)
    
    private init() {
    }

    
    
    public func closeDatabase(completion callback: (() -> Void)?=nil, clearStoredKey: Bool) {
        guard database != nil else { return }
        Diag.debug("Will close database")

        if clearStoredKey, let urlRef = databaseRef {
            try? Keychain.shared.removeDatabaseKey(databaseRef: urlRef)
        }

        serialDispatchQueue.async {
            guard let dbDoc = self.databaseDocument else { return }
            
            dbDoc.close(successHandler: {
                guard let dbRef = self.databaseRef else { assertionFailure(); return }
                self.notifyDatabaseWillClose(database: dbRef)
                self.databaseDocument = nil
                self.databaseRef = nil
                self.notifyDatabaseDidClose(database: dbRef)
                Diag.info("Database closed")
                callback?()
            }, errorHandler: { errorMessage in
                Diag.warning("Failed to save database document [message: \(String(describing: errorMessage))]")
            })
        }
    }

    public func startLoadingDatabase(
        database dbRef: URLReference,
        password: String,
        keyFile keyFileRef: URLReference?)
    {
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: nil, password: password, keyFileRef: keyFileRef)
        }
    }
    
    public func startLoadingDatabase(database dbRef: URLReference, compositeKey: SecureByteArray) {
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: compositeKey, password: "", keyFileRef: nil)
        }
    }
    
    private func _loadDatabase(
        dbRef: URLReference,
        compositeKey: SecureByteArray?,
        password: String,
        keyFileRef: URLReference?)
    {
        precondition(database == nil, "Can only load one database at a time")

        Diag.info("Will load database")
        progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = 0
        
        let dbLoader = DatabaseLoader(
            dbRef: dbRef,
            compositeKey: compositeKey,
            password: password,
            keyFileRef: keyFileRef,
            progress: progress,
            completion: databaseLoaded)
        dbLoader.load()
    }
    
    private func databaseLoaded(_ dbDoc: DatabaseDocument, _ dbRef: URLReference) {
        self.databaseDocument = dbDoc
        self.databaseRef = dbRef
    }

    public func rememberDatabaseKey(onlyIfExists: Bool = false) throws {
        guard let databaseRef = databaseRef, let database = database else { return }
        
        if onlyIfExists {
            guard try hasKey(for: databaseRef) else { return }
        }
        try Keychain.shared.setDatabaseKey(
            databaseRef: databaseRef,
            key: database.compositeKey)
        Diag.info("Database key saved in keychain.")
    }
    
    public func hasKey(for databaseRef: URLReference) throws -> Bool {
        let key = try Keychain.shared.getDatabaseKey(databaseRef: databaseRef)
        return key != nil
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
    
    private func _saveDatabase(_ dbDoc: DatabaseDocument, dbRef: URLReference) {
        precondition(database != nil, "No database to save")
        Diag.info("Saving database")
        
        progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = 0
        notifyDatabaseWillSave(database: dbRef)
        
        let dbSaver = DatabaseSaver(
            databaseDocument: dbDoc,
            databaseRef: dbRef,
            progress: progress,
            completion: databaseSaved)
        dbSaver.save()
    }
    
    private func databaseSaved(_ dbDoc: DatabaseDocument) {
    }
    
    public func changeCompositeKey(to newKey: SecureByteArray) {
        database?.changeCompositeKey(to: newKey)
        Diag.info("Database composite key changed")
    }
    
    public static func createCompositeKey(
        keyHelper: KeyHelper,
        password: String,
        keyFile keyFileRef: URLReference?,
        success successHandler: @escaping((_ combinedKey: SecureByteArray) -> Void),
        error errorHandler: @escaping((_ errorMessage: String) -> Void))
    {
        let dataReadyHandler = { (keyFileData: ByteArray) -> Void in
            let passwordData = keyHelper.getPasswordData(password: password)
            if passwordData.isEmpty && keyFileData.isEmpty {
                Diag.error("Password and key file are both empty")
                errorHandler(NSLocalizedString("Password and key file are both empty.", comment: "Error message"))
                return
            }
            let compositeKey = keyHelper.makeCompositeKey(
                passwordData: passwordData,
                keyFileData: keyFileData)
            Diag.debug("New composite key created successfully")
            successHandler(compositeKey)
        }
        
        if let keyFileRef = keyFileRef {
            do {
                let keyFileURL = try keyFileRef.resolve()
                let keyDoc = FileDocument(fileURL: keyFileURL)
                keyDoc.open(successHandler: {
                    dataReadyHandler(keyDoc.data)
                }, errorHandler: { error in
                    Diag.error("Failed to open key file [error: \(error.localizedDescription)]")
                    errorHandler(NSLocalizedString("Failed to open key file", comment: "Error message"))
                })
            } catch {
                Diag.error("Failed to open key file [error: \(error.localizedDescription)]")
                errorHandler(NSLocalizedString("Failed to open key file", comment: "Error message"))
                return
            }
            
        } else {
            dataReadyHandler(ByteArray())
        }
    }
    
    public func createDatabase(
        databaseURL: URL,
        password: String,
        keyFile: URLReference?,
        template templateSetupHandler: @escaping (Group2) -> Void,
        success successHandler: @escaping () -> Void,
        error errorHandler: @escaping ((String?) -> Void))
    {
        assert(database == nil)
        assert(databaseDocument == nil)
        let db2 = Database2.makeNewV4()
        guard let root2 = db2.root as? Group2 else { fatalError() }
        templateSetupHandler(root2)

        self.databaseDocument = DatabaseDocument(fileURL: databaseURL)
        self.databaseDocument!.database = db2
        DatabaseManager.createCompositeKey(
            keyHelper: db2.keyHelper,
            password: password,
            keyFile: keyFile,
            success: { 
                (newCompositeKey) in
                DatabaseManager.shared.changeCompositeKey(to: newCompositeKey)
                
                do {
                    self.databaseRef = try URLReference(from: databaseURL, location: .external)
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


    internal enum Notifications {
        static let cancelled = Notification.Name("com.keepassium.databaseManager.cancelled")
        static let progressDidChange = Notification.Name("com.keepassium.databaseManager.progressDidChange")
        static let willLoadDatabase = Notification.Name("com.keepassium.databaseManager.willLoadDatabase")
        static let didLoadDatabase = Notification.Name("com.keepassium.databaseManager.didLoadDatabase")
        static let willSaveDatabase = Notification.Name("com.keepassium.databaseManager.willSaveDatabase")
        static let didSaveDatabase = Notification.Name("com.keepassium.databaseManager.didSaveDatabase")
        static let invalidMasterKey = Notification.Name("com.keepassium.databaseManager.invalidMasterKey")
        static let loadingError = Notification.Name("com.keepassium.databaseManager.loadingError")
        static let savingError = Notification.Name("com.keepassium.databaseManager.savingError")
        static let willCreateDatabase = Notification.Name("com.keepassium.databaseManager.willCreateDatabase")
        static let willCloseDatabase = Notification.Name("com.keepassium.databaseManager.willCloseDatabase")
        static let didCloseDatabase = Notification.Name("com.keepassium.databaseManager.didCloseDatabase")
        
        static let userInfoURLRefKey = "urlRef"
        static let userInfoProgressKey = "progress"
        static let userInfoErrorMessageKey = "errorMessage"
        static let userInfoErrorReasonKey = "errorReason"
        static let userInfoWarningsKey = "warningMessages"
    }
    
    fileprivate func notifyDatabaseWillLoad(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willLoadDatabase: urlRef)
                }
            }
        }
        
        NotificationCenter.default.post(
            name: Notifications.willLoadDatabase,
            object: self,
            userInfo: [Notifications.userInfoURLRefKey: urlRef])
    }
    
    fileprivate func notifyDatabaseDidLoad(
        database urlRef: URLReference,
        warnings: DatabaseLoadingWarnings)
    {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didLoadDatabase: urlRef, warnings: warnings)
                }
            }
        }
        
        NotificationCenter.default.post(
            name: Notifications.didLoadDatabase,
            object: self,
            userInfo: [
                Notifications.userInfoURLRefKey: urlRef,
                Notifications.userInfoWarningsKey: warnings
            ]
        )
    }
    
    fileprivate func notifyOperationCancelled(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(database: urlRef, isCancelled: true)
                }
            }
        }
        
        NotificationCenter.default.post(
            name: Notifications.cancelled,
            object: self,
            userInfo: [Notifications.userInfoURLRefKey: urlRef])
    }

    fileprivate func notifyProgressDidChange(database urlRef: URLReference, progress: ProgressEx) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(progressDidChange: progress)
                }
            }
        }
        NotificationCenter.default.post(
            name: Notifications.progressDidChange,
            object: self,
            userInfo: [Notifications.userInfoProgressKey: progress])
    }

    
    fileprivate func notifyDatabaseLoadError(
        database urlRef: URLReference,
        isCancelled: Bool,
        message: String,
        reason: String?)
    {
        if isCancelled {
            notifyOperationCancelled(database: urlRef)
            return
        }
        
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(
                        database: urlRef,
                        loadingError: message,
                        reason: reason)
                }
            }
        }
        let userInfo: [AnyHashable: Any]
        if let reason = reason {
            userInfo = [
                Notifications.userInfoURLRefKey: urlRef,
                Notifications.userInfoErrorMessageKey: message,
                Notifications.userInfoErrorReasonKey: reason]
        } else {
            userInfo = [
                Notifications.userInfoURLRefKey: urlRef,
                Notifications.userInfoErrorMessageKey: message]
        }
        NotificationCenter.default.post(
            name: Notifications.loadingError,
            object: nil,
            userInfo: userInfo)
    }
    
    fileprivate func notifyDatabaseInvalidMasterKey(database urlRef: URLReference, message: String) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(database: urlRef, invalidMasterKey: message)
                }
            }
        }
        NotificationCenter.default.post(
            name: Notifications.invalidMasterKey,
            object: self,
            userInfo: [
                Notifications.userInfoURLRefKey: urlRef,
                Notifications.userInfoErrorMessageKey: message
            ]
        )
    }
    
    fileprivate func notifyDatabaseWillSave(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willSaveDatabase: urlRef)
                }
            }
        }
        NotificationCenter.default.post(
            name: Notifications.willSaveDatabase,
            object: self,
            userInfo: [
                Notifications.userInfoURLRefKey: urlRef
            ]
        )
    }
    
    fileprivate func notifyDatabaseDidSave(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(didSaveDatabase: urlRef)
                }
            }
        }
        NotificationCenter.default.post(
            name: Notifications.didSaveDatabase,
            object: self,
            userInfo: [
                Notifications.userInfoURLRefKey: urlRef
            ]
        )
    }
    
    fileprivate func notifyDatabaseSaveError(
        database urlRef: URLReference,
        isCancelled: Bool,
        message: String,
        reason: String?)
    {
        if isCancelled {
            notifyOperationCancelled(database: urlRef)
            return
        }

        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(
                        database: urlRef,
                        savingError: message,
                        reason: reason)
                }
            }
        }
        let userInfo: [AnyHashable: Any]
        if let reason = reason {
            userInfo = [
                Notifications.userInfoURLRefKey: urlRef,
                Notifications.userInfoErrorMessageKey: message,
                Notifications.userInfoErrorReasonKey: reason]
        } else {
            userInfo = [
                Notifications.userInfoURLRefKey: urlRef,
                Notifications.userInfoErrorMessageKey: message]
        }
        NotificationCenter.default.post(
            name: Notifications.savingError,
            object: self,
            userInfo: userInfo)
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
        NotificationCenter.default.post(
            name: Notifications.willCreateDatabase,
            object: self,
            userInfo: [Notifications.userInfoURLRefKey: urlRef])
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
        NotificationCenter.default.post(
            name: Notifications.willCloseDatabase,
            object: self,
            userInfo: [Notifications.userInfoURLRefKey: urlRef])
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
        NotificationCenter.default.post(
            name: Notifications.didCloseDatabase,
            object: self,
            userInfo: [Notifications.userInfoURLRefKey: urlRef])
    }
}


fileprivate class DatabaseLoader {
    private let dbRef: URLReference
    private let compositeKey: SecureByteArray?
    private let password: String
    private let keyFileRef: URLReference?
    private let progress: ProgressEx
    private var progressKVO: NSKeyValueObservation?
    private unowned var notifier: DatabaseManager
    private let warnings: DatabaseLoadingWarnings
    private let completion: ((DatabaseDocument, URLReference) -> Void)
    
    init(
        dbRef: URLReference,
        compositeKey: SecureByteArray?,
        password: String,
        keyFileRef: URLReference?,
        progress: ProgressEx,
        completion: @escaping((DatabaseDocument, URLReference) -> Void))
    {
        self.dbRef = dbRef
        self.compositeKey = compositeKey
        self.password = password
        self.keyFileRef = keyFileRef
        self.progress = progress
        self.completion = completion
        self.warnings = DatabaseLoadingWarnings()
        self.notifier = DatabaseManager.shared
    }

    private func startObservingProgress() {
        assert(progressKVO == nil)
        progressKVO = progress.observe(
            \.fractionCompleted,
            options: [.new],
            changeHandler: {
                [weak self] (progress, _) in
                guard let _self = self else { return }
                _self.notifier.notifyProgressDidChange(
                    database: _self.dbRef,
                    progress: _self.progress
                )
            }
        )
    }
    
    private func stopObservingProgress() {
        assert(progressKVO != nil)
        progressKVO?.invalidate()
        progressKVO = nil
    }
    
    private func initDatabase(signature data: ByteArray) -> Database? {
        if Database1.isSignatureMatches(data: data) {
            Diag.info("DB signature: KPv1")
            return Database1()
        } else if Database2.isSignatureMatches(data: data) {
            Diag.info("DB signature: KPv2")
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
    }
    
    private func endBackgroundTask() {
        guard let appShared = AppGroup.applicationShared else { return }
        
        guard let bgTask = backgroundTask else { return }
        print("ending background task")
        backgroundTask = nil
        appShared.endBackgroundTask(bgTask)
    }
    
    
    func load() {
        startBackgroundTask()
        startObservingProgress()
        notifier.notifyDatabaseWillLoad(database: dbRef)
        let dbURL: URL
        do {
            dbURL = try dbRef.resolve()
        } catch {
            Diag.error("Failed to resolve database URL reference [error: \(error.localizedDescription)]")
            stopObservingProgress()
            notifier.notifyDatabaseLoadError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: NSLocalizedString("Cannot find database file", comment: "Error message"),
                reason: error.localizedDescription)
            endBackgroundTask()
            return
        }
        
        let dbDoc = DatabaseDocument(fileURL: dbURL)
        progress.status = NSLocalizedString("Loading database file...", comment: "Status message: loading database file in progress")
        dbDoc.open(
            successHandler: {
                self.onDatabaseDocumentOpened(dbDoc)
            },
            errorHandler: {
                (errorMessage) in
                Diag.error("Failed to open database document [error: \(String(describing: errorMessage))]")
                self.stopObservingProgress()
                self.notifier.notifyDatabaseLoadError(
                    database: self.dbRef,
                    isCancelled: self.progress.isCancelled,
                    message: NSLocalizedString("Cannot open database file", comment: "Error message"),
                    reason: errorMessage)
                self.endBackgroundTask()
            }
        )
    }
    
    private func onDatabaseDocumentOpened(_ dbDoc: DatabaseDocument) {
        progress.completedUnitCount += ProgressSteps.readDatabase
        
        guard let db = initDatabase(signature: dbDoc.encryptedData) else {
            Diag.error("Unrecognized database format [firstBytes: \(dbDoc.encryptedData.prefix(8).asHexString)]")
            stopObservingProgress()
            notifier.notifyDatabaseLoadError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: NSLocalizedString("Unrecognized database format", comment: "Error message"),
                reason: nil)
            endBackgroundTask()
            return
        }
        
        dbDoc.database = db
        if let compositeKey = compositeKey {
            progress.completedUnitCount += ProgressSteps.readKeyFile
            Diag.info("Using a ready composite key")
            onCompositeKeyReady(dbDoc: dbDoc, compositeKey: compositeKey)
            return
        }
        
        if let keyFileRef = keyFileRef {
            Diag.debug("Loading key file")
            progress.localizedDescription = NSLocalizedString("Loading key file...", comment: "Status message: loading key file in progress")
            let keyFileURL: URL
            do {
                keyFileURL = try keyFileRef.resolve()
            } catch {
                Diag.error("Failed to resolve key file URL reference [error: \(error.localizedDescription)]")
                stopObservingProgress()
                notifier.notifyDatabaseLoadError(
                    database: dbRef,
                    isCancelled: progress.isCancelled,
                    message: NSLocalizedString("Cannot find key file", comment: "Error message"),
                    reason: error.localizedDescription)
                endBackgroundTask()
                return
            }
            
            let keyDoc = FileDocument(fileURL: keyFileURL)
            keyDoc.open(
                successHandler: {
                    self.onKeyFileDataReady(dbDoc: dbDoc, keyFileData: keyDoc.data)
                },
                errorHandler: {
                    (error) in
                    Diag.error("Failed to open key file [error: \(error.localizedDescription)]")
                    self.stopObservingProgress()
                    self.notifier.notifyDatabaseLoadError(
                        database: self.dbRef,
                        isCancelled: self.progress.isCancelled,
                        message: NSLocalizedString("Cannot open key file", comment: "Error message"),
                        reason: error.localizedDescription)
                    self.endBackgroundTask()
                }
            )
        } else {
            onKeyFileDataReady(dbDoc: dbDoc, keyFileData: ByteArray())
        }
    }
    
    private func onKeyFileDataReady(dbDoc: DatabaseDocument, keyFileData: ByteArray) {
        guard let database = dbDoc.database else { fatalError() }
        
        progress.completedUnitCount += ProgressSteps.readKeyFile
        let keyHelper = database.keyHelper
        let passwordData = keyHelper.getPasswordData(password: password)
        if passwordData.isEmpty && keyFileData.isEmpty {
            Diag.error("Both password and key file are empty")
            stopObservingProgress()
            notifier.notifyDatabaseInvalidMasterKey(
                database: dbRef,
                message: NSLocalizedString(
                    "Please provide at least a password or a key file",
                    comment: "Error message"))
            endBackgroundTask()
            return
        }
        let compositeKey = keyHelper.makeCompositeKey(
            passwordData: passwordData,
            keyFileData: keyFileData)
        onCompositeKeyReady(dbDoc: dbDoc, compositeKey: compositeKey)
    }
    
    func onCompositeKeyReady(dbDoc: DatabaseDocument, compositeKey: SecureByteArray) {
        guard let db = dbDoc.database else { fatalError() }
        do {
            progress.addChild(db.initProgress(), withPendingUnitCount: ProgressSteps.decryptDatabase)
            Diag.info("Loading database")
            try db.load(
                dbFileData: dbDoc.encryptedData,
                compositeKey: compositeKey,
                warnings: warnings
            )
            Diag.info("Database loaded OK")
            progress.localizedDescription = NSLocalizedString("Done", comment: "Status message: operation completed")
            completion(dbDoc, dbRef)
            stopObservingProgress()
            notifier.notifyDatabaseDidLoad(database: dbRef, warnings: warnings)
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
                notifier.notifyDatabaseLoadError(
                    database: dbRef,
                    isCancelled: progress.isCancelled,
                    message: error.localizedDescription,
                    reason: error.failureReason)
                endBackgroundTask()
            case .invalidKey:
                Diag.error("Invalid master key. [message: \(error.localizedDescription)]")
                stopObservingProgress()
                notifier.notifyDatabaseInvalidMasterKey(
                    database: dbRef,
                    message: error.localizedDescription)
                endBackgroundTask()
            case .saveError:
                Diag.error("saveError while loading?!")
                fatalError("Database saving error while loading?!")
            }
        } catch let error as ProgressInterruption {
            dbDoc.database = nil
            dbDoc.close(completionHandler: nil)
            switch error {
            case .cancelled(let reason):
                Diag.info("Database loading was cancelled. [reason: \(reason.localizedDescription)]")
                stopObservingProgress()
                switch reason {
                case .userRequest:
                    notifier.notifyDatabaseLoadError(
                        database: dbRef,
                        isCancelled: true,
                        message: error.localizedDescription,
                        reason: error.failureReason)
                case .lowMemoryWarning:
                    notifier.notifyDatabaseLoadError(
                        database: dbRef,
                        isCancelled: false,
                        message: error.localizedDescription,
                        reason: nil)
                }
                endBackgroundTask()
            }
        } catch {
            dbDoc.database = nil
            dbDoc.close(completionHandler: nil)
            Diag.error("Unexpected error [message: \(error.localizedDescription)]")
            stopObservingProgress()
            notifier.notifyDatabaseLoadError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: error.localizedDescription,
                reason: nil)
            endBackgroundTask()
        }
    }
}


fileprivate class DatabaseSaver {
    private let dbDoc: DatabaseDocument
    private let dbRef: URLReference
    private let progress: ProgressEx
    private var progressKVO: NSKeyValueObservation?
    private unowned var notifier: DatabaseManager
    private let completion: ((DatabaseDocument) -> Void)

    init(
        databaseDocument dbDoc: DatabaseDocument,
        databaseRef dbRef: URLReference,
        progress: ProgressEx,
        completion: @escaping((DatabaseDocument) -> Void))
    {
        assert(dbDoc.documentState.contains(.normal))
        self.dbDoc = dbDoc
        self.dbRef = dbRef
        self.progress = progress
        notifier = DatabaseManager.shared
        self.completion = completion
    }
    
    private func startObservingProgress() {
        assert(progressKVO == nil)
        progressKVO = progress.observe(
            \.fractionCompleted,
            options: [.new],
            changeHandler: {
                [weak self] (progress, _) in
                guard let _self = self else { return }
                _self.notifier.notifyProgressDidChange(
                    database: _self.dbRef,
                    progress: _self.progress
                )
            }
        )
    }
    
    private func stopObservingProgress() {
        assert(progressKVO != nil)
        progressKVO?.invalidate()
        progressKVO = nil
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
    
    
    func save() {
        guard let database = dbDoc.database else { fatalError("Database is nil") }
        startBackgroundTask()
        startObservingProgress()
        do {
            if Settings.current.isBackupDatabaseOnSave {
                FileKeeper.shared.makeBackup(
                    nameTemplate: dbRef.info.fileName,
                    contents: dbDoc.encryptedData)
            }

            progress.addChild(
                database.initProgress(),
                withPendingUnitCount: ProgressSteps.encryptDatabase)
            Diag.info("Encrypting database")
            let outData = try database.save() 
            Diag.info("Writing database document")
            dbDoc.encryptedData = outData
            dbDoc.save(
                successHandler: {
                    self.progress.completedUnitCount += ProgressSteps.writeDatabase
                    Diag.info("Database saved OK")
                    self.stopObservingProgress()
                    self.notifier.notifyDatabaseDidSave(database: self.dbRef)
                    self.completion(self.dbDoc)
                    self.endBackgroundTask()
                },
                errorHandler: {
                    (errorMessage) in
                    Diag.error("Database saving error. [message: \(String(describing: errorMessage))]")
                    self.stopObservingProgress()
                    self.notifier.notifyDatabaseSaveError(
                        database: self.dbRef,
                        isCancelled: self.progress.isCancelled,
                        message: errorMessage ?? "",
                        reason: nil)
                    self.endBackgroundTask()
                }
            )
        } catch let error as DatabaseError {
            Diag.error("""
                Database saving error. [
                    isCancelled: \(progress.isCancelled),
                    message: \(error.localizedDescription),
                    reason: \(String(describing: error.failureReason))]
                """)
            stopObservingProgress()
            notifier.notifyDatabaseSaveError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: error.localizedDescription,
                reason: error.failureReason)
            endBackgroundTask()
        } catch let error as ProgressInterruption {
            stopObservingProgress()
            switch error {
            case .cancelled(let reason):
                Diag.error("Database saving was cancelled. [reason: \(reason.localizedDescription)]")
                switch reason {
                case .userRequest:
                    notifier.notifyDatabaseSaveError(
                        database: dbRef,
                        isCancelled: true,
                        message: error.localizedDescription,
                        reason: nil)
                case .lowMemoryWarning:
                    notifier.notifyDatabaseSaveError(
                        database: dbRef,
                        isCancelled: false,
                        message: error.localizedDescription,
                        reason: nil)
                }
                endBackgroundTask()
            }
        } catch { 
            Diag.error("Database saving error. [isCancelled: \(progress.isCancelled), message: \(error.localizedDescription)]")
            stopObservingProgress()
            notifier.notifyDatabaseSaveError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: error.localizedDescription,
                reason: nil)
            endBackgroundTask()
        }
    }
}
