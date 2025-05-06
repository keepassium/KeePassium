//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

extension Coordinator {
    func requestFormatUpgradeIfNecessary(
        in viewController: UIViewController,
        for database: Database,
        and feature: DatabaseFeature2,
        didApprove: @escaping () -> Void
    ) {
        guard let db2 = database as? Database2 else {
            assertionFailure("Requested format upgrade for KDB format, this should be blocked in UI.")
            return
        }
        guard let newFormat = db2.formatUpgradeRequired(for: feature) else {
            didApprove()
            return
        }

        guard db2.formatVersion.hasMajorDifferences(with: newFormat) else {
            Diag.debug("Minor format version upgrade required, approving silently")
            db2.upgradeFormatVersion(to: newFormat)
            didApprove()
            return
        }

        let message = [
                String.localizedStringWithFormat(
                    LString.databaseFormatVersionUpgradeMessageTemplate,
                    db2.formatVersion.description,
                    newFormat.description),
                LString.titleDatabaseFormatConversionAllDataPreserved
            ].joined(separator: "\n\n") 
        let confirmationAlert = UIAlertController.make(
            title: LString.titleDatabaseFormatVersionUpgrade,
            message: message,
            dismissButtonTitle: LString.actionCancel
        )
        confirmationAlert.addAction(title: LString.actionContinue, style: .default, preferred: true) { _ in
            Diag.debug("DB format upgrade approved by user")
            db2.upgradeFormatVersion(to: newFormat)
            didApprove()
        }
        viewController.present(confirmationAlert, animated: true)
    }
}
