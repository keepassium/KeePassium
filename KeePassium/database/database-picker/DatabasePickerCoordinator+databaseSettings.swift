//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    func showDatabaseSettings(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor?,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let databaseSettingsCoordinator = DatabaseSettingsCoordinator(
            fileRef: fileRef,
            router: modalRouter
        )
        databaseSettingsCoordinator.delegate = self
        databaseSettingsCoordinator.start()

        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(databaseSettingsCoordinator, onDismiss: nil)
    }
}

extension DatabasePickerCoordinator: DatabaseSettingsCoordinatorDelegate {
    func didChangeDatabaseSettings(in coordinator: DatabaseSettingsCoordinator) {
        refresh()
    }
}
