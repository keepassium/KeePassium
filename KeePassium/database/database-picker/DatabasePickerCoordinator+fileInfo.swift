//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    func showFileInfo(
        _ fileRef: URLReference,
        at popoverAnchor: PopoverAnchor?,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let fileInfoCoordinator = FileInfoCoordinator(
            fileRef: fileRef,
            fileType: .database,
            allowExport: true,
            router: modalRouter)
        fileInfoCoordinator.delegate = self
        fileInfoCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        fileInfoCoordinator.start()

        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(fileInfoCoordinator)
    }
}

extension DatabasePickerCoordinator: FileInfoCoordinatorDelegate {
    func didEliminateFile(_ fileRef: URLReference, in coordinator: FileInfoCoordinator) {
        refresh()
    }
}
