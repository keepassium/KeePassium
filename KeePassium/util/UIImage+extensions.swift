//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
    case externalLinkBadge = "external-link-badge"
    case moreActionsToolbar = "more-actions-toolbar"
    case sortOrderAscToolbar = "sort-order-asc-toolbar"
    case sortOrderDescToolbar = "sort-order-desc-toolbar"
    case databaseBackupListitem = "database-backup-listitem"
    case databaseTrashedListitem = "database-trashed-listitem"
    case filePreviewToolbar = "file-preview-toolbar"
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
    case premiumBenefitQuickAutoFill = "premium-benefit-quick-autofill"
    case premiumBenefitSupport = "premium-benefit-support"
    case premiumBenefitShiny = "premium-benefit-shiny"
    case premiumConditionCheckedListitem = "premium-condition-checked-listitem"
    case premiumConditionUncheckedListitem = "premium-condition-unchecked-listitem"
    case settingsAppLockListitem = "settings-app-lock-listitem"
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
    case arrowshapeTurnUpForward = "arrowshape.turn.up.forward" 
    case arrowLeftAndRight = "arrow.left.and.right" 
    case arrowRightCircle = "arrow.right.circle" 
    case asterisk = "asterisk" 
    case asteriskCircle = "asterisk.circle" 
    case bookClosed = "book.closed" 
    case camera = "camera" 
    case checkmark = "checkmark" 
    case checkmarkCircle = "checkmark.circle" 
    case chevronDown = "chevron.down" 
    case chevronForward = "chevron.forward" 
    case chevronUp = "chevron.up" 
    case clock = "clock" 
    case clockArrowCirclepath = "clock.arrow.circlepath" 
    case docOnDoc = "doc.on.doc" 
    case ellipsisCircle = "ellipsis.circle" 
    case exclamationMarkTriangle = "exclamationmark.triangle" 
    case folder = "folder" 
    case gearshape2 = "gearshape.2" 
    case heart = "heart" 
    case icloudSlash = "icloud.slash" 
    case infoCircle = "info.circle" 
    case megaphone = "megaphone" 
    case minus = "minus" 
    case network = "network" 
    case nosign = "nosign" 
    case paperclip = "paperclip" 
    case pencil = "pencil" 
    case photo = "photo" 
    case plus = "plus" 
    case qrcode = "qrcode" 
    case sliderVertical3 = "slider.vertical.3" 
    case squareAndPencil = "square.and.pencil" 
    case squareAndArrowDown = "square.and.arrow.down" 
    case squareAndArrowUp = "square.and.arrow.up" 
    case xmark = "xmark" 
    case xmarkCircle = "xmark.circle" 
    case textformat = "textformat" 
    case trash = "trash" 
    case wandAndStars = "wand.and.stars" 
    case wifiSlash = "wifi.slash" 
    case xmarkICloud = "xmark.icloud" 
}

extension UIImage {
    convenience init(asset: ImageAsset) {
        self.init(named: asset.rawValue)! 
    }
    
    static func get(_ systemImageName: SystemImageName) -> UIImage? {
        if let systemImage =  UIImage(systemName: systemImageName.rawValue) {
            return systemImage
        }
        let fallbackAssetImage = UIImage(named: systemImageName.rawValue)
        return fallbackAssetImage
    }
    
    static func kpIcon(forEntry entry: Entry, iconSet: DatabaseIconSet?=nil) -> UIImage? {
        if let entry2 = entry as? Entry2,
            let db2 = entry2.database as? Database2,
            let customIcon2 = db2.customIcons.first(where: { $0.uuid == entry2.customIconUUID }),
            let image = UIImage(data: customIcon2.data.asData)
        {
            return image.withGradientUnderlay()
        }
        let _iconSet = iconSet ?? Settings.current.databaseIconSet
        return _iconSet.getIcon(entry.iconID)
    }
    
    static func kpIcon(forGroup group: Group, iconSet: DatabaseIconSet?=nil) -> UIImage? {
        if let group2 = group as? Group2,
            let db2 = group2.database as? Database2,
            let customIcon2 = db2.customIcons.first(where: { $0.uuid == group2.customIconUUID }),
            let image = UIImage(data: customIcon2.data.asData)
        {
            return image.withGradientUnderlay()
        }
        let _iconSet = iconSet ?? Settings.current.databaseIconSet
        return _iconSet.getIcon(group.iconID)
    }
    
    func downscalingToSquare(maxSide: CGFloat) -> UIImage? {
        let targetSide: CGFloat
        if size.width > maxSide && size.height > maxSide {
            targetSide = maxSide
        } else {
            targetSide = min(size.width, size.height)
        }
        
        let targetSize = CGSize(width: targetSide, height: targetSide)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, self.scale)
        self.draw(in: CGRect(x: 0, y: 0, width: targetSide, height: targetSide))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resized
    }
    
    func withGradientUnderlay() -> UIImage? {
        guard #available(iOS 13, *) else {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        let colors = [
            CGColor(gray: 1.0, alpha: 0.2),
            CGColor(gray: 1.0, alpha: 0.05),
            CGColor(gray: 1.0, alpha: 0.0),
        ]
        guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceGray(),
                colors: colors as CFArray,
                locations: [0.0, 0.9, 1.0])
        else {
            return nil
        }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = max(size.width, size.height) / 2
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0.0,
            endCenter: center,
            endRadius: radius,
            options: CGGradientDrawingOptions.drawsBeforeStartLocation
        )

        self.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let composed = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return composed
    }
}
