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

class PremiumCoordinator {
    
    weak var delegate: PremiumCoordinatorDelegate?
    
    let presentingViewController: UIViewController
    
    private let premiumManager: PremiumManager
    private let navigationController: UINavigationController
    private let premiumVC: PremiumVC
    private var isProductsRefreshed: Bool = false
    
    init(presentingViewController: UIViewController) {
        self.premiumManager = PremiumManager.shared
        self.presentingViewController = presentingViewController
        premiumVC = PremiumVC.create()
        navigationController = UINavigationController(rootViewController: premiumVC)
        navigationController.modalPresentationStyle = .formSheet
        premiumVC.delegate = self
    }
    
    func start(tryRestoringPurchasesFirst: Bool=false) {
        premiumManager.delegate = self
        self.presentingViewController.present(navigationController, animated: true, completion: nil)
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        premiumVC.allowRestorePurchases = false
        
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
        premiumManager.requestAvailableProducts(completionHandler: {
            [weak self] (products, error) in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            guard let self = self else { return }
            
            self.premiumVC.allowRestorePurchases = true
            
            if let error = error {
                self.premiumVC.showMessage(error.localizedDescription)
                return
            }
            guard let products = products, products.count > 0 else {
                let message = NSLocalizedString(
                    "[Premium/Upgrade] Hmm, there are no upgrades available. This should not happen, please contact support.",
                    value: "Hmm, there are no upgrades available. This should not happen, please contact support.",
                    comment: "Error message: AppStore returned no available in-app purchase options")
                self.premiumVC.showMessage(message)
                return
            }
            self.isProductsRefreshed = true
            self.premiumVC.setAvailableProducts(products)
        })
    }
    
    func finish(animated: Bool, completion: (() -> Void)?) {
        navigationController.dismiss(animated: animated) { [weak self] in
            guard let self = self else { return }
            self.delegate?.didFinish(self)
        }
    }
}

extension PremiumCoordinator: PremiumDelegate {
    func didPressBuy(product: SKProduct, in premiumController: PremiumVC) {
        premiumManager.purchase(product)
    }
    
    func didPressCancel(in premiumController: PremiumVC) {
        premiumManager.delegate = nil
        finish(animated: true, completion: nil)
    }
    
    func didPressRestorePurchases(in premiumController: PremiumVC) {
        restorePurchases()
    }
}

extension PremiumCoordinator: PremiumManagerDelegate {
    func purchaseStarted(in premiumManager: PremiumManager) {
        premiumVC.showMessage(NSLocalizedString(
            "[Premium/Upgrade/Progress] Purchasing...",
            value: "Purchasing...",
            comment: "Status: in-app purchase started")
        )
        premiumVC.setPurchasing(true)
    }
    
    func purchaseSucceeded(_ product: InAppProduct, in premiumManager: PremiumManager) {
        premiumVC.setPurchasing(false)
        let thankYouAlert = UIAlertController(
            title: NSLocalizedString(
                "[Premium/Upgrade/Success/title] Thank You",
                value: "Thank You",
                comment: "Title of the message shown after a successful in-app purchase"),
            message: NSLocalizedString(
                "[Premium/Upgrade/Success/text] Upgrade successful, enjoy the app!",
                value: "Upgrade successful, enjoy the app!",
                comment: "Text of the message shown after successful in-app purchase"),
            preferredStyle: .alert)
        let okAction = UIAlertAction(title: LString.actionOK, style: .default) { [weak self] _ in
            self?.finish(animated: true, completion: nil)
        }
        thankYouAlert.addAction(okAction)
        premiumVC.present(thankYouAlert, animated: true, completion: nil)
    }
    
    func purchaseDeferred(in premiumManager: PremiumManager) {
        premiumVC.setPurchasing(false)
        premiumVC.showMessage(NSLocalizedString(
            "[Premium/Upgrade/Deferred/text] Thank you! You can use KeePassium while purchase is awaiting approval from a parent",
            value: "Thank you! You can use KeePassium while purchase is awaiting approval from a parent",
            comment: "Message shown when in-app purchase is deferred until parental approval."))
    }
    
    func purchaseFailed(with error: Error, in premiumManager: PremiumManager) {
        let errorAlert = UIAlertController.make(
            title: LString.titleError,
            message: error.localizedDescription,
            cancelButtonTitle: LString.actionDismiss)
        premiumVC.present(errorAlert, animated: true, completion: nil)
        premiumVC.setPurchasing(false)
    }
    
    func purchaseCancelledByUser(in premiumManager: PremiumManager) {
        premiumVC.setPurchasing(false)
    }
    
    func purchaseRestoringFinished(in premiumManager: PremiumManager) {
        premiumVC.setPurchasing(false)
        switch premiumManager.status {
        case .subscribed:
            let successAlert = UIAlertController(
                title: NSLocalizedString(
                    "[Premium/Upgrade/Restored/title] Purchase Restored",
                    value: "Purchase Restored",
                    comment: "Title of the message shown after in-app purchase was successfully restored"),
                message: NSLocalizedString(
                    "[Premium/Upgrade/Restored/text] Upgrade successful, enjoy the app!",
                    value: "Upgrade successful, enjoy the app!",
                    comment: "Text of the message shown after in-app purchase was successfully restored"),
                preferredStyle: .alert)
            let okAction = UIAlertAction(title: LString.actionOK, style: .default) {
                [weak self] _ in
                self?.finish(animated: true, completion: nil)
            }
            successAlert.addAction(okAction)
            premiumVC.present(successAlert, animated: true, completion: nil)
        default:
            if !isProductsRefreshed {
                refreshAvailableProducts()
            }
            let notRestoredAlert = UIAlertController.make(
                title: NSLocalizedString(
                    "[Premium/Upgrade/RestoreFailed/title] Sorry",
                    value: "Sorry",
                    comment: "Title of an error message: there were no in-app purchases that can be restored"),
                message: NSLocalizedString(
                    "[Premium/Upgrade/RestoreFailed/text] No previous purchase could be restored.",
                    value: "No previous purchase could be restored.",
                    comment: "Text of an error message: there were no in-app purchases that can be restored"),
                cancelButtonTitle: LString.actionOK)
            premiumVC.present(notRestoredAlert, animated: true, completion: nil)
        }
    }
    
    
}
