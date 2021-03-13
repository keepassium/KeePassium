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
    case lockDatabaseToolbar = "lock-database-toolbar"
    case openURLCellAccessory = "open-url-cellaccessory"
    case fileInfoCellAccessory = "file-info-cellaccessory"
    case deleteItemListitem = "delete-item-listitem"
    case deleteItemToolbar = "delete-item-toolbar"
    case editItemListitem = "edit-item-listitem"
    case editItemToolbar = "edit-item-toolbar"
    case moreActionsToolbar = "more-actions-toolbar"
    case sortOrderAscToolbar = "sort-order-asc-toolbar"
    case sortOrderDescToolbar = "sort-order-desc-toolbar"
    case databaseBackupListitem = "database-backup-listitem"
    case databaseTrashedListitem = "database-trashed-listitem"
    case fileProviderGenericListitem = "fp-generic-listitem"
    case fileProviderOnMyIPadListitem = "fp-on-ipad-listitem"
    case fileProviderOnMyIPhoneListitem = "fp-on-iphone-listitem"
    case fileProviderOnMyIPhoneXListitem = "fp-on-iphonex-listitem"
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
    case premiumBenefitFieldReferences = "premium-benefit-field-references"
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

enum SystemImageName: String {
    case docOnDoc = "doc.on.doc"
    case ellipsisCircle = "ellipsis.circle"
    case pencil = "pencil"
    case squareAndPencil = "square.and.pencil"
    case squareAndArrowUp = "square.and.arrow.up"
    case trash = "trash"
    case qrcode = "qrcode"
}

extension UIImage {
    convenience init(asset: ImageAsset) {
        self.init(named: asset.rawValue)! 
    }
    
    static func get(_ systemImageName: SystemImageName) -> UIImage? {
        if #available(iOS 13, *) {
            return UIImage(systemName: systemImageName.rawValue)
        } else {
            return UIImage(named: systemImageName.rawValue)
        }
    }
    
    static func kpIcon(forEntry entry: Entry, iconSet: DatabaseIconSet?=nil) -> UIImage? {
        if let entry2 = entry as? Entry2,
            let db2 = entry2.database as? Database2,
            let customIcon2 = db2.customIcons[entry2.customIconUUID],
            let image = UIImage(data: customIcon2.data.asData) {
            return image
        }
        let _iconSet = iconSet ?? Settings.current.databaseIconSet
        return _iconSet.getIcon(entry.iconID)
    }
    
    static func kpIcon(forGroup group: Group, iconSet: DatabaseIconSet?=nil) -> UIImage? {
        if let group2 = group as? Group2,
            let db2 = group2.database as? Database2,
            let customIcon2 = db2.customIcons[group2.customIconUUID],
            let image = UIImage(data: customIcon2.data.asData) {
            return image
        }
        let _iconSet = iconSet ?? Settings.current.databaseIconSet
        return _iconSet.getIcon(group.iconID)
    }
}
