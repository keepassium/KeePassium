//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class AutoFillSettingsCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter
    private let autoFillSettingsVC: SettingsAutoFillVC

    init(router: NavigationRouter) {
        self.router = router
        autoFillSettingsVC = SettingsAutoFillVC.instantiateFromStoryboard()
        autoFillSettingsVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(autoFillSettingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
    }

    @objc
    private func premiumStatusDidChange() {
        refresh()
    }

    func refresh() {
        if let topVC = router.navigationController.topViewController,
           let topRefreshable = topVC as? Refreshable
        {
            topRefreshable.refresh()
        }
    }
}

extension AutoFillSettingsCoordinator {
    private func maybeSetQuickAutoFill(_ enabled: Bool, in viewController: SettingsAutoFillVC) {
        if enabled {
            performPremiumActionOrOfferUpgrade(
                for: .canUseQuickTypeAutoFill,
                in: viewController,
                actionHandler: {
                    Settings.current.isQuickTypeEnabled = true
                }
            )
        } else {
            Settings.current.isQuickTypeEnabled = false
            viewController.showQuickAutoFillCleared()
            QuickTypeAutoFillStorage.removeAll()
        }
    }
}

extension AutoFillSettingsCoordinator: SettingsAutoFillViewControllerDelegate {
    func didToggleQuickAutoFill(newValue: Bool, in viewController: SettingsAutoFillVC) {
        maybeSetQuickAutoFill(newValue, in: viewController)
    }

    func didToggleCopyTOTP(newValue: Bool, in viewController: SettingsAutoFillVC) {
        Settings.current.isCopyTOTPOnAutoFill = newValue
    }
}
