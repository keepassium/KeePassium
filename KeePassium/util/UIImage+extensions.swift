//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

enum ImageAsset: String {
    case lockCover = "app-cover"
    case appCoverPattern = "app-cover-pattern"
    case backgroundPattern = "background-pattern"
    case createItemToolbar = "create-item-toolbar"
    case editItemToolbar = "edit-item-toolbar"
    case lockDatabaseToolbar = "lock-database-toolbar"
    case openURLCellAccessory = "open-url-cellaccessory"
    case fileInfoCellAccessory = "file-info-cellaccessory"
    case deleteItemListitem = "delete-item-listitem"
    case editItemListitem = "rename-item-listitem"
    case sortOrderAscToolbar = "sort-order-asc-toolbar"
    case sortOrderDescToolbar = "sort-order-desc-toolbar"
    case databaseBackupListitem = "database-backup-listitem"
    case databaseTrashedListitem = "database-trashed-listitem"
    case fileProviderGenericListitem = "fp-generic-listitem"
    case fileProviderOnMyIPadListitem = "fp-on-ipad-listitem"
    case fileProviderOnMyIPhoneListitem = "fp-on-iphone-listitem"
    case keyFileListitem = "keyfile-listitem"
    case hideAccessory = "hide-accessory"
    case unhideAccessory = "unhide-accessory"
    case hideListitem = "hide-listitem"
    case unhideListitem = "unhide-listitem"
    case biometryTouchIDListitem = "touch-id-listitem"
    case biometryFaceIDListitem = "face-id-listitem"
    case premiumFeatureBadge = "premium-feature-badge"
    case premiumBenefitMultiDB = "premium-benefit-multidb"
    case premiumBenefitDBTimeout = "premium-benefit-db-timeout"
    case premiumBenefitPreview = "premium-benefit-preview"
    case premiumBenefitHardwareKeys = "premium-benefit-yubikey"
    case premiumBenefitCustomAppIcons = "premium-benefit-custom-appicons"
    case premiumBenefitSupport = "premium-benefit-support"
    case premiumBenefitShiny = "premium-benefit-shiny"
    case premiumConditionCheckedListitem = "premium-condition-checked-listitem"
    case premiumConditionUncheckedListitem = "premium-condition-unchecked-listitem"
    case expandRowCellAccessory = "expand-row-cellaccessory"
    case collapseRowCellAccessory = "collapse-row-cellaccessory"
    case viewMoreAccessory = "view-more-accessory"
    case yubikeyOnAccessory = "yubikey-on-accessory"
    case yubikeyOffAccessory = "yubikey-off-accessory"
    case yubikeyMFIPhoneNew = "yubikey-mfi-phone-new"
    case yubikeyMFIPhone = "yubikey-mfi-phone"
    case yubikeyMFIKey = "yubikey-mfi-key"
}

extension UIImage {
    convenience init(asset: ImageAsset) {
        self.init(named: asset.rawValue)! 
    }
    
    static func kpIcon(forID iconID: IconID) -> UIImage? {
        return UIImage(named: String(format: "db-icons/kpbIcon%02d", iconID.rawValue))
    }
    
    static func kpIcon(forEntry entry: Entry) -> UIImage? {
        if let entry2 = entry as? Entry2,
            let db2 = entry2.database as? Database2,
            let customIcon2 = db2.customIcons[entry2.customIconUUID],
            let image = UIImage(data: customIcon2.data.asData) {
            return image
        }
        return kpIcon(forID: entry.iconID)
    }
    
    static func kpIcon(forGroup group: Group) -> UIImage? {
        if let group2 = group as? Group2,
            let db2 = group2.database as? Database2,
            let customIcon2 = db2.customIcons[group2.customIconUUID],
            let image = UIImage(data: customIcon2.data.asData) {
            return image
        }
        return kpIcon(forID: group.iconID)
    }
    
}
