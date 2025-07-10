//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension KeyFilePickerCoordinator {
    public func startAddingKeyFile(mode: AddingMode, presenter: UIViewController) {
        self._addingMode = mode

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: FileType.keyFileUTIs)
        picker.delegate = self
        picker.modalPresentationStyle = .pageSheet
        presenter.present(picker, animated: true, completion: nil)
    }
}

extension KeyFilePickerCoordinator: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        guard let _addingMode else {
            Diag.warning("Adding mode is not defined, cancelling")
            assertionFailure()
            return
        }
        switch _addingMode {
        case .import:
            _addKeyFile(url: url, accessMode: .import, presenter: _filePickerVC)
        case .use:
            returnReference(for: url, presenter: _filePickerVC)
        }
        self._addingMode = nil
    }
}

extension KeyFilePickerCoordinator {
    internal func _addKeyFile(url: URL, accessMode: FileKeeper.OpenMode?, presenter: UIViewController) {
        guard sanityCheck(url, presenter: presenter) else {
            return
        }

        let accessMode = accessMode
                ?? (FileKeeper.shared.canActuallyAccessAppSandbox ? .import : .openInPlace)

        let fileKeeper = FileKeeper.shared
        fileKeeper.addFile(url: url, fileType: .keyFile, mode: accessMode) {
            [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                refresh()
            case .failure(let fileKeeperError):
                presenter.showErrorAlert(fileKeeperError)
            }
        }
    }

    private func returnReference(for url: URL, presenter: UIViewController) {
        guard sanityCheck(url, presenter: presenter) else {
            return
        }

        let location = FileKeeper.shared.getLocation(for: url)
        _filePickerVC.indicateState(isBusy: true)
        URLReference.create(for: url, location: location) { [weak self] result in
            guard let self else { return }
            _filePickerVC.indicateState(isBusy: false)
            switch result {
            case .success(let fileRef):
                didSelectFile(fileRef, cause: .app, in: _filePickerVC)
            case .failure(let fileAccessError):
                let message = String.localizedStringWithFormat(
                    LString.Error.failedToOpenFileReasonTemplate,
                    fileAccessError.localizedDescription)
                Diag.error(message)
                presenter.showErrorAlert(message)
            }
        }
    }

    private func sanityCheck(_ url: URL, presenter: UIViewController) -> Bool {
        if FileType.isDatabaseFile(url: url) {
            Diag.warning("Tried to add database as a key file, refusing")
            presenter.showErrorAlert(
                LString.dontUseDatabaseAsKeyFile,
                title: LString.titleWarning)
            return false
        }
        return true
    }
}
