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
    
    static let didReadDatabaseFile: Int64 = -1
    static let didReadKeyFile: Int64 = -1
    static let willDecryptDatabase: Int64 = 0
    static let didDecryptDatabase: Int64 = 100

    static let willMakeBackup: Int64 = -1
    static let willEncryptDatabase: Int64 = 0
    static let didEncryptDatabase: Int64 = 90
    static let didWriteDatabase: Int64 = 100
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
        progress.completedUnitCount = ProgressSteps.start
        
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
        progress.completedUnitCount = ProgressSteps.start
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
                errorHandler(LString.Error.passwordAndKeyFileAreBothEmpty)
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
                        errorHandler(LString.Error.failedToOpenKeyFile)
                    }
                }
            case .failure(let accessError):
                Diag.error("Failed to open key file [error: \(accessError.localizedDescription)]")
                errorHandler(LString.Error.failedToOpenKeyFile)
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
    
    fileprivate static func shouldUpdateLatestBackup(for dbRef: URLReference) -> Bool {
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


fileprivate class ProgressObserver {
    internal let progress: ProgressEx
    private var progressFractionKVO: NSKeyValueObservation?
    private var progressDescriptionKVO: NSKeyValueObservation?
    
    init(progress: ProgressEx) {
        self.progress = progress
    }
    
    func startObservingProgress() {
        assert(progressFractionKVO == nil && progressDescriptionKVO == nil)
        progressFractionKVO = progress.observe(
            \.fractionCompleted,
            options: [.new],
            changeHandler: {
                [weak self] (progress, _) in
                self?.progressDidChange(progress: progress)
            }
        )
        progressDescriptionKVO = progress.observe(
            \.localizedDescription,
            options: [.new],
            changeHandler: {
                [weak self] (progress, _) in
                self?.progressDidChange(progress: progress)
            }
        )
    }
    
    func stopObservingProgress() {
        assert(progressFractionKVO != nil && progressDescriptionKVO != nil)
        progressFractionKVO?.invalidate()
        progressDescriptionKVO?.invalidate()
        progressFractionKVO = nil
        progressDescriptionKVO = nil
    }
    
    func progressDidChange(progress: ProgressEx) {
        assertionFailure("Override this")
    }
}


fileprivate class DatabaseLoader: ProgressObserver {
    typealias CompletionHandler = (URLReference, DatabaseDocument?) -> Void
    
    private let dbRef: URLReference
    private let compositeKey: CompositeKey
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
        self.completion = completion
        self.warnings = DatabaseLoadingWarnings()
        self.notifier = DatabaseManager.shared
        super.init(progress: progress)
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
    
    
    override func progressDidChange(progress: ProgressEx) {
        notifier.notifyProgressDidChange(
            database: dbRef,
            progress: progress)
    }
    
    
    func load() {
        startBackgroundTask()
        startObservingProgress()
        notifier.notifyDatabaseWillLoad(database: dbRef)
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
        notifier.notifyDatabaseLoadError(
            database: dbRef,
            isCancelled: progress.isCancelled,
            message: LString.Error.cannotFindDatabaseFile,
            reason: error.localizedDescription)
        completion(dbRef, nil)
        endBackgroundTask()
    }
    
    private func onDatabaseURLResolved(url: URL, fileProvider: FileProvider?) {
        let dbDoc = DatabaseDocument(fileURL: url, fileProvider: fileProvider)
        progress.status = LString.Progress.loadingDatabaseFile
        dbDoc.open { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                self.onDatabaseDocumentOpened(dbDoc: dbDoc, data: docData)
            case .failure(let fileAccessError):
                Diag.error("Failed to open database document [error: \(fileAccessError.localizedDescription)]")
                self.stopObservingProgress()
                self.notifier.notifyDatabaseLoadError(
                    database: self.dbRef,
                    isCancelled: self.progress.isCancelled,
                    message: LString.Error.cannotOpenDatabaseFile,
                    reason: fileAccessError.localizedDescription)
                self.completion(self.dbRef, nil)
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
            notifier.notifyDatabaseLoadError(
                database: dbRef,
                isCancelled: progress.isCancelled,
                message: LString.Error.unrecognizedDatabaseFormat,
                reason: nil)
            completion(dbRef, nil)
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
        notifier.notifyDatabaseLoadError(
            database: dbRef,
            isCancelled: progress.isCancelled,
            message: LString.Error.cannotFindKeyFile,
            reason: error.localizedDescription)
        completion(dbRef, nil)
        endBackgroundTask()
    }

    private func onKeyFileURLResolved(url: URL, fileProvider: FileProvider?, dbDoc: DatabaseDocument) {
        let keyDoc = BaseDocument(fileURL: url, fileProvider: fileProvider)
        keyDoc.open { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                self.onKeyFileDataReady(dbDoc: dbDoc, keyFileData: docData)
            case .failure(let fileAccessError):
                Diag.error("Failed to open key file [error: \(fileAccessError.localizedDescription)]")
                self.stopObservingProgress()
                self.notifier.notifyDatabaseLoadError(
                    database: self.dbRef,
                    isCancelled: self.progress.isCancelled,
                    message: LString.Error.cannotOpenKeyFile,
                    reason: fileAccessError.localizedDescription)
                self.completion(self.dbRef, nil)
                self.endBackgroundTask()
            }
        }
    }
    
    private func onKeyFileDataReady(dbDoc: DatabaseDocument, keyFileData: ByteArray) {
        guard let database = dbDoc.database else { fatalError() }
        
        progress.completedUnitCount = ProgressSteps.didReadKeyFile
        let keyHelper = database.keyHelper
        let passwordData = keyHelper.getPasswordData(password: compositeKey.password)
        if passwordData.isEmpty && keyFileData.isEmpty {
            Diag.error("Both password and key file are empty")
            stopObservingProgress()
            notifier.notifyDatabaseInvalidMasterKey(
                database: dbRef,
                message: LString.Error.needPasswordOrKeyFile)
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
                progress.status = LString.Progress.makingDatabaseBackup
                assert(dbRef.url != nil)
                FileKeeper.shared.makeBackup(
                    nameTemplate: dbRef.url?.lastPathComponent ?? "Backup",
                    mode: .latest,
                    contents: dbDoc.data)
            }
            
            progress.completedUnitCount = ProgressSteps.all
            progress.localizedDescription = LString.Progress.done
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


fileprivate class DatabaseSaver: ProgressObserver {
    typealias CompletionHandler = (URLReference, DatabaseDocument) -> Void
    
    private let dbDoc: DatabaseDocument
    private let dbRef: URLReference
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
        notifier = DatabaseManager.shared
        self.completion = completion
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
        notifier.notifyProgressDidChange(
            database: dbRef,
            progress: progress)
    }
    
    
    func save() {
        guard let database = dbDoc.database else { fatalError("Database is nil") }

        startBackgroundTask()
        startObservingProgress()
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
            dbDoc.save { [self] result in 
                switch result {
                case .success:
                    self.progress.status = LString.Progress.done
                    self.progress.completedUnitCount = ProgressSteps.didWriteDatabase
                    Diag.info("Database saved OK")
                    self.updateLatestBackup(with: outData)
                    self.stopObservingProgress()
                    self.notifier.notifyDatabaseDidSave(database: self.dbRef)
                    self.completion(self.dbRef, self.dbDoc)
                    self.endBackgroundTask()
                case .failure(let fileAccessError):
                    Diag.error("Database saving error. [message: \(fileAccessError.localizedDescription)]")
                    self.stopObservingProgress()
                    self.notifier.notifyDatabaseSaveError(
                        database: self.dbRef,
                        isCancelled: self.progress.isCancelled,
                        message: fileAccessError.localizedDescription,
                        reason: nil)
                    self.completion(self.dbRef, self.dbDoc)
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
