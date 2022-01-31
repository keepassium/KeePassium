//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
        case .canUseLongDatabaseTimeouts:
            return LString.premiumFeatureLongDatabaseTimeoutsTitle
        case .canPreviewAttachments:
            return LString.premiumFeaturePreviewAttachmentsTitle
        case .canUseHardwareKeys:
            return LString.premiumFeatureHardwareKeysTitle
        case .canKeepMasterKeyOnDatabaseTimeout:
            return LString.premiumFeatureGenericTitle
        case .canChangeAppIcon:
            return LString.premiumFeatureChangeAppIconTitle
        case .canRelocateAcrossDatabases:
            return LString.premiumFeatureGenericTitle
        case .canUseQuickTypeAutoFill:
            return LString.premiumFeatureQuickAutoFillTitle
        case .canUseExpressUnlock,
             .canViewFieldReferences:
            assertionFailure("Implicit feature, no upgrade notice required")
            return LString.premiumFeatureGenericTitle
        }
    }
    
    public var upgradeNoticeText: String {
        switch self {
        case .canUseMultipleDatabases:
            return LString.premiumFeatureMultipleDatabasesDescription
        case .canUseLongDatabaseTimeouts:
            return LString.premiumFeatureLongDatabaseTimeoutsDescription
        case .canPreviewAttachments:
            return LString.premiumFeaturePreviewAttachmentsDescription
        case .canUseHardwareKeys:
            return LString.premiumFeatureHardwareKeysDescription
        case .canUseQuickTypeAutoFill:
            return LString.premiumFeatureQuickAutoFillDescription
        case .canKeepMasterKeyOnDatabaseTimeout,
             .canChangeAppIcon,
             .canUseExpressUnlock,
             .canViewFieldReferences,
             .canRelocateAcrossDatabases:
            return LString.premiumFeatureGenericDescription
        }
    }
}
