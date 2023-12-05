//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseKeyChangerCoordinatorDelegate: AnyObject {
    func didChangeDatabaseKey(in coordinator: DatabaseKeyChangerCoordinator)

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

final class DatabaseKeyChangerCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: DatabaseKeyChangerCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseKeyChangerVC: DatabaseKeyChangerVC

    private let databaseFile: DatabaseFile
    private let database: Database

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }
    var saveSuccessHandler: (() -> Void)?

    init(databaseFile: DatabaseFile, router: NavigationRouter) {
        self.router = router
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        databaseKeyChangerVC = DatabaseKeyChangerVC.make(for: databaseFile)
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
        router.push(databaseKeyChangerVC, animated: true, onPop: { [weak self] in
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
        let keyFilePickerCoordinator = KeyFilePickerCoordinator(router: modalRouter)
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
        let newPassword = databaseKeyChangerVC.password
        let newKeyFile = databaseKeyChangerVC.keyFileRef
        let newYubiKey = databaseKeyChangerVC.yubiKey

        database.keyHelper.createCompositeKey(
            password: newPassword,
            keyFile: newKeyFile,
            challengeHandler: ChallengeResponseManager.makeHandler(for: newYubiKey),
            completion: { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let newCompositeKey):
                    self.database.changeCompositeKey(to: newCompositeKey)
                    DatabaseSettingsManager.shared.updateSettings(for: self.databaseFile) { dbSettings in
                        dbSettings.maybeSetMasterKey(newCompositeKey)
                        dbSettings.maybeSetAssociatedKeyFile(newKeyFile)
                        dbSettings.maybeSetAssociatedYubiKey(newYubiKey)
                    }
                    self.saveDatabase(self.databaseFile)
                case .failure(let errorMessage):
                    Diag.error("Failed to create new composite key [message: \(errorMessage)]")
                    self.databaseKeyChangerVC.showErrorAlert(errorMessage, title: LString.titleError)
                }
            }
        )
    }
}

extension DatabaseKeyChangerCoordinator: DatabaseKeyChangerDelegate {
    func didPressSelectKeyFile(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseKeyChangerVC
    ) {
        router.dismissModals(animated: false, completion: { [weak self] in
            self?.showKeyFilePicker(at: popoverAnchor)
        })
    }

    func didPressSelectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseKeyChangerVC
    ) {
        router.dismissModals(animated: false, completion: { [weak self] in
            self?.showHardwareKeyPicker(at: popoverAnchor)
        })
    }

    func shouldDismissPopovers(in viewController: DatabaseKeyChangerVC) {
        router.dismissModals(animated: false, completion: nil)
    }

    func didPressSaveChanges(in viewController: DatabaseKeyChangerVC) {
        applyChangesAndSaveDatabase()
    }
}

extension DatabaseKeyChangerCoordinator: KeyFilePickerCoordinatorDelegate {
    func didPickKeyFile(_ keyFile: URLReference?, in coordinator: KeyFilePickerCoordinator) {
        databaseKeyChangerVC.setKeyFile(keyFile)
    }

    func didEliminateKeyFile(_ keyFile: URLReference, in coordinator: KeyFilePickerCoordinator) {
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

extension DatabaseKeyChangerCoordinator: DatabaseSaving {
    func canCancelSaving(databaseFile: DatabaseFile) -> Bool {
        return false
    }

    func didSave(databaseFile: DatabaseFile) {
        Diag.info("Master key change saved")
        router.pop(animated: true) { [self] in
            self.delegate?.didChangeDatabaseKey(in: self)
        }
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return databaseKeyChangerVC
    }

    func getDiagnosticsHandler() -> (() -> Void)? {
        return showDiagnostics
    }
}
