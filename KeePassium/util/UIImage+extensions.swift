//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

enum ImageAsset: String {
    case appCoverPattern = "app-cover-pattern" 
    case backgroundPattern = "background-pattern" 

    case yubikeyMFIPhoneNew = "yubikey-mfi-phone-new"
    case yubikeyMFIPhone = "yubikey-mfi-phone"
    case yubikeyMFIKey = "yubikey-mfi-key"

    public func asColor() -> UIColor? {
        return UIColor(patternImage: UIImage(asset: self))
    }
}

public enum SymbolName: String {
    public static let keyFile = Self.keyDocHorizontal
    public static let actionRestore = Self.clockArrowCirclepath
    public static let appProtection = Self.lock
    public static let autoFill = Self.return
    public static let fieldReference = Self.arrowRightCircle
    public static let largeType = Self.characterMagnify
    public static let passwordAudit = Self.networkBadgeShield
    public static let managedParameter = Self.person2BadgeGearshape

    public static let premiumBenefitMultiDB = Self.shieldBadgePlus
    public static let premiumBenefitDBTimeout = Self.clockBadgeCheckmark
    public static let premiumBenefitHardwareKeys = Self.usbDongle
    public static let premiumBenefitFieldReferences = Self.arrowshapeTurnUpForwardCircle
    public static let premiumBenefitQuickAutoFill = Self.bolt
    public static let premiumBenefitBusinessClouds = Self.briefcase
    public static let premiumBenefitPasswordAudit = Self.networkBadgeShield
    public static let premiumBenefitLinkedDatabases = Self.squareOnSquare
    public static let premiumBenefitSupport = Self.questionmarkBubble
    public static let premiumBenefitShiny = Self.faceSmiling

    case onboardingLogo = "onboarding-logo"
    case onboardingDataProtection = "onboarding-data-protection"
    case onboardingVault = "onboarding-vault"
    case onboardingPIN = "onboarding-pin"
    case onboardingFaceID = "onboarding-faceid"
    case onboardingTouchID = "onboarding-touchid"
    case onboardingOpticID = "onboarding-opticid"
    case onboardingAutoFill = "onboarding-autofill"

    case antCircle = "ant.circle"
    case arrowLeftAndRight = "arrow.left.and.right"
    case arrowRightCircle = "arrow.right.circle"
    case arrowshapeTurnUpForward = "arrowshape.turn.up.forward"
    case arrowshapeTurnUpForwardCircle = "arrowshape.turn.up.forward.circle"
    case arrowUpArrowDown = "arrow.up.arrow.down"
    case arrowUpCircleFill = "arrow.up.circle.fill"
    case asterisk = "asterisk"
    case bellSlash = "bell.slash"
    case bolt = "bolt"
    case bookClosed = "book.closed"
    case briefcase = "briefcase"
    case camera = "camera"
    case characterMagnify = "character.magnify"
    case checkmark = "checkmark"
    case checkmarkCircle = "checkmark.circle"
    case checkmarkSeal = "checkmark.seal"
    case chevronDown = "chevron.down"
    case chevronForward = "chevron.forward"
    case chevronUp = "chevron.up"
    case clock = "clock"
    case clockArrowCirclepath = "clock.arrow.circlepath"
    case clockBadgeCheckmark = "clock.badge.checkmark"
    case clockShield = "clock.shield"
    case dieFace3 = "die.face.3"
    case docOnDoc = "doc.on.doc"
    case docBadgePlus = "doc.badge.plus"
    case docTextMagnifyingGlass = "doc.text.magnifyingglass"
    case ellipsis = "ellipsis"
    case ellipsisCircle = "ellipsis.circle"
    case externalLink = "external-link" 
    case exclamationMarkOctagonFill = "exclamationmark.octagon.fill"
    case exclamationMarkTriangle = "exclamationmark.triangle" 
    case exclamationMarkTriangleFill = "exclamationmark.triangle.fill"
    case eye = "eye"
    case eyeFill = "eye.fill"
    case faceID = "faceid"
    case faceSmiling = "face.smiling"
    case folder = "folder"
    case folderBadgePlus = "folder.badge.plus"
    case folderGridBadgePlus = "square.grid.3x1.folder.badge.plus"
    case gear = "gear"
    case gearshape2 = "gearshape.2"
    case globe = "globe"
    case heart = "heart"
    case iCloud = "icloud"
    case iCloudSlash = "icloud.slash"
    case infoCircle = "info.circle"
    case infoCircleFill = "info.circle.fill"
    case iPad = "ipad"
    case iPadHomeButton = "ipad.homebutton"
    case iPhone = "iphone"
    case iPhoneHomeButton = "iphone.homebutton"
    case key = "key.diagonal"
    case keyDoc = "key.doc"
    case keyDocHorizontal = "key.doc.horizontal"
    case keyHorizontal = "key.horizontal"
    case keyboard = "keyboard"
    case listBullet = "list.bullet"
    case link = "link"
    case lock = "lock"
    case lockShield = "lock.shield"
    case minus = "minus"
    case network = "network"
    case networkBadgeShield = "network.badge.shield"
    case nosign = "nosign"
    case noteText = "note.text"
    case paperclip = "paperclip"
    case paperclipBadgeEllipsis = "paperclip.badge.ellipsis"
    case pencil = "pencil"
    case person = "person"
    case person2BadgeGearshape = "person.2.badge.gearshape"
    case person3 = "person.3"
    case photo = "photo"
    case plus = "plus"
    case plusCircleFill = "plus.circle.fill"
    case plusSquareOnSquare = "plus.square.on.square"
    case printer = "printer"
    case qrcode = "qrcode"
    case questionmarkBubble = "questionmark.bubble"
    case rectangleStack = "rectangle.stack"
    case `return` = "return"
    case shieldBadgePlus = "shield.badge.plus"
    case sliderVertical3 = "slider.vertical.3"
    case starFill = "star.fill"
    case squareAndPencil = "square.and.pencil"
    case squareAndArrowDown = "square.and.arrow.down"
    case squareAndArrowUp = "square.and.arrow.up"
    case squareOnSquare = "square.on.square"
    case textformat = "textformat"
    case touchID = "touchid"
    case trash = "trash"
    case trashBadgeClock = "trash.badge.clock"
    case usbDongle = "usb.dongle"
    case wandAndStars = "wand.and.stars"
    case wifiSlash = "wifi.slash"
    case xmark = "xmark"
    case xmarkICloud = "xmark.icloud"

    case fileProviderBox = "fp.box" 
    case fileProviderBoxCryptor = "fp.boxcryptor" 
    case fileProviderDropbox = "fp.dropbox" 
    case fileProviderGeneric = "fp.generic" 
    case fileProviderGoogleDrive = "fp.googledrive" 
    case fileProviderNAS = "fp.nas" 
    case fileProviderNextCloud = "fp.nextcloud" 
    case fileProviderOneDrive = "fp.onedrive" 
    case fileProviderOwnCloud = "fp.owncloud" 
    case fileProviderPCloud = "fp.pcloud" 
    case fileProviderSMB = "fp.smb" 
    case fileProviderSynologyDrive = "fp.synologydrive" 
    case fileProviderUSB = "fp.user" 
    case fileProviderWebDAV = "fp.webdav" 
}

extension UIImage {
    static var premiumBadge: UIImage? {
        UIImage.symbol(.starFill)?
            .applyingSymbolConfiguration(UIImage.SymbolConfiguration(scale: .large))?
            .withTintColor(.systemYellow, renderingMode: .alwaysOriginal)
    }
}

extension UIImage {

    public static func symbol(
        _ symbolName: SymbolName?,
        tint: UIColor? = nil,
        accessibilityLabel: String? = nil
    ) -> UIImage? {
        guard let symbolName else {
            return nil
        }

        var result = UIImage(named: symbolName.rawValue)
            ?? UIImage(systemName: symbolName.rawValue)

        if let tint {
            result = result?.withTintColor(tint, renderingMode: .alwaysOriginal)
        }
        if let accessibilityLabel {
            result?.accessibilityLabel = accessibilityLabel
        }
        return result
    }

    convenience init(asset: ImageAsset) {
        self.init(named: asset.rawValue)! 
    }

    static func kpIcon(forEntry entry: Entry, iconSet: DatabaseIconSet? = nil) -> UIImage? {
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

    static func kpIcon(forGroup group: Group, iconSet: DatabaseIconSet? = nil) -> UIImage? {
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

    func withGradientUnderlay() -> UIImage? {
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
