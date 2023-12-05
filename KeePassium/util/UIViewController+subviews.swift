//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public extension UIViewController {

    func showChildViewController(_ viewController: UIViewController) {
        assert(viewController.parent == nil, "viewController is already used somewhere")
        let childView = viewController.view!
        self.view.addSubview(childView)

        viewController.view.frame = view.bounds
        viewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        self.addChild(viewController)
        viewController.didMove(toParent: self)
    }

    func hideChildViewController(_ viewController: UIViewController) {
        assert(viewController.parent === self, "viewController is not a child of this VC")
        viewController.willMove(toParent: nil)
        viewController.removeFromParent()
        viewController.view.removeFromSuperview()
    }

    func swapChildViewControllers(
        from currentVC: UIViewController,
        to nextVC: UIViewController,
        duration: TimeInterval = 0.3,
        options: UIView.AnimationOptions = .showHideTransitionViews,
        completion: ((Bool) -> Void)? = nil
    ) {
        assert(nextVC.parent == nil)

        let nextView = nextVC.view!
        let currentView = currentVC.view!

        currentVC.willMove(toParent: nil)
        self.addChild(nextVC)
        self.view.insertSubview(nextView, belowSubview: currentView)

        nextView.frame = view.bounds
        nextView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        UIView.transition(
            from: currentView,
            to: nextView,
            duration: duration,
            options: options,
            completion: { finished in
                currentView.removeFromSuperview()
                currentVC.removeFromParent()
                nextVC.didMove(toParent: self)
                completion?(finished)
            }
        )
    }
}
