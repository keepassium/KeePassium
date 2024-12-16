//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol KeyFilePickerCoordinatorDelegate: AnyObject {
    func didPickKeyFile(_ keyFile: URLReference?, in coordinator: KeyFilePickerCoordinator)
    func didEliminateKeyFile(_ keyFile: URLReference, in coordinator: KeyFilePickerCoordinator)
}

class KeyFilePickerCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()

    weak var delegate: KeyFilePickerCoordinatorDelegate?
    var dismissHandler: CoordinatorDismissHandler?

    private var router: NavigationRouter
    private var keyFilePickerVC: KeyFilePickerVC
    private var documentPickerShouldAdd = true

    private var fileExportHelper: FileExportHelper?

    init(router: NavigationRouter) {
        self.router = router
        keyFilePickerVC = KeyFilePickerVC.create()
        super.init()

        keyFilePickerVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        start(selectedFile: nil)
    }

    func start(selectedFile: URLReference?) {
        if router.navigationController.topViewController == nil {
            let cancelButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(didPressDismissButton))
            keyFilePickerVC.navigationItem.leftBarButtonItem = cancelButton
        }

        router.push(keyFilePickerVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    @objc
    private func didPressDismissButton() {
        dismiss(animated: true)
    }

    private func dismiss(animated: Bool) {
        router.pop(viewController: keyFilePickerVC, animated: animated)
    }
}

extension KeyFilePickerCoordinator {
    private func showFileInfo(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let fileInfoCoordinator = FileInfoCoordinator(
            fileRef: fileRef,
            fileType: .keyFile,
            allowExport: false,
            router: modalRouter)
        fileInfoCoordinator.delegate = self
        fileInfoCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        fileInfoCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(fileInfoCoordinator)
    }

    func createKeyFile() {
        let keyFileData: ByteArray
        do {
            keyFileData = try KeyHelper.generateKeyFileData()
        } catch {
            keyFilePickerVC.showErrorAlert(error)
            return
        }

        fileExportHelper = FileExportHelper(data: keyFileData, fileName: LString.defaultKeyFileName)
        fileExportHelper!.handler = { [weak self] finalURL in
            self?.fileExportHelper = nil
            guard let self, let finalURL else {
                return
            }
            switch FileKeeper.shared.getLocation(for: finalURL) {
            case .internalDocuments:
                self.keyFilePickerVC.refresh()
            case .external:
                self.addKeyFile(url: finalURL, mode: .openInPlace)
            default:
                let message = "File generated in an unexpected location, aborting"
                Diag.warning(message)
                assertionFailure(message)
                return
            }
        }
        fileExportHelper!.saveAs(presenter: keyFilePickerVC)
    }
}

extension KeyFilePickerCoordinator: KeyFilePickerDelegate {
    func didPressImportKeyFile(at popoverAnchor: PopoverAnchor, in keyFilePicker: KeyFilePickerVC) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: FileType.keyFileUTIs)
        documentPickerShouldAdd = true
        picker.delegate = self
        picker.modalPresentationStyle = .pageSheet
        popoverAnchor.apply(to: picker.popoverPresentationController)
        router.present(picker, animated: true, completion: nil)
    }

    func didPressUseKeyFile(at popoverAnchor: PopoverAnchor, in keyFilePicker: KeyFilePickerVC) {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: FileType.keyFileUTIs)
        documentPickerShouldAdd = false
        picker.delegate = self
        picker.modalPresentationStyle = .pageSheet
        popoverAnchor.apply(to: picker.popoverPresentationController)
        router.present(picker, animated: true, completion: nil)
    }

    func didSelectFile(_ selectedFile: URLReference?, in keyFilePicker: KeyFilePickerVC) {
        delegate?.didPickKeyFile(selectedFile, in: self)
        dismiss(animated: true)
    }

    func didPressFileInfo(
        for keyFile: URLReference,
        at popoverAnchor: PopoverAnchor,
        in keyFilePicker: KeyFilePickerVC
    ) {
        showFileInfo(keyFile, at: popoverAnchor, in: keyFilePicker)
    }

    func didPressEliminate(
        keyFile: URLReference,
        at popoverAnchor: PopoverAnchor,
        in keyFilePicker: KeyFilePickerVC
    ) {
        Diag.debug("Will remove or delete key file")
        FileDestructionHelper.destroyFile(
            keyFile,
            fileType: .keyFile,
            withConfirmation: true,
            at: popoverAnchor,
            parent: keyFilePicker,
            completion: { [weak self] success in
                guard let self = self else { return }
                self.keyFilePickerVC.refresh()
                if success {
                    self.delegate?.didEliminateKeyFile(keyFile, in: self)
                }
            }
        )
    }

    func didPressCreateKeyFile(at popoverAnchor: PopoverAnchor, in keyFilePicker: KeyFilePickerVC) {
        createKeyFile()

    }
}

extension KeyFilePickerCoordinator: UIDocumentPickerDelegate {
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else { return }

        if documentPickerShouldAdd {
            addKeyFile(url: url)
        } else {
            returnFileReference(for: url)
        }
    }

    private func addKeyFile(url: URL, mode: FileKeeper.OpenMode? = nil) {
        guard !FileType.isDatabaseFile(url: url) else {
            showDatabaseAsKeyFileWarning()
            return
        }

        let addingMode = mode ?? (FileKeeper.shared.canActuallyAccessAppSandbox ? .import : .openInPlace)

        let fileKeeper = FileKeeper.shared
        fileKeeper.addFile(url: url, fileType: .keyFile, mode: addingMode) { [weak self] result in
            switch result {
            case .success:
                self?.keyFilePickerVC.refresh()
            case .failure(let fileKeeperError):
                self?.keyFilePickerVC.showErrorAlert(fileKeeperError)
            }
        }
    }

    private func returnFileReference(for url: URL) {
        guard !FileType.isDatabaseFile(url: url) else {
            showDatabaseAsKeyFileWarning()
            return
        }

        let location = FileKeeper.shared.getLocation(for: url)
        keyFilePickerVC.setBusyIndicatorVisible(true)
        URLReference.create(for: url, location: location) { [weak self] result in
            guard let self = self else { return }
            self.keyFilePickerVC.setBusyIndicatorVisible(false)
            switch result {
            case .success(let fileRef):
                self.delegate?.didPickKeyFile(fileRef, in: self)
                self.dismiss(animated: true)
            case .failure(let fileAccessError):
                let message = String.localizedStringWithFormat(
                    LString.Error.failedToOpenFileReasonTemplate,
                    fileAccessError.localizedDescription)
                Diag.error(message)
                self.keyFilePickerVC.showErrorAlert(message)
            }
        }
    }

    private func showDatabaseAsKeyFileWarning() {
        let warningAlert = UIAlertController.make(
            title: LString.titleWarning,
            message: LString.dontUseDatabaseAsKeyFile,
            dismissButtonTitle: LString.actionOK)
        keyFilePickerVC.present(warningAlert, animated: true)
    }
}

extension KeyFilePickerCoordinator: FileInfoCoordinatorDelegate {
    func didEliminateFile(_ fileRef: URLReference, in coordinator: FileInfoCoordinator) {
        keyFilePickerVC.refresh()
        delegate?.didEliminateKeyFile(fileRef, in: self)
    }
}
