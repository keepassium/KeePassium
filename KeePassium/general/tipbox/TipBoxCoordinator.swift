//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit

final class TipBoxCoordinator: BaseCoordinator {
    private let premiumManager: PremiumManager
    private let tipBoxVC: TipBoxVC
    private var availableProducts = [SKProduct]()

    override init(router: NavigationRouter) {
        self.premiumManager = PremiumManager.shared
        tipBoxVC = TipBoxVC.instantiateFromStoryboard()
        super.init(router: router)
        tipBoxVC.delegate = self
    }

    deinit {
        premiumManager.delegate = nil
    }

    override func start() {
        super.start()
        _pushInitialViewController(tipBoxVC, dismissButtonStyle: .close, animated: true)
        premiumManager.delegate = self

        Diag.info(TipBox.getStatus())
        TipBox.registerTipBoxSeen()
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
        guard let products, products.count > 0 else {
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

        guard let skProduct else {
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
