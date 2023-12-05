//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol OnboardingCoordinatorDelegate: AnyObject {
    func didPressCreateDatabase(in coordinator: OnboardingCoordinator)
    func didPressAddExistingDatabase(in coordinator: OnboardingCoordinator)
    func didPressConnectToServer(in coordinator: OnboardingCoordinator)
}

final class OnboardingCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()

    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: OnboardingCoordinatorDelegate?

    private let router: NavigationRouter

    private lazy var welcomeVC: WelcomeVC = {
        return WelcomeVC.make(delegate: self)
    }()

    init(router: NavigationRouter) {
        self.router = router
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(welcomeVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    func dismiss(completion: @escaping () -> Void) {
        router.pop(animated: true, completion: completion)
    }
}

extension OnboardingCoordinator: WelcomeDelegate {
    func didPressCreateDatabase(in welcomeVC: WelcomeVC) {
        delegate?.didPressCreateDatabase(in: self)
    }

    func didPressAddExistingDatabase(in welcomeVC: WelcomeVC) {
        delegate?.didPressAddExistingDatabase(in: self)
    }

    func didPressConnectToServer(in welcomeVC: WelcomeVC) {
        delegate?.didPressConnectToServer(in: self)
    }
}
