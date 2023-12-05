//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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
                handler: { [weak viewController] _ in
                    guard let presentingVC = viewController else { return }
                    let popoverAnchor = PopoverAnchor(
                        sourceView: presentingVC.view,
                        sourceRect: presentingVC.view.frame)
                    SupportEmailComposer.show(
                        subject: .problem,
                        parent: presentingVC,
                        popoverAnchor: popoverAnchor,
                        completion: { _ in
                            alert.dismiss(animated: false, completion: nil)
                        }
                    )
                }
            )
        }
        alert.addAction(closeDatabaseAction)
        viewController.present(alert, animated: true, completion: nil)

        Diag.warning("DB loading warnings shown [issues: \(warnings.getRedactedDescription())]")
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
