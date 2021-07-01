//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

typealias DatabaseUnlockResult = Result<Database, Error>

protocol DatabaseUnlockerCoordinatorDelegate: AnyObject {
    func shouldAutoUnlockDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> Bool
    func willUnlockDatabase(_ fileRef: URLReference, in coordinator: DatabaseUnlockerCoordinator)
    func didNotUnlockDatabase(
        _ fileRef: URLReference,
        with message: String?,
        reason: String?,
        in coordinator: DatabaseUnlockerCoordinator
    )
    func didUnlockDatabase(
        _ fileRef: URLReference,
        database: Database,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    )
}

final class DatabaseUnlockerCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: DatabaseUnlockerCoordinatorDelegate?
    
    private let router: NavigationRouter
    private let databaseUnlockerVC: DatabaseUnlockerVC
    
    private var databaseRef: URLReference
    private var selectedKeyFileRef: URLReference?
    private var selectedHardwareKey: YubiKey?
    
    private var mayUseFinalKey = true
    
    init(router: NavigationRouter, databaseRef: URLReference) {
        self.router = router
        self.databaseRef = databaseRef

        databaseUnlockerVC = DatabaseUnlockerVC.instantiateFromStoryboard()
        databaseUnlockerVC.delegate = self
        databaseUnlockerVC.shouldAutofocus = true
        databaseUnlockerVC.databaseRef = databaseRef
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        router.push(databaseUnlockerVC, animated: true, onPop: { [weak self] viewController in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    func refresh() {
        databaseUnlockerVC.refresh()
    }
    
    func setDatabase(_ fileRef: URLReference) {
        databaseRef = fileRef
        databaseUnlockerVC.databaseRef = fileRef
        
        guard let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef) else {
            refresh()
            return
        }
        
        if let associatedKeyFileRef = dbSettings.associatedKeyFile {
            let allKeyFiles = FileKeeper.shared.getAllReferences(
                fileType: .keyFile,
                includeBackup: false)
            let matchingKeyFile = associatedKeyFileRef.find(
                in: allKeyFiles,
                fallbackToNamesake: true)
            setKeyFile(matchingKeyFile) 
        } else {
            setKeyFile(nil)
        }

        let associatedYubiKey = dbSettings.associatedYubiKey
        setHardwareKey(associatedYubiKey) 
        
        mayUseFinalKey = true
        refresh()
    }
}

extension DatabaseUnlockerCoordinator {
    private func disableNavigation() {
        router.navigationController.navigationItem.setHidesBackButton(true, animated: false)
    }
    private func enableNavigation() {
        router.navigationController.navigationItem.setHidesBackButton(false, animated: true)
    }
    
    private func showDiagnostics(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator)
    }
    
    private func selectKeyFile(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let keyFilePickerCoordinator = KeyFilePickerCoordinator(
            router: modalRouter,
            addingMode: .openInPlace
        )
        keyFilePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        keyFilePickerCoordinator.delegate = self
        keyFilePickerCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(keyFilePickerCoordinator)
    }
    
    private func selectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let hardwareKeyPickerCoordinator = HardwareKeyPickerCoordinator(router: modalRouter)
        hardwareKeyPickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        hardwareKeyPickerCoordinator.delegate = self
        hardwareKeyPickerCoordinator.setSelectedKey(selectedHardwareKey)
        hardwareKeyPickerCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(hardwareKeyPickerCoordinator)
    }
    
    private func setKeyFile(_ fileRef: URLReference?) {
        selectedKeyFileRef = fileRef
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { dbSettings in
            dbSettings.maybeSetAssociatedKeyFile(fileRef)
        }
        
        databaseUnlockerVC.setKeyFile(fileRef)
        databaseUnlockerVC.refresh()
    }
    
    private func setHardwareKey(_ yubiKey: YubiKey?) {
        selectedHardwareKey = yubiKey
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { dbSettings in
            dbSettings.maybeSetAssociatedYubiKey(yubiKey)
        }
        databaseUnlockerVC.setYubiKey(yubiKey)
        databaseUnlockerVC.refresh()
    }
    
    #if AUTOFILL_EXT
    private func challengeHandlerForAutoFill(
        challenge: SecureByteArray,
        responseHandler: @escaping ResponseHandler)
    {
        Diag.warning("YubiKey is not available in AutoFill")
        responseHandler(SecureByteArray(), .notAvailableInAutoFill)
    }
    #endif
    
    private func canUnlockAutomatically() -> Bool {
        guard let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef) else {
            return false
        }
        return dbSettings.hasMasterKey
    }
    
    private func maybeUnlockAutomatically() {
        guard canUnlockAutomatically() else {
            return
        }
        guard delegate?.shouldAutoUnlockDatabase(databaseRef, in: self) ?? false else {
            return
        }
        router.showProgressView(title: LString.databaseStatusLoading, allowCancelling: true, animated: false)
        disableNavigation()
        
        tryToUnlockDatabase()
    }

    private func tryToUnlockDatabase() {
        Diag.clear()

        delegate?.willUnlockDatabase(databaseRef, in: self)

        databaseUnlockerVC.hideErrorMessage(animated: false)
        DatabaseManager.shared.addObserver(self)
        
        #if AUTOFILL_EXT
        let challengeHandler = (selectedHardwareKey != nil) ? challengeHandlerForAutoFill : nil
        #elseif MAIN_APP
        let challengeHandler = ChallengeResponseManager.makeHandler(for: selectedHardwareKey)
        #endif
        
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef)
        if let databaseKey = dbSettings?.masterKey {
            databaseKey.challengeHandler = challengeHandler
            DatabaseManager.shared.startLoadingDatabase(
                database: databaseRef,
                compositeKey: databaseKey,
                canUseFinalKey: mayUseFinalKey)
        } else {
            mayUseFinalKey = false 
            let password = databaseUnlockerVC.password
            DatabaseManager.shared.startLoadingDatabase(
                database: databaseRef,
                password: password,
                keyFile: selectedKeyFileRef,
                challengeHandler: challengeHandler)
        }
    }
    
    private func eraseMasterKey() {
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) {
            $0.clearMasterKey()
        }
    }
}

extension DatabaseUnlockerCoordinator: DatabaseUnlockerDelegate {
    func willAppear(viewController: DatabaseUnlockerVC) {
        maybeUnlockAutomatically()
    }
    
    func didPressSelectKeyFile(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC
    ) {
        selectKeyFile(at: popoverAnchor, in: viewController)
    }
    
    func didPressSelectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC
    ) {
        selectHardwareKey(at: popoverAnchor, in: viewController)
    }

    func canUnlockAutomatically(_ viewController: DatabaseUnlockerVC) -> Bool {
        return canUnlockAutomatically()
    }
    func didPressUnlock(in viewController: DatabaseUnlockerVC) {
        tryToUnlockDatabase()
    }

    func didPressLock(in viewController: DatabaseUnlockerVC) {
        eraseMasterKey()
    }
    
    func didPressShowDiagnostics(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC
    ) {
        showDiagnostics(at: popoverAnchor, in: viewController)
    }
}

extension DatabaseUnlockerCoordinator: KeyFilePickerCoordinatorDelegate {
    func didPickKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference?) {
        databaseUnlockerVC.hideErrorMessage(animated: false)
        setKeyFile(keyFile)
    }
    
    func didRemoveOrDeleteKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference) {
        if keyFile == selectedKeyFileRef {
            databaseUnlockerVC.hideErrorMessage(animated: false)
            setKeyFile(nil)
        }
        databaseUnlockerVC.refresh()
    }
}

extension DatabaseUnlockerCoordinator: HardwareKeyPickerCoordinatorDelegate {
    func didSelectKey(_ yubiKey: YubiKey?, in coordinator: HardwareKeyPickerCoordinator) {
        databaseUnlockerVC.hideErrorMessage(animated: false)
        setHardwareKey(yubiKey)
    }
}

extension DatabaseUnlockerCoordinator: DatabaseManagerObserver {
    func databaseManager(willLoadDatabase urlRef: URLReference) {
        router.showProgressView(title: LString.databaseStatusLoading, allowCancelling: true)
        disableNavigation()
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { dbSettings in
            dbSettings.clearMasterKey()
        }
        databaseUnlockerVC.refresh()
        databaseUnlockerVC.clearPasswordField()
        router.hideProgressView()
        enableNavigation()
        
        databaseUnlockerVC.maybeFocusOnPassword()
        
        delegate?.didNotUnlockDatabase(databaseRef, with: nil, reason: nil, in: self)
    }
    
    func databaseManager(database urlRef: URLReference, invalidMasterKey message: String) {
        DatabaseManager.shared.removeObserver(self)
        if mayUseFinalKey {
            Diag.info("Express unlock failed, retrying slow")
            mayUseFinalKey = false
            tryToUnlockDatabase()
        } else {
            DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { dbSettings in
                dbSettings.clearMasterKey()
            }
            databaseUnlockerVC.refresh()
            router.hideProgressView()
            enableNavigation()
            
            databaseUnlockerVC.showErrorMessage(message, haptics: .wrongPassword)
            databaseUnlockerVC.maybeFocusOnPassword()
        }
        delegate?.didNotUnlockDatabase(databaseRef, with: message, reason: nil, in: self)
    }
    
    func databaseManager(database urlRef: URLReference, loadingError message: String, reason: String?) {
        DatabaseManager.shared.removeObserver(self)
        databaseUnlockerVC.refresh()
        router.hideProgressView()
        enableNavigation()
        
        if databaseRef.hasPermissionError257 || databaseRef.hasFileMissingError {
            databaseUnlockerVC.showErrorMessage(
                message,
                reason: reason,
                suggestion: LString.tryToReAddFile,
                haptics: .error
            )
        } else {
            databaseUnlockerVC.showErrorMessage(message, reason: reason, haptics: .error)
        }
        databaseUnlockerVC.maybeFocusOnPassword()
        delegate?.didNotUnlockDatabase(databaseRef, with: message, reason: reason, in: self)
    }
    
    func databaseManager(didLoadDatabase urlRef: URLReference, warnings: DatabaseLoadingWarnings) {
        DatabaseManager.shared.removeObserver(self)
        HapticFeedback.play(.databaseUnlocked)
        
        let database = DatabaseManager.shared.database!
        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { dbSettings in
            dbSettings.maybeSetMasterKey(of: database)
        }
        databaseUnlockerVC.clearPasswordField()
        
        delegate?.didUnlockDatabase(databaseRef, database: database, warnings: warnings, in: self)
    }
}
