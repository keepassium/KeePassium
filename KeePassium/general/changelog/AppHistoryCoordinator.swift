//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppHistoryCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter
    private let viewer: AppHistoryViewerVC

    init(router: NavigationRouter) {
        self.router = router
        viewer = AppHistoryViewerVC.instantiateFromStoryboard()
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
         AppHistory.load(completion: { [weak self] appHistory in
            self?.viewer.appHistory = appHistory
        })
        router.push(viewer, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
}
