//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class NavigationRouter: NSObject {
    public typealias PopHandler = ((UIViewController) -> ())
    
    public private(set) var navigationController: UINavigationController
    private var popHandlers = [ObjectIdentifier: PopHandler]()
    
    init(_ navigationController: UINavigationController) {
        self.navigationController = navigationController
        super.init()
    }
    
    public func push(_ viewController: UIViewController, animated: Bool, onPop popHandler: PopHandler?) {
        if let popHandler = popHandler {
            let id = ObjectIdentifier(viewController)
            popHandlers[id] = popHandler
        }
        navigationController.pushViewController(viewController, animated: animated)
    }
    
    public func pop(animated: Bool) {
        let isLastVC = (navigationController.viewControllers.count == 1)
        if isLastVC {
            navigationController.dismiss(animated: animated, completion: nil)
            triggerAndRemovePopHandler(for: navigationController.topViewController!) 
        } else {
            navigationController.popViewController(animated: animated)
        }
    }
    
    public func popToRoot(animated: Bool) {
        navigationController.popToRootViewController(animated: animated)
    }
    
    fileprivate func triggerAndRemovePopHandler(for viewController: UIViewController) {
        let id = ObjectIdentifier(viewController)
        if let popHandler = popHandlers[id] {
            popHandler(viewController)
            popHandlers.removeValue(forKey: id)
        }
    }
}

extension NavigationRouter: UINavigationControllerDelegate {
    public func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool)
    {
        guard let fromVC = navigationController.transitionCoordinator?.viewController(forKey: .from),
            !navigationController.viewControllers.contains(fromVC)
            else { return }
        triggerAndRemovePopHandler(for: fromVC)
    }
}
