//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class RootSplitVC: UISplitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.preferredDisplayMode = .oneBesideSecondary
        if ProcessInfo.isRunningOnMac {
            preferredPrimaryColumnWidthFraction = Settings.current.primaryPaneWidthFraction
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if ProcessInfo.isRunningOnMac {
            Settings.current.primaryPaneWidthFraction = primaryColumnWidth / view.bounds.width
        }
    }

    public func setDetailRouter(_ router: NavigationRouter) {
        assert(viewControllers.count > 0) 

        if viewControllers.count == 1 {
            let vc = viewControllers.first! 
            guard let primaryNavVC = vc as? UINavigationController else {
                Diag.warning("Expected UINavigationController, got \(vc.debugDescription) instead")
                assertionFailure()
                return
            }
            primaryNavVC.pushViewController(router.navigationController, animated: true)
        } else {
            var _viewControllers = viewControllers
            _viewControllers = _viewControllers.dropLast()
            _viewControllers.append(router.navigationController)
            viewControllers = _viewControllers
        }
    }

    public func ensurePrimaryVisible() {
        guard isCollapsed else { return }
        guard let navVC = viewControllers.first! as? UINavigationController else {
            assertionFailure()
            return
        }
        navVC.popToRootViewController(animated: false)
    }
}
