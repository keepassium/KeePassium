//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension Settings {
    
    private static let heavyUseDatabaseLockTimeout = DatabaseLockTimeout.after5minutes
    private static let lightUseDatabaseLockTimeout = DatabaseLockTimeout.after1hour
    
    var premiumDatabaseLockTimeout: Settings.DatabaseLockTimeout {
        let actualTimeout = Settings.current.databaseLockTimeout
        switch PremiumManager.shared.status {
        case .initialGracePeriod,
             .freeLightUse:
            return min(actualTimeout, Settings.lightUseDatabaseLockTimeout)
        case .freeHeavyUse:
            return min(actualTimeout, Settings.heavyUseDatabaseLockTimeout)
        case .subscribed,
             .lapsed:
            return actualTimeout
        }
    }
    
    var premiumIsBiometricAppLockEnabled: Bool {
        return isBiometricAppLockEnabled
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
    
    func isAvailable(timeout: Settings.DatabaseLockTimeout, for status: PremiumManager.Status) -> Bool {
        switch status {
        case .initialGracePeriod,
             .freeLightUse:
            return timeout <= Settings.lightUseDatabaseLockTimeout
        case .freeHeavyUse:
            return timeout <= Settings.heavyUseDatabaseLockTimeout && timeout != .never
        case .subscribed,
             .lapsed:
            return true
        }
    }
    
    func isShownAvailable(timeout: Settings.DatabaseLockTimeout, for status: PremiumManager.Status) -> Bool {
        switch status {
        case .initialGracePeriod,
             .freeLightUse:
            return timeout <= Settings.lightUseDatabaseLockTimeout && timeout != .never
        case .freeHeavyUse:
            return timeout <= Settings.heavyUseDatabaseLockTimeout && timeout != .never
        case .subscribed,
             .lapsed:
            return true
        }
    }
}
