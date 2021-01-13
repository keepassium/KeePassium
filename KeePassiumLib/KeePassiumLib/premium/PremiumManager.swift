//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import StoreKit

public enum InAppProduct: String {
    public enum Period {
        case oneTime
        case yearly
        case monthly
        case other
    }
    
    case betaForever = "com.keepassium.ios.iap.beta.forever"
    
    case forever = "com.keepassium.ios.iap.forever"
    case forever2 = "com.keepassium.ios.iap.forever.2"
    case montlySubscription = "com.keepassium.ios.iap.subscription.1month"
    case yearlySubscription = "com.keepassium.ios.iap.subscription.1year"
    
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
        }
    }
    
    public static func period(productIdentifier: String) -> Period {
        if productIdentifier.contains(".forever") {
            return .oneTime
        } else if productIdentifier.contains(".1year") {
            return .yearly
        } else if productIdentifier.contains(".1month") {
            return .monthly
        } else {
            assertionFailure("Should not be here")
            return .other
        }
    }
}



public protocol PremiumManagerDelegate: class {
    func purchaseStarted(in premiumManager: PremiumManager)
    
    func purchaseSucceeded(_ product: InAppProduct, in premiumManager: PremiumManager)
    
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
    private let gracePeriodInSeconds: TimeInterval = 1 * 60

    private let lapsePeriodInSeconds: TimeInterval = 7 * 60
    
    private let heavyUseThreshold: TimeInterval = 5 * 60
#else
    private let gracePeriodInSeconds: TimeInterval = 2 * 24 * 60 * 60 
    private let lapsePeriodInSeconds: TimeInterval = 2 * 24 * 60 * 60 
    private let heavyUseThreshold: TimeInterval = 8 * 60 * 60 / 12 
#endif
    
    private let premiumSupportDuration: TimeInterval = 365 * 24 * 60 * 60 

    
    
    public private(set) var isTrialAvailable: Bool = true
    
    public private(set) var fallbackDate: Date? = nil
    
    public enum Status {
        case initialGracePeriod
        case subscribed
        case lapsed
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
        updateStatus(allowSubscriptionExpiration: true)
    }
    
    public func updateStatus() {
        updateStatus(allowSubscriptionExpiration: false)
    }

    #if DEBUG
    public func resetSubscription() {
        try? Keychain.shared.clearPremiumExpiryDate()
        usageMonitor.resetStats()
        Settings.current.resetFirstLaunchTimestampToNow()
        updateStatus(allowSubscriptionExpiration: true)
    }
    #endif
    
    private func updateStatus(allowSubscriptionExpiration: Bool) {
        if !allowSubscriptionExpiration && status == .subscribed {
            return
        }
        
        let previousStatus = status
        var wasStatusSet = false
        if let expiryDate = getPremiumExpiryDate() {
            if expiryDate.timeIntervalSinceNow > 0 {
                status = .subscribed
                wasStatusSet = true
            } else if Date.now.timeIntervalSince(expiryDate) < lapsePeriodInSeconds {
                status = .lapsed
                wasStatusSet = true
            }
        } else {
            if gracePeriodSecondsRemaining > 0 {
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
    
    private var isSubscribed: Bool {
        if let premiumExpiryDate = getPremiumExpiryDate() {
            let isPremium = Date.now < premiumExpiryDate
            return isPremium
        }
        return false
    }

    public func getPremiumProduct() -> InAppProduct? {
        if BusinessModel.type == .prepaid {
            return InAppProduct.forever
        }
        
        #if DEBUG
        return InAppProduct.betaForever 
        #endif
        if Settings.current.isTestEnvironment {
            return InAppProduct.betaForever
        }

        do {
            return try Keychain.shared.getPremiumProduct() 
        } catch {
            Diag.error("Failed to get premium product info [message: \(error.localizedDescription)]")
            return nil
        }
    }
    
    public func getPremiumExpiryDate() -> Date? {
        if BusinessModel.type == .prepaid {
            return Date.distantFuture
        }
        
        #if DEBUG
        return Date.distantFuture 
        #endif
        if Settings.current.isTestEnvironment {
            return Date.distantFuture
        }
        
        do {
            return try Keychain.shared.getPremiumExpiryDate() 
        } catch {
            Diag.error("Failed to get premium expiry date [message: \(error.localizedDescription)]")
            return nil
        }
    }
    
    fileprivate func setPremiumExpiry(for product: InAppProduct, to expiryDate: Date) -> Bool {
        do {
            try Keychain.shared.setPremiumExpiry(for: product, to: expiryDate)
            updateStatus()
            return true
        } catch {
            Diag.error("Failed to save purchase expiry date [message: \(error.localizedDescription)]")
            return false
        }
    }
    
    
    public func reloadReceipt() {
        guard BusinessModel.type == .freemium else { return }
        
        let oldFallbackDate = fallbackDate
        if AppGroup.isMainApp {
            let receiptAnalyzer = ReceiptAnalyzer()
            receiptAnalyzer.loadReceipt()
            isTrialAvailable = !receiptAnalyzer.containsTrial
            fallbackDate = receiptAnalyzer.fallbackDate
            do {
                try Keychain.shared.setPremiumFallbackDate(fallbackDate) 
            } catch {
                Diag.warning("Failed to store premium fallback date [message: \(error.localizedDescription)]")
            }
        } else { 
            do {
                fallbackDate = try Keychain.shared.getPremiumFallbackDate()  
            } catch {
                Diag.warning("Failed to retrieve premium fallback date [message: \(error.localizedDescription)]")
            }
        }
        
        if let newFallbackDate = fallbackDate, newFallbackDate != oldFallbackDate {
            Diag.info("Premium fallback date changed to \(fallbackDate!.iso8601String())")
            notifyStatusChanged()
        }
    }
    
    public func isPremiumSupportAvailable() -> Bool {
        switch status {
        case .subscribed,
             .lapsed:
            return true
        case .initialGracePeriod,
             .freeLightUse,
             .freeHeavyUse:
            if let fallbackDate = fallbackDate {
                let supportExpiryDate = fallbackDate.addingTimeInterval(premiumSupportDuration)
                return supportExpiryDate < .now
            }
            return false
        }
    }
    
    
    public func isAvailable(feature: PremiumFeature) -> Bool {
        return feature.isAvailable(in: status, fallbackDate: fallbackDate)
    }
    
    
    public var gracePeriodSecondsRemaining: Double {
        let firstLaunchTimestamp = Settings.current.firstLaunchTimestamp
        let secondsFromFirstLaunch = abs(Date.now.timeIntervalSince(firstLaunchTimestamp))
        let secondsLeft = gracePeriodInSeconds - secondsFromFirstLaunch
        return secondsLeft
    }
    
    public var secondsUntilExpiration: Double? {
        guard let expiryDate = getPremiumExpiryDate() else { return nil }
        return expiryDate.timeIntervalSinceNow
    }
    
    public var secondsSinceExpiration: Double? {
        guard let secondsUntilExpiration = secondsUntilExpiration else { return nil }
        return -secondsUntilExpiration
    }
    
    public var lapsePeriodSecondsRemaining: Double? {
        guard let secondsSinceExpiration = secondsSinceExpiration,
            secondsSinceExpiration > 0 
            else { return nil }
        let secondsLeft = lapsePeriodInSeconds - secondsSinceExpiration
        return secondsLeft
    }

    
    public fileprivate(set) var availableProducts: [SKProduct]?
    private let purchaseableProductIDs = Set<String>([
        InAppProduct.forever2.rawValue,
        InAppProduct.montlySubscription.rawValue,
        InAppProduct.yearlySubscription.rawValue])
    
    private var productsRequest: SKProductsRequest?

    public typealias ProductsRequestHandler = (([SKProduct]?, Error?) -> Void)
    fileprivate var productsRequestHandler: ProductsRequestHandler?
    
    public func requestAvailableProducts(completionHandler: @escaping ProductsRequestHandler)
    {
        productsRequest?.cancel()
        productsRequestHandler = completionHandler
        
        productsRequest = SKProductsRequest(productIdentifiers: purchaseableProductIDs)
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
        didReceive response: SKProductsResponse)
    {
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
        updatedTransactions transactions: [SKPaymentTransaction])
    {
        reloadReceipt()
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                didPurchase(with: transaction, in: queue)
            case .purchasing:
                delegate?.purchaseStarted(in: self)
                break
            case .failed:
                didFailToPurchase(with: transaction, in: queue)
                break
            case .restored:
                didRestorePurchase(transaction, in: queue)
                break
            case .deferred:
                delegate?.purchaseDeferred(in: self)
                break
            @unknown default:
                Diag.warning("Unknown transaction state")
                assertionFailure()
            }
        }
    }
    
    public func paymentQueue(
        _ queue: SKPaymentQueue,
        restoreCompletedTransactionsFailedWithError error: Error)
    {
        Diag.error("Failed to restore purchases [message: \(error.localizedDescription)]")
        delegate?.purchaseFailed(with: error, in: self)
    }

    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        ReceiptAnalyzer.logPurchaseHistory()
        Diag.debug("Finished restoring purchases")
        delegate?.purchaseRestoringFinished(in: self)
    }
    
    public func paymentQueue(
        _ queue: SKPaymentQueue,
        shouldAddStorePayment payment: SKPayment,
        for product: SKProduct
        ) -> Bool
    {
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
        
        Diag.info("IAP purchase update [date: \(transactionDate), product: \(productID)]")
        if applyPurchase(of: product, on: transactionDate, skipExpired: false) {
            queue.finishTransaction(transaction)
        }
        delegate?.purchaseSucceeded(product, in: self)
    }
    
    private func didRestorePurchase(_ transaction: SKPaymentTransaction, in queue: SKPaymentQueue) {
        guard let transactionDate = transaction.transactionDate else {
            assertionFailure()
            Diag.warning("IAP transaction date is empty?!")
            queue.finishTransaction(transaction)
            return
        }
        
        let productID = transaction.payment.productIdentifier
        guard let product = InAppProduct(rawValue: productID) else {
            assertionFailure()
            Diag.error("IAP with unrecognized product ID [id: \(productID)]")
            queue.finishTransaction(transaction)
            return
        }
        Diag.info("Restored purchase [date: \(transactionDate), product: \(productID)]")
        if applyPurchase(of: product, on: transactionDate, skipExpired: true) {
            queue.finishTransaction(transaction)
        }
    }
    
    private func applyPurchase(
        of product: InAppProduct,
        on transactionDate: Date,
        skipExpired: Bool = false
        ) -> Bool
    {
        let calendar = Calendar.current
        let newExpiryDate: Date
        switch product.period {
        case .oneTime:
            newExpiryDate = Date.distantFuture
        case .yearly:
            #if DEBUG
                newExpiryDate = calendar.date(byAdding: .hour, value: 1, to: transactionDate)!
            #else
                newExpiryDate = calendar.date(byAdding: .year, value: 1, to: transactionDate)!
            #endif
        case .monthly:
            #if DEBUG
                newExpiryDate = calendar.date(byAdding: .minute, value: 5, to: transactionDate)!
            #else
                newExpiryDate = calendar.date(byAdding: .month, value: 1, to: transactionDate)!
            #endif
        case .other:
            assertionFailure()
            newExpiryDate = calendar.date(byAdding: .year, value: 1, to: transactionDate)!
        }
        
        if skipExpired && newExpiryDate < Date.now {
            return true
        }
        
        let oldExpiryDate = getPremiumExpiryDate()
        if newExpiryDate > (oldExpiryDate ?? Date.distantPast) {
            let isNewDateSaved = setPremiumExpiry(for: product, to: newExpiryDate)
            return isNewDateSaved
        } else {
            return true
        }
    }
    
    private func didFailToPurchase(
        with transaction: SKPaymentTransaction,
        in queue: SKPaymentQueue)
    {
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
