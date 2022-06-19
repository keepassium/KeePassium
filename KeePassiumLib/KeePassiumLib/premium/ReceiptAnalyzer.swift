//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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

public struct PurchaseHistory: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case containsTrial
        case containsLifetimePurchase
        case latestPremiumProduct
        case latestPremiumExpiryDate
        case premiumSupportExpiryDate
        case premiumFallbackDate
    }
    public internal(set) var containsTrial: Bool
    
    public internal(set) var containsLifetimePurchase: Bool
    
    public internal(set) var latestPremiumProduct: InAppProduct?
    
    public internal(set) var latestPremiumExpiryDate: Date?
    
    public internal(set) var premiumFallbackDate: Date?
    
    public internal(set) var premiumSupportExpiryDate: Date?
    
    static let empty = {
        PurchaseHistory(
            containsTrial: false,
            containsLifetimePurchase: false,
            latestPremiumProduct: nil,
            latestPremiumExpiryDate: nil,
            premiumSupportExpiryDate: nil,
            premiumFallbackDate: nil
        )
    }()
    
    static let prepaidProVersion = {
        PurchaseHistory(
            containsTrial: false,
            containsLifetimePurchase: true,
            latestPremiumProduct: .forever,
            latestPremiumExpiryDate: Date.distantFuture,
            premiumSupportExpiryDate: Date.distantFuture,
            premiumFallbackDate: Date.distantFuture
        )
    }()
    
    static let betaTesting = {
        PurchaseHistory(
            containsTrial: false,
            containsLifetimePurchase: true,
            latestPremiumProduct: .betaForever,
            latestPremiumExpiryDate: Date.distantFuture,
            premiumSupportExpiryDate: nil,
            premiumFallbackDate: Date.distantFuture
        )
    }()
    
    private init(
        containsTrial: Bool,
        containsLifetimePurchase: Bool,
        latestPremiumProduct: InAppProduct?,
        latestPremiumExpiryDate: Date?,
        premiumSupportExpiryDate: Date?,
        premiumFallbackDate: Date?
    ) {
        self.containsTrial = containsTrial
        self.containsLifetimePurchase = containsLifetimePurchase
        self.latestPremiumProduct = latestPremiumProduct
        self.latestPremiumExpiryDate = latestPremiumExpiryDate
        self.premiumSupportExpiryDate = premiumSupportExpiryDate
        self.premiumFallbackDate = premiumFallbackDate
    }
    
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        containsTrial = try values.decode(Bool.self, forKey: .containsTrial)
        containsLifetimePurchase = try values.decode(Bool.self, forKey: .containsLifetimePurchase)
        latestPremiumProduct = try values.decode(InAppProduct?.self, forKey: .latestPremiumProduct)
        latestPremiumExpiryDate = try values.decode(Date?.self, forKey: .latestPremiumExpiryDate)
        premiumSupportExpiryDate = try values.decode(Date?.self, forKey: .premiumSupportExpiryDate)
        premiumFallbackDate = try values.decode(Date?.self, forKey: .premiumFallbackDate)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(containsTrial, forKey: .containsTrial)
        try container.encode(containsLifetimePurchase, forKey: .containsLifetimePurchase)
        try container.encode(latestPremiumProduct, forKey: .latestPremiumProduct)
        try container.encode(latestPremiumExpiryDate, forKey: .latestPremiumExpiryDate)
        try container.encode(premiumSupportExpiryDate, forKey: .premiumSupportExpiryDate)
        try container.encode(premiumFallbackDate, forKey: .premiumFallbackDate)
    }
}

class ReceiptAnalyzer {
    private let adjacentIntervalsTolerance = 7 * TimeInterval.day
    
    
    struct DateInterval: CustomDebugStringConvertible {
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
    
    
    static func logPurchaseHistory() {
        do {
            let receipt = try InAppReceipt.localReceipt()
            guard receipt.hasPurchases else {
                Diag.debug("No previous purchases found.")
                return
            }
            
            Diag.debug("Purchase history:")
            let sortedPurchases = receipt.purchases.sorted(by: { $0.purchaseDate > $1.purchaseDate })
            sortedPurchases.forEach { purchase in
                var flags = [String]()
                if let cancellationDateString = purchase.cancellationDateString {
                    flags.append("- cancelled on \(cancellationDateString)")
                }
                if purchase.subscriptionTrialPeriod || purchase.subscriptionIntroductoryPricePeriod {
                    flags.append("- trial")
                }
                Diag.debug(
                    """
                    \(purchase.productIdentifier): purchased on \(purchase.purchaseDateString) \
                    until \(purchase.subscriptionExpirationDateString ?? "(no date)") \
                    \(flags.joined(separator: " "))
                    """
                )
            }
        } catch {
            Diag.error(error.localizedDescription)
        }
    }
    
    func loadReceipt() -> PurchaseHistory {
        if BusinessModel.type == .prepaid {
            return PurchaseHistory.prepaidProVersion
        }
        if Settings.current.isTestEnvironment {
            Diag.info("Enabling premium for test environment")
            return PurchaseHistory.betaTesting
        }
        
        do {
            let receipt = try InAppReceipt.localReceipt()
            guard receipt.hasPurchases else {
                return PurchaseHistory.empty
            }

            var purchaseHistory = PurchaseHistory.empty
            processSubscriptionPurchases(receipt, &purchaseHistory)
            processVersionPurchases(receipt, &purchaseHistory)
            processLifetimePurchases(receipt, &purchaseHistory)
            return purchaseHistory
        } catch {
            if ProcessInfo.isCatalystApp {
                Diag.info("Catalyst app without App Store receipt, assuming beta version")
                return PurchaseHistory.betaTesting
            }
            Diag.warning(error.localizedDescription)
            return PurchaseHistory.empty
        }
    }
    
    
    private func processLifetimePurchases(
        _ receipt: InAppReceipt,
        _ purchaseHistory: inout PurchaseHistory
    ) {
        for lifetimeProduct in InAppProduct.allForever {
            let productPurchases = receipt.purchases(ofProductIdentifier: lifetimeProduct.rawValue)
            for purchase in productPurchases {
                guard purchase.cancellationDateString == nil else {
                    continue
                }

                purchaseHistory.containsLifetimePurchase = true
                purchaseHistory.latestPremiumProduct = lifetimeProduct
                purchaseHistory.latestPremiumExpiryDate = Date.distantFuture
                purchaseHistory.premiumFallbackDate = Date.distantFuture
                purchaseHistory.premiumSupportExpiryDate = purchaseHistory.latestPremiumExpiryDate?
                    .addingTimeInterval(lifetimeProduct.premiumSupportDurationAfterExpiry)
                return
            }
        }
    }

    
    private func processVersionPurchases(
        _ receipt: InAppReceipt,
        _ purchaseHistory: inout PurchaseHistory
    ) {
        guard let purchasedVersion = getLatestPurchasedVersion(receipt) else {
            return
        }
        guard let versionProduct = InAppProduct(rawValue: purchasedVersion.productIdentifier) else {
            Diag.error("Unexpected product ID, ignoring")
            assertionFailure()
            return
        }
        let versionExpiryDate = purchasedVersion.purchaseDate
        let versionFallbackDate = purchasedVersion.purchaseDate
        let versionPremiumSupportExpiryDate = versionExpiryDate
            .addingTimeInterval(versionProduct.premiumSupportDurationAfterExpiry)

        guard let subscriptionExpiryDate = purchaseHistory.latestPremiumExpiryDate else {
            purchaseHistory.latestPremiumProduct = versionProduct
            purchaseHistory.latestPremiumExpiryDate = versionExpiryDate
            purchaseHistory.premiumFallbackDate = versionFallbackDate
            purchaseHistory.premiumSupportExpiryDate = versionPremiumSupportExpiryDate
            return
        }
        
        let isSubscriptionActive = (subscriptionExpiryDate.timeIntervalSinceNow > 0)
        if isSubscriptionActive {
            purchaseHistory.premiumFallbackDate = Date.max(
                purchaseHistory.premiumFallbackDate,
                versionFallbackDate)
            return
        }
        
        if let subscriptionFallbackDate = purchaseHistory.premiumFallbackDate,
           subscriptionFallbackDate > versionFallbackDate
        {
            purchaseHistory.premiumSupportExpiryDate = Date.max(
                purchaseHistory.premiumSupportExpiryDate,
                versionPremiumSupportExpiryDate
            )
        } else {
            purchaseHistory.latestPremiumProduct = versionProduct
            purchaseHistory.latestPremiumExpiryDate = versionExpiryDate
            purchaseHistory.premiumFallbackDate = versionFallbackDate
            purchaseHistory.premiumSupportExpiryDate = versionPremiumSupportExpiryDate
        }
    }
    
    private func getLatestPurchasedVersion(_ receipt: InAppReceipt) -> InAppPurchase? {
        let versionPurchases = receipt.purchases.filter { purchase in
            guard purchase.cancellationDateString == nil else { return false }
            guard let product = InAppProduct(rawValue: purchase.productIdentifier) else {
                Diag.error("Unexpected in-app product ID, ignoring [id: \(purchase.productIdentifier)]")
                assertionFailure()
                return false
            }
            return product.isVersionPurchase
        }
        
        let latestPurchasedVersion = versionPurchases.max(by: { $1.purchaseDate > $0.purchaseDate })
        return latestPurchasedVersion
    }
    
    
    private func processSubscriptionPurchases(
        _ receipt: InAppReceipt,
        _ purchaseHistory: inout PurchaseHistory
    ) {
        purchaseHistory.containsTrial = receipt.autoRenewablePurchases.reduce(false) {
            (result, purchase) -> Bool in
            return result
                || purchase.subscriptionTrialPeriod
                || purchase.subscriptionIntroductoryPricePeriod
        }

        let validSubscriptions = receipt.autoRenewablePurchases
            .filter { $0.cancellationDateString == nil } 
        purchaseHistory.premiumFallbackDate = getSubscriptionFallbackDate(validSubscriptions)
        
        if let latestSubscription = getLatestExpiringSubscription(validSubscriptions) {
            guard let product = InAppProduct(rawValue: latestSubscription.productIdentifier)
            else {
                Diag.error("Unexpected in-app product ID, aborting [id: \(latestSubscription.productIdentifier)]")
                assertionFailure()
                return
            }
            purchaseHistory.latestPremiumProduct = product
            purchaseHistory.latestPremiumExpiryDate = latestSubscription.subscriptionExpirationDate
            purchaseHistory.premiumSupportExpiryDate = latestSubscription.subscriptionExpirationDate?
                .addingTimeInterval(product.premiumSupportDurationAfterExpiry)
        }
    }
    
    private func getLatestExpiringSubscription(_ validSubscriptions: [InAppPurchase]) -> InAppPurchase? {
        let subscriptionsRecentToOld = validSubscriptions
            .filter { $0.subscriptionExpirationDate != nil } 
            .sorted { $0.subscriptionExpirationDate! > $1.subscriptionExpirationDate! }
        return subscriptionsRecentToOld.first
    }
    
    private func getSubscriptionFallbackDate(_ validSubscriptions: [InAppPurchase]) -> Date? {
        let sortedSubscriptions = validSubscriptions
            .sorted { $0.purchaseDate > $1.purchaseDate } 
        var subscriptionIterator = sortedSubscriptions.makeIterator()
        guard let latestSubscription = subscriptionIterator.next() else {
            return nil
        }
        
        guard var continuousInterval = DateInterval(fromSubscription: latestSubscription) else {
            assertionFailure()
            return nil 
        }
        
        var fallbackDate: Date? = nil
        while true {
            let duration = continuousInterval.duration
            if duration >= .year {
                fallbackDate = continuousInterval.to.addingTimeInterval(-TimeInterval.year)
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
        
        if let _fallbackDate = fallbackDate {
            Diag.info("Subscription fallback date: \(dateFormatter.string(from: _fallbackDate))")
        }
        return fallbackDate
    }
}

fileprivate extension Date {
    static func max(_ one: Date?, _ two: Date?) -> Date? {
        guard let one = one else {
            return two
        }
        guard let two = two else {
            return one
        }
        if one > two {
            return one
        } else {
            return two
        }
    }
}
