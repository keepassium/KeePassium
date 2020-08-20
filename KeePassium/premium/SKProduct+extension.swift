//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import StoreKit
import UIKit

extension SKProduct {
    
    var localizedPrice: String {
        return SKProduct.localizePrice(price: price, locale: priceLocale)
    }
    
    public static func localizePrice(price: NSDecimalNumber, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        return formatter.string(from: price) ?? String(format: "%.2f", price)
    }
    
    var localizedTrialDuration: String? {
        guard #available(iOS 11.2, *),
            let period = introductoryPrice?.subscriptionPeriod else { return nil }

        var dateComponents = DateComponents()
        let timeFormatter = DateComponentsFormatter()
        switch period.unit {
        case .day:
            dateComponents.setValue(period.numberOfUnits, for: .day)
            timeFormatter.allowedUnits = [.day]
        case .week:
            dateComponents.setValue(7 * period.numberOfUnits, for: .day)
            timeFormatter.allowedUnits = [.day]
        case .month:
            dateComponents.setValue(period.numberOfUnits, for: .month)
            timeFormatter.allowedUnits = [.month]
        case .year:
            dateComponents.setValue(period.numberOfUnits, for: .year)
            timeFormatter.allowedUnits = [.year]
        @unknown default:
            assertionFailure()
            return nil 
        }
        
        timeFormatter.unitsStyle = .full
        timeFormatter.maximumUnitCount = 1
        timeFormatter.formattingContext = .beginningOfSentence 
        timeFormatter.zeroFormattingBehavior = .dropAll
        return timeFormatter.string(from: dateComponents)
    }
}
