//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppHistoryCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    
    typealias DismissHandler = (AppHistoryCoordinator) -> Void
    var dismissHandler: DismissHandler?
    
    private let router: NavigationRouter
    private let viewer: AppHistoryViewerVC
    
    init(router: NavigationRouter) {
        self.router = router
        viewer = AppHistoryViewerVC.instantiateFromStoryboard()
    }
    
    func start() {
        let appHistory = AppHistory.load(from: "ChangeLog")
        viewer.appHistory = appHistory
        router.push(viewer, animated: true, onPop: { [self] (viewController) in 
            self.dismissHandler?(self)
        })
    }
}
