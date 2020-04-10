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
        completion callback: ((String?) -> Void)?)
    {
        guard database != nil else { return }
        Diag.verbose("Will queue close database")

        if clearStoredKey, let urlRef = databaseRef {
            DatabaseSettingsManager.shared.updateSettings(for: urlRef) { (dbSettings) in
                dbSettings.clearMasterKey()
                Diag.verbose("Master key cleared")
            }
        }

        serialDispatchQueue.async {
            guard let dbDoc = self.databaseDocument else { return }
            Diag.debug("Will close database")
            
            let completionSemaphore = DispatchSemaphore(value: 0)
            
            DispatchQueue.main.async {
                dbDoc.close(successHandler: { 
                    self.handleDatabaseClosing()
                    callback?(nil)
                    completionSemaphore.signal()
                }, errorHandler: { errorMessage in 
                    Diag.error("Failed to save database document [message: \(String(describing: errorMessage))]")
                    let adjustedErrorMessage: String?
                    if ignoreErrors {
                        Diag.warning("Ignoring errors and closing anyway")
                        self.handleDatabaseClosing()
                        adjustedErrorMessage = nil
                    } else {
                        adjustedErrorMessage = errorMessage
                    }
                    callback?(adjustedErrorMessage)
                    completionSemaphore.signal()
                })
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
    
    public func startLoadingDatabase(database dbRef: URLReference, compositeKey: CompositeKey) {
        Diag.verbose("Will queue load database")
        let compositeKeyClone = compositeKey.clone()
        serialDispatchQueue.async {
            self._loadDatabase(dbRef: dbRef, compositeKey: compositeKeyClone)
        }
    }
    
    private func _loadDatabase(dbRef: URLReference, compositeKey: CompositeKey) {
        precondition(database == nil, "Can only load one database at a time")

        Diag.info("Will load database")
        progress = ProgressEx()
        progress.totalUnitCount = ProgressSteps.all
        progress.completedUnitCount = 0
        
        precondition(databaseLoader == nil)
        databaseLoader = DatabaseLoader(
            dbRef: dbRef,
            compositeKey: compositeKey,
            progress: progress,
            completion: databaseLoaderFinished)
        databaseLoader!.load()
    }
    
    private func databaseLoaderFinished(_ dbRef: URLReference, _ dbDoc: DatabaseDocument?) {
        self.databaseRef = dbRef
        self.databaseDocument = dbDoc
        self.databaseLoader = nil
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
        progress.completedUnitCount = 0
        notifyDatabaseWillSave(database: dbRef)
        
        precondition(databaseSaver == nil)
        databaseSaver = DatabaseSaver(
            databaseDocument: dbDoc,
            databaseRef: dbRef,
            progress: progress,
            completion: databaseSaverFinished)
        databaseSaver!.save()
    }
    
    private func databaseSaverFinished(_ urlRef: URLReference, _ dbDoc: DatabaseDocument) {
        databaseSaver = nil
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
        let dataReadyHandler = { (keyFileData: ByteArray) -> Void in
            let passwordData = keyHelper.getPasswordData(password: password)
            if passwordData.isEmpty && keyFileData.isEmpty {
                Diag.error("Password and key file are both empty")
                errorHandler(NSLocalizedString(
                    "[Database/Unlock/Error] Password and key file are both empty.",
                    bundle: Bundle.framework,
                    value: "Password and key file are both empty.",
                    comment: "Error message"))
                return
            }
            let staticComponents = keyHelper.combineComponents(
                passwordData: passwordData, 
                keyFileData: keyFileData    
            )
            let compositeKey = CompositeKey(
                staticComponents: staticComponents,
                challengeHandler: challengeHandler)
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
                    errorHandler(NSLocalizedString(
                        "[Database/Unlock/Error] Failed to open key file",
                        bundle: Bundle.framework,
                        value: "Failed to open key file",
                        comment: "Error message")
                    )
                })
            } catch {
                Diag.error("Failed to open key file [error: \(error.localizedDescription)]")
                errorHandler(NSLocalizedString(
                    "[Database/Unlock/Error] Failed to open key file",
                    bundle: Bundle.framework,
                    value: "Failed to open key file",
                    comment: "Error message")
                )
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

        self.databaseDocument = DatabaseDocument(fileURL: databaseURL)
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


    fileprivate func notifyDatabaseWillLoad(database urlRef: URLReference) {
        notificationQueue.async { 
            for (_, observer) in self.observers {
                guard let strongObserver = observer.observer else { continue }
                DispatchQueue.main.async {
                    strongObserver.databaseManager(willLoadDatabase: urlRef)
                }
            }
        }
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


fileprivate class DatabaseLoader {
    typealias CompletionHandler = (URLReference, DatabaseDocument?) -> Void
    
    private let dbRef: URLReference
    private let compositeKey: CompositeKey
    private let progress: ProgressEx
    private var progressKVO: NSKeyValueObservation?
    private unowned var notifier: DatabaseManager
    private let warnings: DatabaseLoadingWarnings
    private let completion: CompletionHandler
    
    init(
        dbRef: URLReference,
        compositeKey: CompositeKey,
        progress: ProgressEx,
        completion: @escaping(CompletionHandler))
    {
        assert(compositeKey.state != .empty)
        self.dbRef = dbRef
        self.compositeKey = compositeKey
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
                message: NSLocalizedString(
                    "[Database/Load/Error] Cannot find database file",
                    bundle: Bundle.framework,
                    value: "Cannot find database file",
                    comment: "Error message"),
                reason: error.localizedDescription)
            completion(dbRef, nil)
            endBackgroundTask()
            return
        }
        
        let dbDoc = DatabaseDocument(fileURL: dbURL)
        progress.status = NSLocalizedString(
            "[Database/Progress] Loading database file...",
            bundle: Bundle.framework,
            value: "Loading database file...",
            comment: "Progress bar status")
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
                    message: NSLocalizedString(
                        "[Database/Load/Error] Cannot open database file",
                        bundle: Bundle.framework,
                        value: "Cannot open database file",
                        comment: "Error message"),
                    reason: errorMessage)
                self.completion(self.dbRef, nil)
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
                message: NSLocalizedString(
                    "[Database/Load/Error] Unrecognized database format",
                    bundle: Bundle.framework,
                    value: "Unrecognized database format",
                    comment: "Error message"),
                reason: nil)
            completion(dbRef, nil)
            endBackgroundTask()
            return
        }
        
        dbDoc.database = db
        guard compositeKey.state == .rawComponents else {
            
            progress.completedUnitCount += ProgressSteps.readKeyFile
            Diag.info("Using a ready composite key")
            onCompositeKeyComponentsProcessed(dbDoc: dbDoc, compositeKey: compositeKey)
            return
        }
        
        if let keyFileRef = compositeKey.keyFileRef {
            Diag.debug("Loading key file")
            progress.localizedDescription = NSLocalizedString(
                "[Database/Progress] Loading key file...",
                bundle: Bundle.framework,
                value: "Loading key file...",
                comment: "Progress status")
            
            let keyFileURL: URL
            do {
                keyFileURL = try keyFileRef.resolve()
            } catch {
                Diag.error("Failed to resolve key file URL reference [error: \(error.localizedDescription)]")
                stopObservingProgress()
                notifier.notifyDatabaseLoadError(
                    database: dbRef,
                    isCancelled: progress.isCancelled,
                    message: NSLocalizedString(
                        "[Database/Load/Error] Cannot find key file",
                        bundle: Bundle.framework,
                        value: "Cannot find key file",
                        comment: "Error message"),
                    reason: error.localizedDescription)
                completion(dbRef, nil)
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
                        message: NSLocalizedString(
                            "[Database/Load/Error] Cannot open key file",
                            bundle: Bundle.framework,
                            value: "Cannot open key file",
                            comment: "Error message"),
                        reason: error.localizedDescription)
                    self.completion(self.dbRef, nil)
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
        let passwordData = keyHelper.getPasswordData(password: compositeKey.password)
        if passwordData.isEmpty && keyFileData.isEmpty {
            Diag.error("Both password and key file are empty")
            stopObservingProgress()
            notifier.notifyDatabaseInvalidMasterKey(
                database: dbRef,
                message: NSLocalizedString(
                    "[Database/Load/Error] Please provide at least a password or a key file",
                    bundle: Bundle.framework,
                    value: "Please provide at least a password or a key file",
                    comment: "Error shown when both master password and key file are empty"))
            completion(dbRef, nil)
            endBackgroundTask()
            return
        }
        compositeKey.setProcessedComponents(passwordData: passwordData, keyFileData: keyFileData)
        onCompositeKeyComponentsProcessed(dbDoc: dbDoc, compositeKey: compositeKey)
    }
    
    func onCompositeKeyComponentsProcessed(dbDoc: DatabaseDocument, compositeKey: CompositeKey) {
        assert(compositeKey.state >= .processedComponents)
        guard let db = dbDoc.database else { fatalError() }
        do {
            progress.addChild(db.initProgress(), withPendingUnitCount: ProgressSteps.decryptDatabase)
            Diag.info("Loading database")
            try db.load(
                dbFileName: dbDoc.fileURL.lastPathComponent,
                dbFileData: dbDoc.encryptedData,
                compositeKey: compositeKey,
                warnings: warnings)
            Diag.info("Database loaded OK")
            progress.localizedDescription = NSLocalizedString(
                "[Database/Progress] Done",
                bundle: Bundle.framework,
                value: "Done",
                comment: "Progress status: finished loading database")
            completion(dbRef, dbDoc)
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
            case .invalidKey:
                Diag.error("Invalid master key. [message: \(error.localizedDescription)]")
                stopObservingProgress()
                notifier.notifyDatabaseInvalidMasterKey(
                    database: dbRef,
                    message: error.localizedDescription)
            case .saveError:
                Diag.error("saveError while loading?!")
                fatalError("Database saving error while loading?!")
            }
            completion(dbRef, nil)
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
                completion(dbRef, nil)
                endBackgroundTask()
            }
        } catch {
            assertionFailure("Unprocessed exception")
            dbDoc.database = nil
            dbDoc.close(completionHandler: nil)
            Diag.error("Unexpected error [message: \(error.localizedDescription)]")
            stopObservingProgress()
            notifier.notifyDatabaseLoadError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: error.localizedDescription,
                reason: nil)
            completion(dbRef, nil)
            endBackgroundTask()
        }
    }
}


fileprivate class DatabaseSaver {
    typealias CompletionHandler = (URLReference, DatabaseDocument) -> Void
    
    private let dbDoc: DatabaseDocument
    private let dbRef: URLReference
    private let progress: ProgressEx
    private var progressKVO: NSKeyValueObservation?
    private unowned var notifier: DatabaseManager
    private let completion: CompletionHandler

    init(
        databaseDocument dbDoc: DatabaseDocument,
        databaseRef dbRef: URLReference,
        progress: ProgressEx,
        completion: @escaping(CompletionHandler))
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
                    self.completion(self.dbRef, self.dbDoc)
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
                    self.completion(self.dbRef, self.dbDoc)
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
            completion(dbRef, dbDoc)
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
                completion(dbRef, dbDoc)
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
            completion(dbRef, dbDoc)
            endBackgroundTask()
        }
    }
}
