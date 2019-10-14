//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class RootNavigationVC: UINavigationController, UINavigationControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.delegate = self
        DatabaseManager.shared.addObserver(self)
    }
    
    deinit {
        DatabaseManager.shared.removeObserver(self)
    }
      
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool)
    {
        let showBottomToolbar = viewController is ViewGroupVC || viewController is ChooseDatabaseVC
        navigationController.isToolbarHidden = !showBottomToolbar
    }

    
    func dismissDatabaseContentControllers() {
        
        var hasReachedViewGroupVC = false
        var popToVC: UIViewController?
        for vc in viewControllers.reversed() {
            let isViewGroupVC = vc is ViewGroupVC
            if !hasReachedViewGroupVC && isViewGroupVC {
                hasReachedViewGroupVC = true
            }
            if hasReachedViewGroupVC && !isViewGroupVC {
                popToVC = vc
                break
            }
        }

        guard let targetVC = popToVC else { return }
        
        guard let splitVC = splitViewController else { fatalError() }
        if !splitVC.isCollapsed {
            splitVC.showDetailViewController(PlaceholderVC.make(), sender: self)
        }
        
        if let presentedVC = presentedViewController {
            if presentedVC.isBeingDismissed {
                popToViewController(targetVC, animated: true)
            } else {
                dismiss(animated: false, completion: {
                    self.popToViewController(targetVC, animated: true)
                })
            }
        } else {
            popToViewController(targetVC, animated: true)
        }
    }
}

extension RootNavigationVC: DatabaseManagerObserver {
    func databaseManager(willCloseDatabase urlRef: URLReference) {
        dismissDatabaseContentControllers()
    }
}
