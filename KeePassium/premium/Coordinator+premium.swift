//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension Coordinator {

    func startObservingPremiumStatus(_ selector: Selector) {
        NotificationCenter.default.addObserver(
            self,
            selector: selector,
            name: PremiumManager.statusUpdateNotification,
            object: nil)
    }

    func performPremiumActionOrOfferUpgrade(
        for feature: PremiumFeature,
        allowBypass: Bool = false,
        bypassTitle: String = LString.actionContinue,
        in viewController: UIViewController,
        actionHandler: @escaping () -> Void
    ) {
        if PremiumManager.shared.isAvailable(feature: feature) {
            actionHandler()
            return
        }

        if allowBypass {
            offerPremiumUpgrade(
                for: feature,
                bypassAction: actionHandler,
                bypassTitle: bypassTitle,
                in: viewController
            )
        } else {
            offerPremiumUpgrade(
                for: feature,
                bypassAction: nil,
                in: viewController
            )
        }
    }

    func offerPremiumUpgrade(
        for feature: PremiumFeature,
        bypassAction: (() -> Void)? = nil,
        bypassTitle: String = LString.actionContinue,
        in viewController: UIViewController
    ) {
        let upgradeNotice = UIAlertController(
            title: feature.titleName,
            message: feature.upgradeNoticeText,
            preferredStyle: .alert
        )
        upgradeNotice.addAction(title: LString.actionUpgradeToPremium, style: .default) {
            [weak self, weak viewController] _ in 
            guard let self = self,
                  let viewController = viewController
            else {
                return
            }
            self.showPremiumUpgrade(in: viewController)
        }
        if let bypassAction = bypassAction {
            upgradeNotice.addAction(title: bypassTitle, style: .default) { _ in
                bypassAction()
            }
        }
        upgradeNotice.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        viewController.present(upgradeNotice, animated: true, completion: nil)
    }
}

#if MAIN_APP
extension Coordinator {

    func showPremiumUpgrade(in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(
            style: PremiumCoordinator.desiredModalPresentationStyle
        )
        let premiumCoordinator = PremiumCoordinator(router: modalRouter)
        premiumCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        premiumCoordinator.start()
        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(premiumCoordinator)
    }
}
#endif

#if AUTOFILL_EXT
extension Coordinator {
    func showPremiumUpgrade(in viewController: UIViewController) {
        let urlOpener = URLOpener(viewController)
        urlOpener.open(url: AppGroup.upgradeToPremiumURL) { [self] success in
            if !success {
                Diag.warning("Failed to open main app")
                showManualUpgradeMessage(in: viewController)
            }
        }
    }

    func showManualUpgradeMessage(in viewController: UIViewController) {
        let manualUpgradeAlert = UIAlertController.make(
            title: LString.premiumManualUpgradeTitle,
            message: LString.premiumManualUpgradeMessage,
            dismissButtonTitle: LString.actionOK)
        viewController.present(manualUpgradeAlert, animated: true, completion: nil)
    }
}
#endif
