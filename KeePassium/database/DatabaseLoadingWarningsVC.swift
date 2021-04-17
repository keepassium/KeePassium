//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class DatabaseLoadingWarningsVC: UIAlertController {
    
    static func present(
        with warnings: DatabaseLoadingWarnings,
        in viewController: UIViewController,
        onLockDatabase: @escaping (() -> Void)
    ) {
        var message = warnings.messages.joined(separator: "\n\n")
        if warnings.isGeneratorImportant {
            let lastUsedAppName = warnings.databaseGenerator ?? ""
            let footerLine = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database/Opened/Warning/lastEdited] Database was last edited by: %@",
                    value: "Database was last edited by: %@",
                    comment: "Status message: name of the app that was last to write/create the database file. [lastUsedAppName: String]"),
                lastUsedAppName)
            message += "\n\n" + footerLine
        }
        
        let alert = UIAlertController(
            title: NSLocalizedString(
                "[Database/Opened/Warning/title] Your database is ready, but there was an issue.",
                value: "Your database is ready, but there was an issue.",
                comment: "Title of a warning message, shown after opening a problematic database"),
            message: message,
            preferredStyle: .alert)
        alert.addAction(
            title: NSLocalizedString(
                "[Database/Opened/Warning/action] Ignore and Continue",
                value: "Ignore and Continue",
                comment: "Action: ignore warnings and proceed to work with the database"),
            style: .default,
            handler: nil)
        alert.addAction(
            title: LString.actionContactUs,
            style: .default,
            handler: { [weak viewController] (action) in
                guard let presentingVC = viewController else { return }
                let popoverAnchor = PopoverAnchor(
                    sourceView: presentingVC.view,
                    sourceRect: presentingVC.view.frame)
                SupportEmailComposer.show(
                    subject: .problem,
                    parent: presentingVC,
                    popoverAnchor: popoverAnchor,
                    completion: { (isSent) in
                        alert.dismiss(animated: false, completion: nil)
                    }
                )
            }
        )
        alert.addAction(
            title: NSLocalizedString(
                "[Database/Opened/Warning/action] Close Database",
                value: "Close Database",
                comment: "Action: lock database"),
            style: .cancel,
            handler: { _ in
                onLockDatabase()
            }
        )
        viewController.present(alert, animated: true, completion: nil)
    }
}
