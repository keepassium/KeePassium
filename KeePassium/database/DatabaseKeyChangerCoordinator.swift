//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseKeyChangerCoordinatorDelegate: AnyObject {
    func didChangeDatabaseKey(in coordinator: DatabaseKeyChangerCoordinator)
}

final class DatabaseKeyChangerCoordinator: Coordinator, DatabaseSaving {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: DatabaseKeyChangerCoordinatorDelegate?
    
    private let router: NavigationRouter
    private let databaseKeyChangerVC: DatabaseKeyChangerVC
    private let databaseRef: URLReference
    
    var databaseExporterTemporaryURL: TemporaryFileURL?
    
    init(databaseRef: URLReference, router: NavigationRouter) {
        self.router = router
        self.databaseRef = databaseRef
        databaseKeyChangerVC = DatabaseKeyChangerVC.make(for: databaseRef)
        databaseKeyChangerVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        if router.navigationController.topViewController == nil {
            let leftButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(didPressDismissButton))
            databaseKeyChangerVC.navigationItem.leftBarButtonItem = leftButton
        }
        router.push(databaseKeyChangerVC, animated: true, onPop: { [weak self] coordinator in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    @objc private func didPressDismissButton() {
        router.dismiss(animated: true)
    }
}

extension DatabaseKeyChangerCoordinator {
    func showKeyFilePicker(at popoverAnchor: PopoverAnchor) {
        let isAlreadyShown = childCoordinators.contains(where: { $0 is KeyFilePickerCoordinator })
        guard !isAlreadyShown else {
            assertionFailure()
            Diag.warning("Key file picker is already shown")
            return
        }
        
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let keyFilePickerCoordinator = KeyFilePickerCoordinator(router: modalRouter, addingMode: .import)
        keyFilePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        keyFilePickerCoordinator.delegate = self
        keyFilePickerCoordinator.start()
        router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(keyFilePickerCoordinator)
    }

    private func showHardwareKeyPicker(at popoverAnchor: PopoverAnchor) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let hardwareKeyPickerCoordinator = HardwareKeyPickerCoordinator(router: modalRouter)
        hardwareKeyPickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        hardwareKeyPickerCoordinator.delegate = self
        hardwareKeyPickerCoordinator.setSelectedKey(databaseKeyChangerVC.yubiKey)
        hardwareKeyPickerCoordinator.start()
        router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(hardwareKeyPickerCoordinator)
    }
    
    private func showDiagnostics() {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()
        
        router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator)
    }
    
    private func applyChangesAndSaveDatabase() {
        guard let db = DatabaseManager.shared.database else {
            assertionFailure()
            return
        }
        
        let newPassword = databaseKeyChangerVC.password
        let newKeyFile = databaseKeyChangerVC.keyFileRef
        let newYubiKey = databaseKeyChangerVC.yubiKey
        let _challengeHandler = ChallengeResponseManager.makeHandler(for: newYubiKey)
        DatabaseManager.createCompositeKey(
            keyHelper: db.keyHelper,
            password: newPassword,
            keyFile: newKeyFile,
            challengeHandler: _challengeHandler,
            success: {
                [weak self] (_ newCompositeKey: CompositeKey) -> Void in
                guard let self = self else { return }
                let dbm = DatabaseManager.shared
                dbm.changeCompositeKey(to: newCompositeKey)
                DatabaseSettingsManager.shared.updateSettings(for: self.databaseRef) {
                    (dbSettings) in
                    dbSettings.maybeSetMasterKey(newCompositeKey)
                    dbSettings.maybeSetAssociatedKeyFile(newKeyFile)
                    dbSettings.maybeSetAssociatedYubiKey(newYubiKey)
                }
                self.saveDatabase()
            },
            error: {
                [weak self] (_ errorMessage: String) -> Void in
                guard let self = self else { return }
                Diag.error("Failed to create new composite key [message: \(errorMessage)]")
                self.databaseKeyChangerVC.showErrorAlert(errorMessage, title: LString.titleError)
            }
        )
    }
    
    private func saveDatabase() {
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
}

extension DatabaseKeyChangerCoordinator: DatabaseKeyChangerDelegate {
    func didPressSelectKeyFile(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseKeyChangerVC
    ) {
        showKeyFilePicker(at: popoverAnchor)
    }
    
    func didPressSelectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseKeyChangerVC
    ) {
        showHardwareKeyPicker(at: popoverAnchor)
    }
    
    func didPressSaveChanges(in viewController: DatabaseKeyChangerVC) {
        applyChangesAndSaveDatabase()
    }
}

extension DatabaseKeyChangerCoordinator: KeyFilePickerCoordinatorDelegate {
    func didPickKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference?) {
        databaseKeyChangerVC.setKeyFile(keyFile)
    }
    
    func didRemoveOrDeleteKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference) {
        if databaseKeyChangerVC.keyFileRef == keyFile {
            databaseKeyChangerVC.setKeyFile(nil)
        }
    }
}

extension DatabaseKeyChangerCoordinator: HardwareKeyPickerCoordinatorDelegate {
    func didSelectKey(_ yubiKey: YubiKey?, in coordinator: HardwareKeyPickerCoordinator) {
        databaseKeyChangerVC.setYubiKey(yubiKey)
    }
}

extension DatabaseKeyChangerCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        router.showProgressView(title: LString.databaseStatusSaving, allowCancelling: false)
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        Diag.info("Master key change cancelled")
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        Diag.info("Master key change saved")
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        router.pop(animated: true, completion: { [self] in
            self.delegate?.didChangeDatabaseKey(in: self)
        })
    }
    
    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?
    ) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: { [weak self] in
                self?.showDiagnostics()
            },
            exportableData: data,
            parent: databaseKeyChangerVC
        )
    }
}
