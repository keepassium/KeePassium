//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol KeyFilePickerCoordinatorDelegate: AnyObject {
    func didPickKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference?)
    func didRemoveOrDeleteKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference)
}

class KeyFilePickerCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()
    
    weak var delegate: KeyFilePickerCoordinatorDelegate?
    var dismissHandler: CoordinatorDismissHandler?
    
    private var router: NavigationRouter
    private var keyFilePickerVC: KeyFilePickerVC
    private var addingMode: FileKeeper.OpenMode = .openInPlace
    
    init(router: NavigationRouter, addingMode: FileKeeper.OpenMode) {
        self.router = router
        keyFilePickerVC = KeyFilePickerVC.create()
        super.init()
        
        self.addingMode = addingMode
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
        
        router.push(keyFilePickerVC, animated: true, onPop: {
            [weak self] viewController in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    @objc
    private func didPressDismissButton() {
        router.dismiss(animated: true)
    }
}

extension KeyFilePickerCoordinator: KeyFilePickerDelegate {
    func didPressAddKeyFile(in keyFilePicker: KeyFilePickerVC, at popoverAnchor: PopoverAnchor) {
        let picker = UIDocumentPickerViewController(documentTypes: FileType.keyFileUTIs, in: .open)
        picker.delegate = self
        picker.modalPresentationStyle = .pageSheet
        popoverAnchor.apply(to: picker.popoverPresentationController)
        router.present(picker, animated: true, completion: nil)
    }
    
    func didSelectFile(in keyFilePicker: KeyFilePickerVC, selectedFile: URLReference?) {
        delegate?.didPickKeyFile(in: self, keyFile: selectedFile)
        router.dismiss(animated: true)
    }
    
    func didPressFileInfo(
        in keyFilePicker: KeyFilePickerVC,
        for keyFile: URLReference,
        at popoverAnchor: PopoverAnchor)
    {
        let fileInfoVC = FileInfoVC.make(urlRef: keyFile, fileType: .keyFile, at: popoverAnchor)
        fileInfoVC.canExport = false
        fileInfoVC.didDeleteCallback = { [weak self, weak fileInfoVC] in
            guard let self = self else { return }
            fileInfoVC?.dismiss(animated: true, completion: nil)
            self.keyFilePickerVC.refresh()
            self.delegate?.didRemoveOrDeleteKeyFile(in: self, keyFile: keyFile)
        }
        router.present(fileInfoVC, animated: true, completion: nil)
    }
    
    func didPressRemoveOrDeleteFile(
        in keyFilePicker: KeyFilePickerVC,
        keyFile: URLReference,
        at popoverAnchor: PopoverAnchor)
    {
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
                    self.delegate?.didRemoveOrDeleteKeyFile(in: self, keyFile: keyFile)
                }
            }
        )
    }
}

extension KeyFilePickerCoordinator: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        addKeyFile(url: url)
    }
    
    private func addKeyFile(url: URL) {
        if FileType.isDatabaseFile(url: url) {
            let warningAlert = UIAlertController.make(
                title: LString.titleWarning,
                message: LString.dontUseDatabaseAsKeyFile,
                dismissButtonTitle: LString.actionOK)
            keyFilePickerVC.present(warningAlert, animated: true)
            return
        }
        
        let fileKeeper = FileKeeper.shared
        fileKeeper.addFile(
            url: url,
            fileType: .keyFile,
            mode: addingMode,
            success: { [weak self] fileRef in
                self?.keyFilePickerVC.refresh()
            },
            error: { [weak self] fileKeeperError in
                self?.keyFilePickerVC.showErrorAlert(fileKeeperError)
            }
        )
    }
}
