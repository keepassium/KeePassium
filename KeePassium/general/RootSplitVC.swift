//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class RootSplitVC: UISplitViewController, UISplitViewControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.preferredDisplayMode = .allVisible
    }
    
    public func setDetailRouter(_ router: NavigationRouter) {
        if isCollapsed {
            showDetailViewController(router.navigationController, sender: self)
        } else {
            var _viewControllers = viewControllers
            _viewControllers = _viewControllers.dropLast()
            _viewControllers.append(router.navigationController)
            viewControllers = _viewControllers
        }
    }
}

