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

protocol PremiumCoordinatorDelegate: class {
    func didFinish(_ premiumCoordinator: PremiumCoordinator)
}

class PremiumCoordinator: NSObject {
    
    weak var delegate: PremiumCoordinatorDelegate?
    
    let presentingViewController: UIViewController
    
    private let premiumManager: PremiumManager
    private let navigationController: UINavigationController
    private let planPicker: PricingPlanPickerVC
    
    private var availablePricingPlans = [PricingPlan]()
    private var isProductsRefreshed: Bool = false
    
    init(presentingViewController: UIViewController) {
        self.premiumManager = PremiumManager.shared
        self.presentingViewController = presentingViewController
        planPicker = PricingPlanPickerVC.create()
        navigationController = UINavigationController(rootViewController: planPicker)
        super.init()

        navigationController.modalPresentationStyle = .pageSheet
        navigationController.presentationController?.delegate = self
        if #available(iOS 13, *) {
            navigationController.isModalInPresentation = true
        }

        planPicker.delegate = self
    }
    
    func start(tryRestoringPurchasesFirst: Bool=false) {
        premiumManager.delegate = self
        self.presentingViewController.present(navigationController, animated: true, completion: nil)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
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
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
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
    
    func finish(animated: Bool, completion: (() -> Void)?) {
        navigationController.dismiss(animated: animated) { [weak self] in
            guard let self = self else { return }
            self.delegate?.didFinish(self)
        }
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
        finish(animated: true, completion: nil)
    }
    
    func didPressRestorePurchases(in viewController: PricingPlanPickerVC) {
        setPurchasing(true)
        restorePurchases()
    }
}

extension PremiumCoordinator: PremiumManagerDelegate {
    func purchaseStarted(in premiumManager: PremiumManager) {
        planPicker.showMessage(LString.statusPurchasing)
        setPurchasing(true)
    }
    
    func purchaseSucceeded(_ product: InAppProduct, in premiumManager: PremiumManager) {
        setPurchasing(false)
        SKStoreReviewController.requestReview()
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
            let successAlert = UIAlertController(
                title: LString.titlePurchaseRestored,
                message: LString.purchaseRestored,
                preferredStyle: .alert)
            let okAction = UIAlertAction(title: LString.actionOK, style: .default) {
                [weak self] _ in
                self?.finish(animated: true, completion: nil)
            }
            successAlert.addAction(okAction)
            planPicker.present(successAlert, animated: true, completion: nil)
        default:
            if !isProductsRefreshed {
                refreshAvailableProducts()
            }
            let notRestoredAlert = UIAlertController.make(
                title: LString.titleRestorePurchaseError,
                message: LString.errorNoPreviousPurchaseToRestore,
                cancelButtonTitle: LString.actionOK)
            planPicker.present(notRestoredAlert, animated: true, completion: nil)
        }
    }
}

extension PremiumCoordinator: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didPressCancel(in: planPicker)
    }
}
