//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
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
        in viewController: UIViewController,
        actionHandler: () -> Void
    ) {
        if PremiumManager.shared.isAvailable(feature: feature) {
            actionHandler()
        } else {
            offerPremiumUpgrade(for: feature, in: viewController)
        }
    }

    func offerPremiumUpgrade(
        for feature: PremiumFeature,
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
        urlOpener.open(url: AppGroup.upgradeToPremiumURL) {
            [self] (success) in
            if !success {
                Diag.warning("Failed to open main app")
                showManualUpgradeMessage(in: viewController)
            }
        }
    }

    func showManualUpgradeMessage(in viewController: UIViewController) {
        let manualUpgradeAlert = UIAlertController.make(
            title: NSLocalizedString(
                "[AutoFill/Premium/Upgrade/Manual/title] Premium Upgrade",
                value: "Premium Upgrade",
                comment: "Title of a message related to upgrading to the premium version"),
            message: NSLocalizedString(
                "[AutoFill/Premium/Upgrade/Manual/text] To upgrade, please manually open KeePassium from your home screen.",
                value: "To upgrade, please manually open KeePassium from your home screen.",
                comment: "Message shown when AutoFill cannot automatically open the main app for upgrading to a premium version."),
            dismissButtonTitle: LString.actionOK)
        viewController.present(manualUpgradeAlert, animated: true, completion: nil)
    }
}
#endif
