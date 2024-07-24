//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension PremiumFeature {

    public var titleName: String {
        switch self {
        case .canUseMultipleDatabases:
            return LString.premiumFeatureMultipleDatabasesTitle
        case .canUseHardwareKeys:
            return LString.premiumFeatureHardwareKeysTitle
        case .canRelocateAcrossDatabases:
            return LString.premiumFeatureGenericTitle
        case .canUseQuickTypeAutoFill:
            return LString.premiumFeatureQuickAutoFillTitle
        case .canUseBusinessClouds:
            return LString.premiumFeatureBusinessCloudsTitle
        case .canAuditPasswords:
            return LString.premiumFeaturePasswordAuditTitle
        case .canOpenLinkedDatabases:
            return LString.premiumFeatureLinkedDatabasesTitle
        }
    }

    public var upgradeNoticeText: String {
        switch self {
        case .canUseMultipleDatabases:
            return LString.premiumFeatureMultipleDatabasesDescription
        case .canUseHardwareKeys:
            return LString.premiumFeatureHardwareKeysDescription
        case .canUseQuickTypeAutoFill:
            return LString.premiumFeatureQuickAutoFillDescription
        case .canUseBusinessClouds:
            return LString.premiumFeatureBusinessCloudsDescription
        case .canAuditPasswords:
            return LString.premiumFeaturePasswordAuditDescription
        case .canOpenLinkedDatabases:
            return LString.premiumFeatureLinkedDatabasesDescription
        case .canRelocateAcrossDatabases:
            return LString.premiumFeatureGenericDescription
        }
    }
}
