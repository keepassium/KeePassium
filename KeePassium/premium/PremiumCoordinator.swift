//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib
import StoreKit

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
        router.push(planPicker, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })

        (UIApplication.shared as! KPApplication).showNetworkActivityIndicator()
        
        planPicker.isPurchaseEnabled = false
        
        if tryRestoringPurchasesFirst {
            restorePurchases()
        } else {
            refreshAvailableProducts()
        }
    }
    
    fileprivate func restorePurchases() {
        premiumManager.restorePurchases()
    }
    
    fileprivate func refreshAvailableProducts() {
        premiumManager.requestAvailableProducts() {
            [weak self] (products, error) in
            (UIApplication.shared as! KPApplication).hideNetworkActivityIndicator()
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
            var availablePlans = products.compactMap { (product) in
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
        premiumManager.delegate = nil
        router.pop(viewController: planPicker, animated: true)
    }
    
    func didPressRestorePurchases(in viewController: PricingPlanPickerVC) {
        setPurchasing(true)
        restorePurchases()
    }
    
    func didPressHelpButton(
        for helpReference: PricingPlanCondition.HelpReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: PricingPlanPickerVC)
    {
        assert(childCoordinators.isEmpty)
        guard helpReference != .none else {
            assertionFailure()
            return
        }
        
        let helpRouter: NavigationRouter
        if router.isHorizontallyCompact {
            helpRouter = router
        } else {
            helpRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        }
        
        let helpViewerCoordinator = HelpViewerCoordinator(router: helpRouter)
        helpViewerCoordinator.dismissHandler = { [weak self] (coordinator) in
            self?.removeChildCoordinator(coordinator)
        }
        helpViewerCoordinator.article = HelpArticle.load(helpReference.articleKey)
        addChildCoordinator(helpViewerCoordinator)
        helpViewerCoordinator.start()
        if helpRouter !== router {
            router.present(helpRouter, animated: true, completion: nil)
        }
    }
}

extension PremiumCoordinator: PremiumManagerDelegate {
    func purchaseStarted(in premiumManager: PremiumManager) {
        planPicker.showMessage(LString.statusPurchasing)
        setPurchasing(true)
        hadSubscriptionBeforePurchase = premiumManager.getPremiumProduct()?.isSubscription ?? false
    }
    
    func purchaseSucceeded(_ product: InAppProduct, in premiumManager: PremiumManager) {
        setPurchasing(false)
        if hadSubscriptionBeforePurchase && !product.isSubscription {
            let existingSubscriptionAlert = UIAlertController.make(
                title: LString.titlePurchaseSuccess,
                message: LString.messageCancelOldSubscriptions,
                dismissButtonTitle: LString.actionDismiss)
            let manageSubscriptionAction = UIAlertAction(
                title: LString.actionManageSubscriptions,
                style: .default)
            {
                (action) in
                AppStoreHelper.openSubscriptionManagement()
            }
            existingSubscriptionAlert.addAction(manageSubscriptionAction)
            planPicker.present(existingSubscriptionAlert, animated: true, completion: nil)
        } else {
            StoreReviewSuggester.maybeShowAppReview(
                appVersion: AppInfo.version,
                occasion: .didPurchasePremium
            )
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
        case .subscribed:
            showRestoreConfirmation()
        default:
            if !isProductsRefreshed {
                refreshAvailableProducts()
            }
            planPicker.showNotification(LString.errorNoPreviousPurchaseToRestore)
        }
    }
    
    private func showRestoreConfirmation() {
        let successAlert = UIAlertController(
            title: LString.titlePurchaseRestored,
            message: LString.purchaseRestored,
            preferredStyle: .alert)
        let okAction = UIAlertAction(title: LString.actionOK, style: .default) {
            [weak self] _ in
            guard let self = self else { return }
            self.router.pop(viewController: self.planPicker, animated: true)
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
