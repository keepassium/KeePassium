//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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

final class DatabaseKeyChangerCoordinator: BaseCoordinator {
    weak var delegate: DatabaseKeyChangerCoordinatorDelegate?

    private let databaseKeyChangerVC: DatabaseKeyChangerVC

    private let databaseFile: DatabaseFile
    private let database: Database

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return _router }
    var saveSuccessHandler: (() -> Void)?

    init(databaseFile: DatabaseFile, router: NavigationRouter) {
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        databaseKeyChangerVC = DatabaseKeyChangerVC.make(for: databaseFile)
        super.init(router: router)
        databaseKeyChangerVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(databaseKeyChangerVC, dismissButtonStyle: .cancel, animated: true)
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
        keyFilePickerCoordinator.delegate = self
        keyFilePickerCoordinator.start()
        _router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(keyFilePickerCoordinator, onDismiss: nil)
    }

    private func showHardwareKeyPicker(at popoverAnchor: PopoverAnchor) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let hardwareKeyPickerCoordinator = HardwareKeyPickerCoordinator(router: modalRouter)
        hardwareKeyPickerCoordinator.delegate = self
        hardwareKeyPickerCoordinator.setSelectedKey(databaseKeyChangerVC.hardwareKey)
        hardwareKeyPickerCoordinator.start()
        _router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(hardwareKeyPickerCoordinator, onDismiss: nil)
    }

    private func showDiagnostics() {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.start()

        _router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator, onDismiss: nil)
    }

    private func applyChangesAndSaveDatabase() {
        let newPassword = databaseKeyChangerVC.password
        let newKeyFile = databaseKeyChangerVC.keyFileRef
        let newHardwareKey = databaseKeyChangerVC.hardwareKey

        database.keyHelper.createCompositeKey(
            password: newPassword,
            keyFile: newKeyFile,
            challengeHandler: ChallengeResponseManager.makeHandler(
                for: newHardwareKey,
                presenter: _router.navigationController.view
            ),
            completion: { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let newCompositeKey):
                    self.database.changeCompositeKey(to: newCompositeKey)
                    DatabaseSettingsManager.shared.updateSettings(for: self.databaseFile) { dbSettings in
                        dbSettings.maybeSetMasterKey(newCompositeKey)
                        dbSettings.maybeSetAssociatedKeyFile(newKeyFile)
                        dbSettings.maybeSetAssociatedHardwareKey(newHardwareKey)
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
        _router.dismissModals(animated: false, completion: { [weak self] in
            self?.showKeyFilePicker(at: popoverAnchor)
        })
    }

    func didPressSelectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseKeyChangerVC
    ) {
        _router.dismissModals(animated: false, completion: { [weak self] in
            self?.showHardwareKeyPicker(at: popoverAnchor)
        })
    }

    func shouldDismissPopovers(in viewController: DatabaseKeyChangerVC) {
        _router.dismissModals(animated: false, completion: nil)
    }

    func didPressSaveChanges(in viewController: DatabaseKeyChangerVC) {
        applyChangesAndSaveDatabase()
    }
}

extension DatabaseKeyChangerCoordinator: KeyFilePickerCoordinatorDelegate {
    func didSelectKeyFile(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in coordinator: KeyFilePickerCoordinator
    ) {
        assert(cause != nil, "Unexpected in single-panel mode")
        databaseKeyChangerVC.setKeyFile(fileRef)
    }

    func didEliminateKeyFile(_ keyFile: URLReference, in coordinator: KeyFilePickerCoordinator) {
        if databaseKeyChangerVC.keyFileRef == keyFile {
            databaseKeyChangerVC.setKeyFile(nil)
        }
    }
}

extension DatabaseKeyChangerCoordinator: HardwareKeyPickerCoordinatorDelegate {
    func didSelectKey(_ hardwareKey: HardwareKey?, in coordinator: HardwareKeyPickerCoordinator) {
        databaseKeyChangerVC.setHardwareKey(hardwareKey)
    }
}

extension DatabaseKeyChangerCoordinator: DatabaseSaving {
    func canCancelSaving(databaseFile: DatabaseFile) -> Bool {
        return false
    }

    func didSave(databaseFile: DatabaseFile) {
        Diag.info("Master key change saved")
        _router.pop(animated: true) { [self] in
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
