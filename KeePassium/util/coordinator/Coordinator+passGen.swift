//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension Coordinator {

    func showPasswordGenerator(
        at popoverAnchor: PopoverAnchor?,
        in viewController: UIViewController
    ) {
        let modalRouter: NavigationRouter
        let isNarrow = viewController.splitViewController?.isCollapsed ?? false
        if ProcessInfo.isRunningOnMac {
            modalRouter = NavigationRouter.createModal(style: .pageSheet, at: popoverAnchor)
        } else if isNarrow {
            modalRouter = NavigationRouter.createModal(style: .pageSheet, at: popoverAnchor)
            let sheet = modalRouter.navigationController.sheetPresentationController
            sheet?.detents = [.medium(), .large()]
            sheet?.prefersGrabberVisible = true
        } else {
            modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        }
        let passGenCoordinator = PasswordGeneratorCoordinator(
            router: modalRouter,
            quickMode: true,
            hasTarget: false
        )
        passGenCoordinator.start()
        addChildCoordinator(passGenCoordinator, onDismiss: nil)
        viewController.present(modalRouter, animated: true, completion: nil)
    }
}
