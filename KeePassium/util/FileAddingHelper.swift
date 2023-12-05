//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class FileAddingHelper {

    public static func ensureFileIsDatabase(
        _ url: URL,
        parent: UIViewController,
        handler: @escaping (URL) -> Void
    ) {
        if FileType.isDatabaseFile(url: url) {
            handler(url)
            return
        }

        DispatchQueue.main.async {
            let fileName = url.lastPathComponent
            let confirmationAlert = UIAlertController.make(
                title: LString.titleWarning,
                message: String.localizedStringWithFormat(
                    LString.warningNonDatabaseExtension,
                    fileName),
                dismissButtonTitle: LString.actionCancel)
            let continueAction = UIAlertAction(
                title: LString.actionContinue,
                style: .default,
                handler: { _ in
                    handler(url)
                }
            )
            confirmationAlert.addAction(continueAction)
            parent.present(confirmationAlert, animated: true, completion: nil)
        }
    }
}
