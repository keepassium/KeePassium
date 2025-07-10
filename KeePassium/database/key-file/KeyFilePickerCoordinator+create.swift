//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension KeyFilePickerCoordinator {
    public func startCreatingKeyFile(presenter: UIViewController) {
        createKeyFile(presenter: presenter)
    }

    private func createKeyFile(presenter: UIViewController) {
        let keyFileData: ByteArray
        do {
            keyFileData = try KeyHelper.generateKeyFileData()
        } catch {
            presenter.showErrorAlert(error)
            return
        }

        let exportHelper = FileExportHelper(data: keyFileData, fileName: LString.defaultKeyFileName)
        exportHelper.handler = { [weak self] finalURL in
            self?._fileExportHelper = nil
            guard let self, let finalURL else { return }
            switch FileKeeper.shared.getLocation(for: finalURL) {
            case .internalDocuments:
                refresh()
            case .external:
                _addKeyFile(url: finalURL, accessMode: .openInPlace, presenter: presenter)
            default:
                Diag.warning("File generated in an unexpected location, aborting")
                assertionFailure()
                return
            }
        }
        exportHelper.saveAs(presenter: presenter)
        self._fileExportHelper = exportHelper
    }
}
