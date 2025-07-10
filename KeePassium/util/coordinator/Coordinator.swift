//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

typealias CoordinatorDismissHandler = (Coordinator) -> Void

protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }

    var _dismissHandler: CoordinatorDismissHandler? { get set }

    func addChildCoordinator(_ coordinator: Coordinator, onDismiss: CoordinatorDismissHandler?)
    func removeChildCoordinator(_ coordinator: Coordinator)
}

extension Coordinator {
    func _pushInitialViewController(
        _ viewController: UIViewController,
        to router: NavigationRouter,
        replaceTopViewController: Bool = false,
        animated: Bool
    ) {
        router.push(
            viewController,
            animated: animated,
            replaceTopViewController: replaceTopViewController,
            onPop: { [weak self] in
                guard let self else { return }
                removeAllChildCoordinators()
                _dismissHandler?(self)
            }
        )
    }

    func addChildCoordinator(_ coordinator: Coordinator, onDismiss: CoordinatorDismissHandler?) {
        assert(
            coordinator._dismissHandler == nil,
            "Coordinator already has a dismiss handler; avoid setting it directly")
        coordinator._dismissHandler = { [weak self, onDismiss] child in
            onDismiss?(child)
            self?.removeChildCoordinator(child)
        }
        assert(
            !childCoordinators.contains(where: { $0 === coordinator }),
            "Tried to re-add an existing child coordinator")

        childCoordinators.append(coordinator)
    }

    func removeChildCoordinator(_ coordinator: Coordinator) {
        assert(
            childCoordinators.contains(where: { $0 === coordinator }),
            "Tried to remove a child coordinator that was not added")

        childCoordinators.removeAll(where: { $0 === coordinator })
    }

    func removeAllChildCoordinators() {
        childCoordinators.removeAll()
    }
}
