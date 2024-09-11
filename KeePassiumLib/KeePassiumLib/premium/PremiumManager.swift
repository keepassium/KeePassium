//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import StoreKit

public enum InAppProduct: String, Codable {
    public enum Kind {
        case premium
        case donation
    }
    public enum Period {
        case oneTime
        case yearly
        case monthly
        case other
    }

    static let allForever = [.forever, forever2]

    case betaForever = "com.keepassium.ios.iap.beta.forever"

    case forever = "com.keepassium.ios.iap.forever"
    case forever2 = "com.keepassium.ios.iap.forever.2"
    case montlySubscription = "com.keepassium.ios.iap.subscription.1month"
    case yearlySubscription = "com.keepassium.ios.iap.subscription.1year"
    case version88 = "com.keepassium.ios.iap.version.88"
    case version96 = "com.keepassium.ios.iap.version.96"
    case version99 = "com.keepassium.ios.iap.version.99"
    case version120 = "com.keepassium.ios.iap.version.120"
    case version139 = "com.keepassium.ios.iap.version.139"
    case version154 = "com.keepassium.ios.iap.version.154"

    case donationSmall = "com.keepassium.ios.donation.small"
    case donationMedium = "com.keepassium.ios.donation.medium"
    case donationLarge = "com.keepassium.ios.donation.large"

    public var period: Period {
        return InAppProduct.period(productIdentifier: self.rawValue)
    }

    public var isSubscription: Bool {
        switch self {
        case .forever,
             .forever2,
             .betaForever:
            return false
        case .montlySubscription,
             .yearlySubscription:
            return true
        case .version88,
             .version96,
             .version99,
             .version120,
             .version139,
             .version154:
            return false
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            return false
        }
    }

    public var isVersionPurchase: Bool {
        switch self {
        case .version88,
             .version96,
             .version99,
             .version120,
             .version139,
             .version154:
            return true
        case .betaForever,
             .forever,
             .forever2,
             .montlySubscription,
             .yearlySubscription:
            return false
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            return false
        }
    }

    public var kind: Kind {
        switch self {
        case .betaForever,
             .forever,
             .forever2,
             .montlySubscription,
             .yearlySubscription,
             .version88,
             .version96,
             .version99,
             .version120,
             .version139,
             .version154:
            return .premium
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            return .donation
        }
    }

    public static func period(productIdentifier: String) -> Period {
        if productIdentifier.contains(".forever") {
            return .oneTime
        } else if productIdentifier.contains(".1year") {
            return .yearly
        } else if productIdentifier.contains(".1month") {
            return .monthly
        } else if productIdentifier.contains(".version.") {
            return .oneTime
        } else if productIdentifier.contains(".donation.") {
            return .other
        } else {
            assertionFailure("Should not be here")
            return .other
        }
    }

    public var premiumSupportDurationAfterExpiry: TimeInterval {
        switch self {
        case .version88,
             .version96,
             .version99,
             .version120,
             .version139,
             .version154:
            return 1 * .year
        case .betaForever,
             .forever,
             .forever2:
            return 0
        case .montlySubscription,
             .yearlySubscription:
            return 0
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            assertionFailure("Premium support is not applicable to donations")
            return 0
        }
    }
}


public protocol PremiumManagerDelegate: AnyObject {
    func purchaseStarted(in premiumManager: PremiumManager)

    func purchaseSucceeded(_ product: InAppProduct, skProduct: SKProduct?, in premiumManager: PremiumManager)

    func purchaseDeferred(in premiumManager: PremiumManager)

    func purchaseFailed(with error: Error, in premiumManager: PremiumManager)

    func purchaseCancelledByUser(in premiumManager: PremiumManager)

    func purchaseRestoringFinished(in premiumManager: PremiumManager)
}

public class PremiumManager: NSObject {
    public static let shared = PremiumManager()

    public weak var delegate: PremiumManagerDelegate? {
        willSet {
            assert(newValue == nil || delegate == nil, "PremiumManager supports only one delegate")
        }
    }


#if DEBUG
    private let gracePeriod: TimeInterval = 1 * .minute

    private let lapsePeriod: TimeInterval = 2 * .minute

    private let heavyUseThreshold: TimeInterval = 5 * .minute
#else
    private let gracePeriod: TimeInterval = 2 * .day
    private let lapsePeriod: TimeInterval = 2 * .day
    private let heavyUseThreshold: TimeInterval = 8 * .hour / 12 
#endif


    private var purchaseHistory = PurchaseHistory.empty

    public var isTrialAvailable: Bool { return !purchaseHistory.containsTrial }

    public var fallbackDate: Date? { return purchaseHistory.premiumFallbackDate }

    public enum Status {
        case initialGracePeriod
        case subscribed
        case lapsed
        case fallback
        case freeLightUse
        case freeHeavyUse
    }

    public var status: Status = .initialGracePeriod

    public static let statusUpdateNotification =
        Notification.Name("com.keepassium.premiumManager.statusUpdated")

    fileprivate func notifyStatusChanged() {
        NotificationCenter.default.post(name: PremiumManager.statusUpdateNotification, object: self)
    }

    public let usageMonitor = UsageMonitor()

    private override init() {
        super.init()
        reloadReceipt()
        updateStatus(allowSubscriptionExpiration: true)
    }

    public func updateStatus() {
        updateStatus(allowSubscriptionExpiration: false)
    }

    private func updateStatus(allowSubscriptionExpiration: Bool) {
        if !allowSubscriptionExpiration && status == .subscribed {
            return
        }

        let previousStatus = status
        var wasStatusSet = false
        if let expiryDate = purchaseHistory.latestPremiumExpiryDate {
            if expiryDate.timeIntervalSinceNow > 0 {
                status = .subscribed
                wasStatusSet = true
            } else if Date.now.timeIntervalSince(expiryDate) < lapsePeriod {
                status = .lapsed
                wasStatusSet = true
            } else if purchaseHistory.premiumFallbackDate != nil {
                status = .fallback
                wasStatusSet = true
            }
        } else {
            if gracePeriodRemaining > 0 {
                status = .initialGracePeriod
                wasStatusSet = true
            }
        }
        if !wasStatusSet { 
            let appUsage = usageMonitor.getAppUsageDuration(.perMonth)
            if appUsage < heavyUseThreshold {
                status = .freeLightUse
            } else {
                status = .freeHeavyUse
            }
        }

        if status != previousStatus {
            Diag.info("Premium status has changed [was: \(previousStatus), now: \(status)]")
            notifyStatusChanged()
        }
    }

    public func getPurchaseHistory() -> PurchaseHistory {
        return purchaseHistory
    }


    public func reloadReceipt() {
        let oldPurchaseHistory = purchaseHistory
        if AppGroup.isMainApp {
            let receiptAnalyzer = ReceiptAnalyzer()
            purchaseHistory = receiptAnalyzer.loadReceipt()
            do {
                try Keychain.shared.setPurchaseHistory(purchaseHistory) 
            } catch {
                Diag.error("Failed to save purchase history [message: \(error.localizedDescription)]")
            }
        } else {
            do {
                let savedHistory = try Keychain.shared.getPurchaseHistory() 
                purchaseHistory = savedHistory ?? PurchaseHistory.empty
            } catch {
                Diag.error("Failed to load purchase history [message: \(error.localizedDescription)]")
            }
        }

        if purchaseHistory != oldPurchaseHistory {
            Diag.info("Purchase history updated")
            notifyStatusChanged()
        }
    }

    public func isPremiumSupportAvailable() -> Bool {
        guard let premiumSupportExpiryDate = purchaseHistory.premiumSupportExpiryDate else {
            return false
        }
        let timeLeft = premiumSupportExpiryDate.timeIntervalSinceNow
        return timeLeft > 0
    }


    public func isAvailable(feature: PremiumFeature) -> Bool {
        return feature.isAvailable(in: status, fallbackDate: fallbackDate)
    }


    public var gracePeriodRemaining: TimeInterval {
        let firstLaunchTimestamp = Settings.current.firstLaunchTimestamp
        let timeSinceFirstLaunch = Date.now.timeIntervalSince(firstLaunchTimestamp)
        if timeSinceFirstLaunch < 0 {
            Diag.info("Time travel detected")
            return 0.0
        }
        let timeLeft = gracePeriod - timeSinceFirstLaunch
        return timeLeft
    }


    public fileprivate(set) var availableProducts: [SKProduct]?
    private let purchaseableProducts: [InAppProduct.Kind: [InAppProduct]] = [
        .premium: [
            .forever2,
            .montlySubscription,
            .yearlySubscription,
            .version154,
        ],
        .donation: [
            .donationSmall,
            .donationMedium,
            .donationLarge,
        ]
    ]

    private var productsRequest: SKProductsRequest?

    public typealias ProductsRequestHandler = (([SKProduct]?, Error?) -> Void)
    fileprivate var productsRequestHandler: ProductsRequestHandler?

    public func requestAvailableProducts(
        ofKind kind: InAppProduct.Kind,
        completionHandler: @escaping ProductsRequestHandler
    ) {
        productsRequest?.cancel()
        productsRequestHandler = completionHandler

        let productsToRequest = purchaseableProducts[kind] ?? []
        let productIDSetToRequest = Set<String>(productsToRequest.map { $0.rawValue })

        productsRequest = SKProductsRequest(productIdentifiers: productIDSetToRequest)
        productsRequest!.delegate = self
        productsRequest!.start()
    }


    public func startObservingTransactions() {
        reloadReceipt()
        SKPaymentQueue.default().add(self)
    }

    public func finishObservingTransactions() {
        SKPaymentQueue.default().remove(self)
    }

    public func purchase(_ product: SKProduct) {
        Diag.info("Starting purchase [product: \(product.productIdentifier)]")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    public func restorePurchases() {
        Diag.info("Starting to restore purchases")
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
}

extension PremiumManager: SKProductsRequestDelegate {
    public func productsRequest(
        _ request: SKProductsRequest,
        didReceive response: SKProductsResponse
    ) {
        Diag.debug("Received list of in-app purchases")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.availableProducts = response.products
            self.productsRequestHandler?(self.availableProducts, nil)
            self.productsRequest = nil
            self.productsRequestHandler = nil
        }
    }

    public func request(_ request: SKRequest, didFailWithError error: Error) {
        Diag.warning("Failed to acquire list of in-app purchases [message: \(error.localizedDescription)]")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.availableProducts = nil
            self.productsRequestHandler?(nil, error)
            self.productsRequest = nil
            self.productsRequestHandler = nil
        }
    }
}

extension PremiumManager: SKPaymentTransactionObserver {
    public func paymentQueue(
        _ queue: SKPaymentQueue,
        updatedTransactions transactions: [SKPaymentTransaction]
    ) {
        reloadReceipt()
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                didPurchase(with: transaction, in: queue)
            case .purchasing:
                delegate?.purchaseStarted(in: self)
            case .failed:
                didFailToPurchase(with: transaction, in: queue)
            case .restored:
                didRestorePurchase(transaction, in: queue)
            case .deferred:
                delegate?.purchaseDeferred(in: self)
            @unknown default:
                Diag.warning("Unknown transaction state")
                assertionFailure()
            }
        }
    }

    public func paymentQueue(
        _ queue: SKPaymentQueue,
        restoreCompletedTransactionsFailedWithError error: Error
    ) {
        Diag.error("Failed to restore purchases [message: \(error.localizedDescription)]")
        delegate?.purchaseFailed(with: error, in: self)
    }

    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        ReceiptAnalyzer.logPurchaseHistory()
        Diag.debug("Finished restoring purchases")
        reloadReceipt()
        updateStatus(allowSubscriptionExpiration: false)
        delegate?.purchaseRestoringFinished(in: self)
    }

    public func paymentQueue(
        _ queue: SKPaymentQueue,
        shouldAddStorePayment payment: SKPayment,
        for product: SKProduct
    ) -> Bool {
        return true 
    }

    private func didPurchase(with transaction: SKPaymentTransaction, in queue: SKPaymentQueue) {
        guard let transactionDate = transaction.transactionDate else {
            assertionFailure()
            Diag.warning("IAP transaction date is empty?!")
            return
        }

        let productID = transaction.payment.productIdentifier
        guard let product = InAppProduct(rawValue: productID) else {
            assertionFailure()
            Diag.error("IAP with unrecognized product ID [id: \(productID)]")
            return
        }

        let skProduct = availableProducts?.first(where: { $0.productIdentifier == productID })

        Diag.info("IAP purchase update [date: \(transactionDate), product: \(productID)]")
        queue.finishTransaction(transaction)

        reloadReceipt()
        updateStatus(allowSubscriptionExpiration: false)
        delegate?.purchaseSucceeded(product, skProduct: skProduct, in: self)
    }

    private func didRestorePurchase(_ transaction: SKPaymentTransaction, in queue: SKPaymentQueue) {
        defer {
            queue.finishTransaction(transaction)
        }

        guard let transactionDate = transaction.transactionDate else {
            assertionFailure()
            Diag.warning("IAP transaction date is empty?!")
            return
        }

        let productID = transaction.payment.productIdentifier
        guard let _ = InAppProduct(rawValue: productID) else {
            assertionFailure()
            Diag.error("IAP with unrecognized product ID [id: \(productID)]")
            return
        }
        Diag.info("Restored purchase [date: \(transactionDate), product: \(productID)]")
    }

    private func didFailToPurchase(
        with transaction: SKPaymentTransaction,
        in queue: SKPaymentQueue
    ) {
        guard let error = transaction.error as? SKError else {
            assertionFailure()
            Diag.error("In-app purchase failed [message: \(transaction.error?.localizedDescription ?? "nil")]")
            queue.finishTransaction(transaction)
            return
        }

        let productID = transaction.payment.productIdentifier
        guard let _ = InAppProduct(rawValue: productID) else {
            assertionFailure()
            Diag.warning("IAP transaction failed, plus unrecognized product [id: \(productID)]")
            return
        }

        if error.code == .paymentCancelled {
            Diag.info("IAP cancelled by the user [message: \(error.localizedDescription)]")
            delegate?.purchaseCancelledByUser(in: self)
        } else {
            Diag.error("In-app purchase failed [message: \(error.localizedDescription)]")
            delegate?.purchaseFailed(with: error, in: self)
        }
        updateStatus()
        queue.finishTransaction(transaction)
    }
}
