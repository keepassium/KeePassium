//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum PremiumFeature: Int {
    public static let all: [PremiumFeature] = [
        .canUseMultipleDatabases, 
        .canUseLongDatabaseTimeouts, 
        .canPreviewAttachments, 
        .canUseHardwareKeys,    
        .canKeepMasterKeyOnDatabaseTimeout, 
        .canChangeAppIcon,
    ]
    
    case canUseMultipleDatabases = 0

    case canUseLongDatabaseTimeouts = 2
    
    case canPreviewAttachments = 3
    
    case canUseHardwareKeys = 4
    
    case canKeepMasterKeyOnDatabaseTimeout = 5
    
    case canChangeAppIcon = 6
    
    public func isAvailable(in status: PremiumManager.Status) -> Bool {
        switch self {
        case .canUseMultipleDatabases:
            return status == .subscribed || status == .lapsed
        case .canUseLongDatabaseTimeouts:
            return status == .subscribed || status == .lapsed
        case .canPreviewAttachments:
            return status != .freeHeavyUse
        case .canUseHardwareKeys:
            return status == .subscribed || status == .lapsed
        case .canKeepMasterKeyOnDatabaseTimeout:
            return status == .subscribed || status == .lapsed
        case .canChangeAppIcon:
            return status == .subscribed || status == .lapsed
        }
    }
}
