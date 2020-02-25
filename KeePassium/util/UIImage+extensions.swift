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
    case deleteItemListitem = "delete-item-listitem"
    case editItemListitem = "rename-item-listitem"
    case databaseCloudListitem = "database-cloud-listitem"
    case databaseLocalListitem = "database-local-listitem"
    case databaseBackupListitem = "database-backup-listitem"
    case databaseErrorListitem = "database-error-listitem"
    case hideAccessory = "hide-accessory"
    case unhideAccessory = "unhide-accessory"
    case hideListitem = "hide-listitem"
    case unhideListitem = "unhide-listitem"
    case copyToClipboardAccessory = "copy-to-clipboard-accessory"
    case biometryTouchIDListitem = "touch-id-listitem"
    case biometryFaceIDListitem = "face-id-listitem"
    case premiumBenefitMultiDB = "premium-benefit-multidb"
    case premiumBenefitDBTimeout = "premium-benefit-db-timeout"
    case premiumBenefitPreview = "premium-benefit-preview"
    case premiumBenefitHardwareKeys = "premium-benefit-yubikey"
    case premiumBenefitSupport = "premium-benefit-support"
    case premiumBenefitShiny = "premium-benefit-shiny"
    case expandRowCellAccessory = "expand-row-cellaccessory"
    case collapseRowCellAccessory = "collapse-row-cellaccessory"
    case yubikeyOnAccessory = "yubikey-on-accessory"
    case yubikeyOffAccessory = "yubikey-off-accessory"
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
    
    static func databaseIcon(for urlRef: URLReference) -> UIImage {
        guard !urlRef.info.hasError else {
            return UIImage(asset: .databaseErrorListitem)
        }
        switch urlRef.location {
        case .external:
            return UIImage(asset: .databaseCloudListitem)
        case .internalDocuments, .internalInbox:
            return UIImage(asset: .databaseLocalListitem)
        case .internalBackup:
            return UIImage(asset: .databaseBackupListitem)
        }
    }
}
