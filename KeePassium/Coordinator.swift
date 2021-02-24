//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

typealias CoordinatorDismissHandler = (Coordinator) -> Void

protocol Coordinator: class {
    var childCoordinators: [Coordinator] { get set }

    var dismissHandler: CoordinatorDismissHandler? { get set }
    
    func addChildCoordinator(_ coordinator: Coordinator)
    func removeChildCoordinator(_ coordinator: Coordinator)
    
    func start()
}

extension Coordinator {
    func addChildCoordinator(_ coordinator: Coordinator) {
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
