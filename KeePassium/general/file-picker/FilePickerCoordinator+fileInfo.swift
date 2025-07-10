//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension FilePickerCoordinator {
    func showFileInfo(
        _ fileRef: URLReference,
        fileType: FileType,
        allowExport: Bool,
        at popoverAnchor: PopoverAnchor?,
        in viewController: UIViewController
    ) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let fileInfoCoordinator = FileInfoCoordinator(
            fileRef: fileRef,
            fileType: fileType,
            allowExport: allowExport,
            router: modalRouter)
        fileInfoCoordinator.delegate = self
        fileInfoCoordinator.start()

        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(fileInfoCoordinator, onDismiss: nil)
    }
}

extension FilePickerCoordinator: FileInfoCoordinatorDelegate {
    func didEliminateFile(_ fileRef: URLReference, in coordinator: FileInfoCoordinator) {
        refresh()
        didEliminateFile(fileRef, in: self)
    }
}
