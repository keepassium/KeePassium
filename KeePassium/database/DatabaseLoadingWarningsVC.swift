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
        _ warnings: DatabaseLoadingWarnings,
        in viewController: UIViewController,
        onLockDatabase: @escaping (() -> Void)
    ) {
        let alert = UIAlertController(
            title: LString.titleDatabaseLoadingWarning,
            message: warnings.getFormattedMessage(),
            preferredStyle: .alert
        )
        let ignoreAndContinueAction = UIAlertAction(
            title: LString.actionIgnoreAndContinue,
            style: .default,
            handler: nil
        )
        let closeDatabaseAction = UIAlertAction(
            title: LString.actionCloseDatabase,
            style: .cancel,
            handler: { _ in
                onLockDatabase()
            }
        )
        
        if let helpURL = warnings.getHelpURL() {
            alert.addAction(
                title: LString.actionLearnMore,
                style: .default,
                handler: { [weak viewController] _ in
                    guard let presentingVC = viewController else {
                        assertionFailure()
                        return
                    }
                    URLOpener(presentingVC).open(url: helpURL)
                }
            )
            alert.addAction(ignoreAndContinueAction)
        } else {
            alert.addAction(ignoreAndContinueAction)
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
        }
        alert.addAction(closeDatabaseAction)
        viewController.present(alert, animated: true, completion: nil)
    }
}

extension DatabaseLoadingWarnings {
    public func getFormattedMessage() -> String {
        let sortedIssues = issues.sorted { $0.priority > $1.priority }
        var messages = sortedIssues.map { getDescription(for: $0) }
        if isGeneratorImportant {
            let footerLine = String.localizedStringWithFormat(
                LString.databaseLastEditedByTemplate,
                databaseGenerator ?? "")
            messages.append(footerLine)
        }
        return messages.joined(separator: "\n\n")
    }
}

extension LString {
    public static let databaseLastEditedByTemplate = NSLocalizedString(
        "[Database/Opened/Warning/lastEdited] Database was last edited by: %@",
        value: "Database was last edited by: %@",
        comment: "Status message: name of the app that was last to write/create the database file. [lastUsedAppName: String]")
    public static let titleDatabaseLoadingWarning = NSLocalizedString(
        "[Database/Opened/Warning/title] Your database is ready, but there was an issue.",
        value: "Your database is ready, but there was an issue.",
        comment: "Title of a warning message, shown after opening a problematic database")
    public static let actionIgnoreAndContinue = NSLocalizedString(
        "[Database/Opened/Warning/action] Ignore and Continue",
        value: "Ignore and Continue",
        comment: "Action: ignore warnings and proceed to work with the database")
    public static let actionCloseDatabase = NSLocalizedString(
        "[Database/Opened/Warning/action] Close Database",
        value: "Close Database",
        comment: "Action: lock database")
}
