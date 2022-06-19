//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension Settings {
    
    private static let lightUseDatabaseLockTimeout = DatabaseLockTimeout.after1hour
    
    var premiumDatabaseLockTimeout: Settings.DatabaseLockTimeout {
        let actualTimeout = Settings.current.databaseLockTimeout
        switch PremiumManager.shared.status {
        case .initialGracePeriod,
             .freeLightUse,
             .freeHeavyUse:
            return min(actualTimeout, Settings.lightUseDatabaseLockTimeout)
        case .subscribed,
             .lapsed,
             .fallback:
            return actualTimeout
        }
    }
    
    var premiumIsKeepKeyFileAssociations: Bool {
        return isKeepKeyFileAssociations
    }
    
    var premiumIsLockDatabasesOnTimeout: Bool {
        let actualValue = Settings.current.isLockDatabasesOnTimeout
        if PremiumManager.shared.isAvailable(feature: .canKeepMasterKeyOnDatabaseTimeout) {
            return actualValue
        } else {
            return true
        }
    }
    
    var premiumIsQuickTypeEnabled: Bool {
        let actualValue = Settings.current.isQuickTypeEnabled
        if PremiumManager.shared.isAvailable(feature: .canUseQuickTypeAutoFill) {
            return actualValue
        } else {
            return false
        }
    }
    
    func isAvailable(timeout: Settings.DatabaseLockTimeout, for status: PremiumManager.Status) -> Bool {
        switch status {
        case .initialGracePeriod,
             .freeLightUse,
             .freeHeavyUse:
            return timeout <= Settings.lightUseDatabaseLockTimeout
        case .subscribed,
             .lapsed,
             .fallback:
            return true
        }
    }
    
    func isShownAvailable(timeout: Settings.DatabaseLockTimeout, for status: PremiumManager.Status) -> Bool {
        switch status {
        case .initialGracePeriod,
             .freeLightUse,
             .freeHeavyUse:
            return timeout <= Settings.lightUseDatabaseLockTimeout
        case .subscribed,
             .lapsed,
             .fallback:
            return true
        }
    }
}
