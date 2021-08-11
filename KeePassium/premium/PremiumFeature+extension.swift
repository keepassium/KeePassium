//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
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
        case .canKeepMasterKeyOnDatabaseTimeout,
             .canChangeAppIcon,
             .canUseExpressUnlock,
             .canViewFieldReferences:
            return LString.premiumFeatureGenericDescription
        }
    }
}

extension LString {
    public static let premiumFeatureGenericTitle = NSLocalizedString(
        "[PremiumFeature/Generic/title]",
        value: "Premium Feature",
        comment: "A generic title of a premium feature")
    public static let premiumFeatureGenericDescription = NSLocalizedString(
        "[PremiumFeature/Generic/description]",
        value: "Upgrade to Premium and enjoy KeePassium at its best.",
        comment: "A generic description of a premium feature")
    
    public static let premiumFeatureMultipleDatabasesTitle = NSLocalizedString(
            "[PremiumFeature/MultiDB/title] Multiple Databases",
            value: "Multiple Databases",
            comment: "Title of a premium feature: ability to use multiple databases (In Title Case)")
    public static let premiumFeatureMultipleDatabasesDescription = NSLocalizedString(
        "[PremiumFeature/MultiDB/description] Easily switch between databases in the premium version.",
        value: "Easily switch between databases in the premium version.",
        comment: "Description/advertisement for the `Multiple Databases` premium feature")
    
    public static let premiumFeatureLongDatabaseTimeoutsTitle = NSLocalizedString(
            "[PremiumFeature/LongDBTimeouts/title] Long Database Timeouts",
            value: "Long Database Timeouts",
            comment: "Title of a premium feature: ability to set long delays in Database Lock Timeout settings (In Title Case)")
    public static let premiumFeatureLongDatabaseTimeoutsDescription = NSLocalizedString(
        "[PremiumFeature/LongDBTimeouts/description] Save time entering your complex master passwords — keep your database open longer in the premium version.",
        value: "Save time entering your complex master passwords — keep your database open longer in the premium version.",
        comment: "Description/advertisement for the `Long Database Timeouts` premium feature")
    
    public static let premiumFeaturePreviewAttachmentsTitle = NSLocalizedString(
            "[PremiumFeature/Preview/title] Preview Attachments",
            value: "Preview Attachments",
            comment: "Title of a premium feature: ability to preview some attached files directly in the app (In Title Case)")
    public static let premiumFeaturePreviewAttachmentsDescription =  NSLocalizedString(
        "[PremiumFeature/Preview/description] Preview images and documents directly in the app, in the premium version.",
        value: "Preview images and documents directly in the app, in the premium version.",
        comment: "Description/advertisement for the `Preview Attachments` premium feature")
    
    public static let premiumFeatureHardwareKeysTitle = NSLocalizedString(
            "[PremiumFeature/HardwareKeys/title] Hardware Keys",
            value: "Hardware Keys",
            comment: "Title of a premium feature: ability use hardware keys (e.g. YubiKey) for encryption (In Title Case)")
    public static let premiumFeatureHardwareKeysDescription = NSLocalizedString(
        "[PremiumFeature/HardwareKeys/description]",
        value: "Strengthen your security with hardware keys (YubiKey) in the premium version.",
        comment: "Description/advertisement for the `Hardware Keys` premium feature")
    
    public static let premiumFeatureChangeAppIconTitle = NSLocalizedString(
            "[PremiumFeature/CustomAppIcons/title]",
            value: "Custom App Icons",
            comment: "Title of a premium feature: ability to change the app icon")
}
