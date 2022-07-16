//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class NetworkAccessSettingsCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    
    private let router: NavigationRouter
    private let viewController: NetworkAccessSettingsVC
    
    init(router: NavigationRouter) {
        self.router = router
        viewController = NetworkAccessSettingsVC.make()
        viewController.isAccessAllowed = Settings.current.isNetworkAccessAllowed
        viewController.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        router.push(viewController, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
}

extension NetworkAccessSettingsCoordinator: NetworkAccessSettingsDelegate {
    func didPressOpenURL(_ url: URL, in viewController: NetworkAccessSettingsVC) {
        URLOpener(viewController).open(url: url)
    }
    
    func didChangeNetworkPermission(isAllowed: Bool, in viewController: NetworkAccessSettingsVC) {
        Settings.current.isNetworkAccessAllowed = isAllowed
    }
}
