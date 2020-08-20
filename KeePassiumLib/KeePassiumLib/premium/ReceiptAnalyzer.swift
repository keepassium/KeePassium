//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import TPInAppReceipt

fileprivate let dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") 
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter
}()

class ReceiptAnalyzer {
    let adjacentIntervalsTolerance = 7 * DateInterval.day
    
    
    struct DateInterval: CustomDebugStringConvertible {
        static let day = TimeInterval(24 * 60 * 60)
        static let year = 365 * DateInterval.day

        var from: Date
        var to: Date
        
        var duration: TimeInterval {
            return to.timeIntervalSince(from)
        }
            
        init?(fromSubscription subscription: InAppPurchase) {
            assert(subscription.isRenewableSubscription)
            guard let expiryDate = subscription.subscriptionExpirationDate else {
                assertionFailure()
                Diag.warning("Subscription with an empty expiration date?")
                return nil
            }
            self.from = subscription.purchaseDate
            self.to = expiryDate
        }
        
        func canExtendLeft(with interval: DateInterval, tolerance: TimeInterval) -> Bool {
            guard interval.to <= self.to else {
                return false
            }
            guard interval.to > self.from.addingTimeInterval(-tolerance) else {
                return false
            }
            return true
        }
        
        var debugDescription: String {
            return "{ \(dateFormatter.string(from: from)) to \(dateFormatter.string(from: to)) }"
        }
    }
    
    
    
    var containsTrial = false
    
    var containsLifetimePurchase = false
    
    var fallbackDate: Date? = nil
    
    
    
    static func logPurchaseHistory() {
        do {
            let receipt = try InAppReceipt.localReceipt()
            guard receipt.hasPurchases else {
                Diag.debug("No previous purchases found.")
                return
            }
            
            Diag.debug("Purchase history:")
            receipt.purchases.forEach { purchase in
                var flags = [String]()
                if purchase.cancellationDateString != nil {
                    flags.append("cancelled")
                }
                if purchase.subscriptionTrialPeriod || purchase.subscriptionIntroductoryPricePeriod {
                    flags.append("trial")
                }
                Diag.debug(
                    """
                    \(purchase.productIdentifier) - \(purchase.purchaseDateString) \
                    to \(purchase.subscriptionExpirationDateString ?? "nil") \
                    \(flags.joined())
                    """
                )
            }
        } catch {
            Diag.error(error.localizedDescription)
        }
    }
    
    func loadReceipt() {
        do {
            let receipt = try InAppReceipt.localReceipt()
            guard receipt.hasPurchases else {
                return
            }
            
            containsTrial = receipt.autoRenewablePurchases.reduce(false) {
                (result, purchase) -> Bool in
                return result
                    || purchase.subscriptionTrialPeriod
                    || purchase.subscriptionIntroductoryPricePeriod
            }
            
            let sortedSubscriptions = receipt.autoRenewablePurchases
                .filter { $0.cancellationDateString == nil } 
                .sorted { $0.purchaseDate > $1.purchaseDate } 

            analyzeSubscriptions(sortedSubscriptions)
            
            containsLifetimePurchase =
                receipt.containsPurchase(ofProductIdentifier: InAppProduct.forever.rawValue) ||
                receipt.containsPurchase(ofProductIdentifier: InAppProduct.forever2.rawValue)
            if containsLifetimePurchase {
                fallbackDate = .distantFuture
            }
        } catch {
            Diag.error(error.localizedDescription)
        }
    }
        
    private func analyzeSubscriptions(_ sortedSubscriptions: [InAppPurchase]) {
        var subscriptionIterator = sortedSubscriptions.makeIterator()
        guard let latestSubscription = subscriptionIterator.next() else {
            return
        }
        
        guard var continuousInterval = DateInterval(fromSubscription: latestSubscription) else {
            assertionFailure()
            return 
        }
        
        while true {
            let duration = continuousInterval.duration
            if duration >= DateInterval.year {
                fallbackDate = continuousInterval.to.addingTimeInterval(-DateInterval.year)
                break
            }

            guard let nextSubscription = subscriptionIterator.next() else {
                break
            }
            guard let interval = DateInterval(fromSubscription: nextSubscription) else {
                assertionFailure()
                break 
            }
            
            let canExtend = continuousInterval.canExtendLeft(with: interval, tolerance: adjacentIntervalsTolerance)
            if canExtend {
                continuousInterval.from = interval.from
            } else {
                continuousInterval = interval
            }
        }
        if let fallbackDate = fallbackDate {
            Diag.info("Subscription fallback date: \(dateFormatter.string(from: fallbackDate))")
        }
    }
}
