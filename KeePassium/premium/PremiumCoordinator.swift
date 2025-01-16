//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit
import UIKit

class PremiumCoordinator: NSObject, Coordinator {
    public static let desiredModalPresentationStyle = UIModalPresentationStyle.pageSheet

    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    private let router: NavigationRouter

    private let premiumManager: PremiumManager
    private let planPicker: PricingPlanPickerVC

    private var availablePricingPlans = [PricingPlan]()
    private var isProductsRefreshed: Bool = false
    private var hadSubscriptionBeforePurchase = false

    init(router: NavigationRouter) {
        self.router = router
        self.premiumManager = PremiumManager.shared

        planPicker = PricingPlanPickerVC.create()
        super.init()

        planPicker.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        self.start(tryRestoringPurchasesFirst: false)
    }

    func start(tryRestoringPurchasesFirst: Bool) {
        premiumManager.delegate = self
        router.push(planPicker, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })

        planPicker.isPurchaseEnabled = false

        if tryRestoringPurchasesFirst {
            restorePurchases()
        } else {
            refreshAvailableProducts()
        }
    }

    public func stop(completion: (() -> Void)?) {
        premiumManager.delegate = nil
        router.pop(viewController: planPicker, animated: true, completion: completion)
    }

    fileprivate func restorePurchases() {
        premiumManager.restorePurchases()
    }

    fileprivate func refreshAvailableProducts() {
        premiumManager.requestAvailableProducts(ofKind: .premium) { [weak self] products, error in
            guard let self = self else { return }

            self.planPicker.isPurchaseEnabled = true

            guard error == nil else {
                self.planPicker.showMessage(error!.localizedDescription)
                return
            }

            guard let products = products, products.count > 0 else {
                let message = LString.errorNoPurchasesAvailable
                self.planPicker.showMessage(message)
                return
            }
            var availablePlans = products.compactMap { product in
                return PricingPlanFactory.make(for: product)
            }
            availablePlans.append(FreePricingPlan()) 
            self.isProductsRefreshed = true
            self.availablePricingPlans = availablePlans
            self.planPicker.refresh(animated: true)
            self.planPicker.scrollToDefaultPlan(animated: false)
        }
    }

    func setPurchasing(_ isPurchasing: Bool) {
        planPicker.setPurchasing(isPurchasing)
    }
}

extension PremiumCoordinator: PricingPlanPickerDelegate {
    func getAvailablePlans() -> [PricingPlan] {
        return availablePricingPlans
    }

    func didPressBuy(product: SKProduct, in viewController: PricingPlanPickerVC) {
        setPurchasing(true)
        premiumManager.purchase(product)
    }

    func didPressCancel(in viewController: PricingPlanPickerVC) {
        stop(completion: nil)
    }

    func didPressRestorePurchases(in viewController: PricingPlanPickerVC) {
        setPurchasing(true)
        restorePurchases()
    }

    func didPressHelpLink(url: URL, at popoverAnchor: PopoverAnchor, in viewController: PricingPlanPickerVC) {
        assert(childCoordinators.isEmpty)
        URLOpener(viewController).open(url: url)
    }
}

extension PremiumCoordinator: PremiumManagerDelegate {
    func purchaseStarted(in premiumManager: PremiumManager) {
        planPicker.showMessage(LString.statusPurchasing)
        setPurchasing(true)

        let purchaseHistory = premiumManager.getPurchaseHistory()
        if let latestPremiumProduct = purchaseHistory.latestPremiumProduct,
           latestPremiumProduct.isSubscription,
           let subscriptionExpiryDate = purchaseHistory.latestPremiumExpiryDate
        {
            let isActiveSubscription = subscriptionExpiryDate.timeIntervalSinceNow > 0
            hadSubscriptionBeforePurchase = isActiveSubscription
        } else {
            hadSubscriptionBeforePurchase = false
        }

        Watchdog.shared.ignoreMinimizationOnce()
    }

    func purchaseSucceeded(
        _ product: InAppProduct,
        skProduct: SKProduct?,
        in premiumManager: PremiumManager
    ) {
        setPurchasing(false)

        Watchdog.shared.ignoreMinimizationOnce()

        if hadSubscriptionBeforePurchase && !product.isSubscription {
            showOngoingSubscriptionReminderAndDismiss()
        } else {
            stop(completion: {
                StoreReviewSuggester.maybeShowAppReview(
                    appVersion: AppInfo.version,
                    occasion: .didPurchasePremium
                )
            })
        }
    }

    func purchaseDeferred(in premiumManager: PremiumManager) {
        setPurchasing(false)
        planPicker.showMessage(LString.statusDeferredPurchase)
    }

    func purchaseFailed(with error: Error, in premiumManager: PremiumManager) {
        planPicker.showErrorAlert(error)
        setPurchasing(false)
    }

    func purchaseCancelledByUser(in premiumManager: PremiumManager) {
        setPurchasing(false)
    }

    func purchaseRestoringFinished(in premiumManager: PremiumManager) {
        setPurchasing(false)
        switch premiumManager.status {
        case .subscribed,
             .fallback:
            showRestoreConfirmation()
        default:
            if !isProductsRefreshed {
                refreshAvailableProducts()
            }
            planPicker.showNotification(LString.errorNoPreviousPurchaseToRestore)
        }
    }

    private func showOngoingSubscriptionReminderAndDismiss() {
        let ongoingSubscriptionAlert = UIAlertController(
            title: LString.titlePurchaseSuccess,
            message: LString.messageCancelOldSubscriptions,
            preferredStyle: .alert
        )
        ongoingSubscriptionAlert.addAction(
            title: LString.actionManageSubscriptions,
            style: .default,
            handler: { _ in
                AppStoreHelper.openSubscriptionManagement()
            }
        )
        ongoingSubscriptionAlert.addAction(
            title: LString.actionDismiss,
            style: .cancel,
            handler: { [weak self] _ in
                self?.stop(completion: nil)
            }
        )
        planPicker.present(ongoingSubscriptionAlert, animated: true, completion: nil)
    }

    private func showRestoreConfirmation() {
        let successAlert = UIAlertController(
            title: LString.titlePurchaseRestored,
            message: LString.purchaseRestored,
            preferredStyle: .alert)
        let okAction = UIAlertAction(title: LString.actionOK, style: .default) { [weak self] _ in
            self?.stop(completion: nil)
        }
        successAlert.addAction(okAction)
        planPicker.present(successAlert, animated: true, completion: nil)
    }
}

extension PremiumCoordinator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didPressCancel(in: planPicker)
    }
}
