//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UIKit

protocol RemoteConnectionSetupAlertPresenting: BaseCoordinator {
    func showErrorAlert(_ error: Error, title: String?)
    func showOverwriteConfirmation(
        fileName: String,
        onConfirm overwriteHandler: @escaping (UIAlertAction) -> Void
    )
}

extension RemoteConnectionSetupAlertPresenting {
    func showErrorAlert(_ error: Error, title: String? = nil) {
        _presenterForModals.showErrorAlert(error, title: title)
    }

    func showOverwriteConfirmation(
        fileName: String,
        onConfirm overwriteHandler: @escaping (UIAlertAction) -> Void
    ) {
        let overwriteAlert = UIAlertController(
            title: LString.fileAlreadyExists,
            message: fileName,
            preferredStyle: .alert)
        overwriteAlert.addAction(title: LString.actionOverwrite, style: .destructive, handler: overwriteHandler)
        overwriteAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        _presenterForModals.present(overwriteAlert, animated: true)
    }
}
