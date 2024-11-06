//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit

final class TipBoxCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter

    private let premiumManager: PremiumManager
    private let tipBoxVC: TipBoxVC
    private var availableProducts = [SKProduct]()

    init(router: NavigationRouter) {
        self.router = router

        self.premiumManager = PremiumManager.shared
        tipBoxVC = TipBoxVC.instantiateFromStoryboard()
        tipBoxVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
        premiumManager.delegate = nil
    }

    func start() {
        setupCloseButton(in: tipBoxVC)
        router.push(tipBoxVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.premiumManager.delegate = nil
            self.dismissHandler?(self)
        })
        premiumManager.delegate = self

        Diag.info(TipBox.getStatus())
        TipBox.registerTipBoxSeen()
    }

    private func setupCloseButton(in viewController: UIViewController) {
        guard router.navigationController.topViewController == nil else {
            return
        }

        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(didPressDismiss))
        viewController.navigationItem.leftBarButtonItem = closeButton
    }

    private func refreshAvailableProducts() {
        tipBoxVC.setStatus(busy: true, text: LString.statusContactingAppStore, animated: true)
        premiumManager.requestAvailableProducts(ofKind: .donation) { [weak self] products, error in
            self?.showReceivedProducts(products, error)
        }
    }

    private func showReceivedProducts(_ products: [SKProduct]?, _ error: Error?) {
        guard error == nil else {
            tipBoxVC.setStatus(busy: false, text: error!.localizedDescription, animated: true)
            return
        }
        guard let products = products, products.count > 0 else {
            tipBoxVC.setStatus(busy: false, text: LString.errorNoPurchasesAvailable, animated: true)
            return
        }
        let sortedProducts = products.sorted {
            $0.price.compare($1.price) == .orderedAscending
        }
        tipBoxVC.setStatus(busy: false, text: nil, animated: true)
        tipBoxVC.setProducts(sortedProducts)
        availableProducts = sortedProducts
    }


    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        router.pop(viewController: tipBoxVC, animated: true)
    }
}

extension TipBoxCoordinator: TipBoxDelegate {
    func didFinishLoading(_ viewController: TipBoxVC) {
        refreshAvailableProducts()
    }

    func didPressPurchase(product: SKProduct, in viewController: TipBoxVC) {
        viewController.setStatus(busy: true, text: LString.statusContactingAppStore, animated: true)
        tipBoxVC.setThankYou(visible: false)
        premiumManager.purchase(product)
    }
}

extension TipBoxCoordinator: PremiumManagerDelegate {
    func purchaseStarted(in premiumManager: PremiumManager) {
        tipBoxVC.setStatus(busy: true, text: LString.statusContactingAppStore, animated: true)

        Watchdog.shared.ignoreMinimizationOnce()
    }

    func purchaseSucceeded(
        _ product: InAppProduct,
        skProduct: SKProduct?,
        in premiumManager: PremiumManager
    ) {
        tipBoxVC.setStatus(busy: false, text: nil, animated: false)
        tipBoxVC.setThankYou(visible: true)

        Watchdog.shared.ignoreMinimizationOnce()

        guard let skProduct = skProduct else {
            Diag.warning("SKProduct is unexpectedly nil")
            assertionFailure()
            return
        }
        TipBox.registerPurchase(amount: skProduct.price, locale: skProduct.priceLocale)
        Diag.info(TipBox.getStatus())
    }

    func purchaseDeferred(in premiumManager: PremiumManager) {
        Diag.info("Purchase deferred")
        tipBoxVC.setStatus(busy: false, text: LString.statusDeferredPurchase, animated: true)
    }

    func purchaseFailed(with error: Error, in premiumManager: PremiumManager) {
        Diag.error("Purchase failed [message: \(error.localizedDescription)]")
        tipBoxVC.showErrorAlert(error)
        tipBoxVC.setStatus(busy: false, text: nil, animated: true)
    }

    func purchaseCancelledByUser(in premiumManager: PremiumManager) {
        tipBoxVC.setStatus(busy: false, text: nil, animated: true)
    }

    func purchaseRestoringFinished(in premiumManager: PremiumManager) {
        assertionFailure("Consumable purchases cannot be restored")
    }
}
