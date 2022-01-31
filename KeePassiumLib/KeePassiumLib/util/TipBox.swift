//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

final public class TipBox {
    private static let totalAmountKey = "tipBox.totalAmount"
    private static let lastSeenDateKey = "tipBox.lastSeenDate"
    private static let lastPurchaseDateKey = "tipBox.lastPurchaseDate"
    private static let currencyCodeKey = "tipBox.currencyCode"

    public private(set) static var totalAmount: Double {
        get {
            let storedValue = UserDefaults.appGroupShared.object(forKey: totalAmountKey) as? Double
            return storedValue ?? 0
        }
        set {
            UserDefaults.appGroupShared.set(newValue, forKey: totalAmountKey)
        }
    }

    public private(set) static var lastSeenDate: Date? {
        get {
            let storedValue = UserDefaults.appGroupShared.object(forKey: lastSeenDateKey) as? Date
            return storedValue
        }
        set {
            UserDefaults.appGroupShared.set(newValue, forKey: lastSeenDateKey)
        }
    }

    public private(set) static var lastPurchaseDate: Date? {
        get {
            let storedValue = UserDefaults.appGroupShared
                .object(forKey: lastPurchaseDateKey) as? Date
            return storedValue
        }
        set {
            UserDefaults.appGroupShared.set(newValue, forKey: lastPurchaseDateKey)
        }
    }
    
    public private(set) static var currencyCode: String? {
        get {
            let storedValue = UserDefaults.appGroupShared
                .object(forKey: currencyCodeKey) as? String
            return storedValue
        }
        set {
            UserDefaults.appGroupShared.set(newValue, forKey: currencyCodeKey)
        }
    }
    
    public static func registerPurchase(amount: NSDecimalNumber, locale: Locale) {
        totalAmount = totalAmount + amount.doubleValue
        lastPurchaseDate = Date.now
        lastSeenDate = Date.now
        currencyCode = locale.currencyCode
    }
    
    public static func registerTipBoxSeen() {
        lastSeenDate = Date.now
    }
}

extension TipBox {
    public static func getStatus() -> String {
        return String(
            format: "TipBox [lastSeen: %@, lastPurchase: %@, total: %.2f %@]",
            lastSeenDate?.description ?? "nil",
            lastPurchaseDate?.description ?? "nil",
            totalAmount,
            currencyCode ?? ""
        )
    }
}
