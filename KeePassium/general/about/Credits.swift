//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib

struct Credits {
    enum License {
        case mit
        case gpl
        case lgpl
        case proprietary
        case publicDomain
        case apache2
        case ccBy3
        case ccByNd3
        case cc0
        case customPermissiveLicense

        var title: String {
            switch self {
            case .mit:
                return LString.mitLicenseTitle
            case .gpl:
                return LString.gplLicenseTitle
            case .lgpl:
                return LString.lgplLicenseTitle
            case .proprietary:
                return LString.proprietaryLicenseTitle
            case .publicDomain:
                return LString.publicDomainLicenseTitle
            case .apache2:
                return LString.apache2LicenseTitle
            case .ccBy3:
                return LString.ccBy3LicenseTitle
            case .ccByNd3:
                return LString.ccByNd3LicenseTitle
            case .cc0:
                return LString.cc0LicenseTitle
            case .customPermissiveLicense:
                return LString.customPermissiveLicenseTitle
            }
        }
    }

    let title: String
    let license: License
    let url: URL?
}

extension Credits {
    static var all: [Credits] {
        return [
            Credits(
                title: LString.creditsTranslations,
                license: .mit,
                url: URL(string: "https://github.com/keepassium/KeePassium-L10n")
            ),
            Credits(
                title: LString.creditsKeePass,
                license: .gpl,
                url: URL(string: "https://keepass.info")
            ),
            Credits(
                title: LString.creditsFeatherIcons,
                license: .mit,
                url: URL(string: "https://feathericons.com")
            ),
            Credits(
                title: LString.creditsIonIcons,
                license: .mit,
                url: URL(string: "http://ionicons.com")
            ),
            Credits(
                title: LString.creditsLineIcons,
                license: .ccByNd3,
                url: URL(string: "https://designmodo.com/linecons-free/")
            ),
            Credits(
                title: LString.creditsIcons8,
                license: .proprietary,
                url: URL(string: "https://icons8.com/paid-license-99")
            ),
            Credits(
                title: LString.creditsNuvolaIcons,
                license: .lgpl,
                url: URL(string: "https://en.wikipedia.org/wiki/Nuvola")
            ),
            Credits(
                title: LString.creditsKeePassXCIcons,
                license: .mit,
                url: URL(string: "https://github.com/keepassxreboot/keepassxc/pull/4699")
            ),
            Credits(
                title: LString.creditsFancyDebossPattern,
                license: .ccBy3,
                url: URL(string: "http://subtlepatterns.com")
            ),
            Credits(
                title: LString.creditsSystemSettingsIcon,
                license: .ccBy3,
                url: URL(string: "http://vicons.superatic.com")
            ),
            Credits(
                title: LString.creditsAEXML,
                license: .mit,
                url: URL(string: "https://github.com/tadija/AEXML")
            ),
            Credits(
                title: LString.creditsRijndael,
                license: .publicDomain,
                url: nil
            ),
            Credits(
                title: LString.creditsArgon2,
                license: .cc0,
                url: URL(string: "https://github.com/P-H-C/phc-winner-argon2")
            ),
            Credits(
                title: LString.creditsChaCha20,
                license: .publicDomain,
                url: URL(string: "https://cr.yp.to/salsa20.html")
            ),
            Credits(
                title: LString.creditsTwoFish,
                license: .customPermissiveLicense,
                url: URL(string: "http://www.cartotype.com/downloads/twofish/twofish.cpp")
            ),
            Credits(
                title: LString.creditsYubico,
                license: .apache2,
                url: URL(string: "https://github.com/Yubico/yubikit-ios")
            ),
            Credits(
                title: LString.creditsTPInAppReceipt,
                license: .mit,
                url: URL(string: "https://github.com/tikhop/TPInAppReceipt")
            ),
            Credits(
                title: LString.creditsSwiftDomainParser,
                license: .mit,
                url: URL(string: "https://github.com/Dashlane/SwiftDomainParser")
            ),
            Credits(
                title: LString.creditsGzipSwift,
                license: .mit,
                url: URL(string: "https://github.com/1024jp/GzipSwift")
            ),
            Credits(
                title: LString.creditsBase32,
                license: .mit,
                url: URL(string: "https://github.com/norio-nomura/Base32")
            ),
            Credits(
                title: LString.creditsToastSwift,
                license: .mit,
                url: URL(string: "https://github.com/scalessec/Toast-Swift")
            ),
            Credits(
                title: LString.creditsZxcvbn,
                license: .mit,
                url: URL(string: "https://github.com/dropbox/zxcvbn-ios")
            ),
            Credits(
                title: LString.creditsWordlists,
                license: .ccBy3,
                url: URL(string: "https://eff.org/dice")
            )
        ]
    }
}

extension LString {
    public static let mitLicenseTitle = NSLocalizedString(
        "[Credits/License/mit]",
        bundle: Bundle.main,
        value: "MIT license",
        comment: "License name for credits"
    )
    public static let gplLicenseTitle = NSLocalizedString(
        "[Credits/License/gpl]",
        bundle: Bundle.main,
        value: "GPL license",
        comment: "License name for credits"
    )
    public static let lgplLicenseTitle = NSLocalizedString(
        "[Credits/License/lgpl]",
        bundle: Bundle.main,
        value: "LGPL license",
        comment: "License name for credits"
    )
    public static let proprietaryLicenseTitle = NSLocalizedString(
        "[Credits/License/proprietary]",
        bundle: Bundle.main,
        value: "Proprietary license",
        comment: "License name for credits"
    )
    public static let publicDomainLicenseTitle = NSLocalizedString(
        "[Credits/License/publicDomain]",
        bundle: Bundle.main,
        value: "Public Domain",
        comment: "License name for credits"
    )
    public static let apache2LicenseTitle = NSLocalizedString(
        "[Credits/License/apache2]",
        bundle: Bundle.main,
        value: "Apache 2.0 license",
        comment: "License name for credits"
    )
    public static let ccBy3LicenseTitle = NSLocalizedString(
        "[Credits/License/ccBy3]",
        bundle: Bundle.main,
        value: "CC BY 3.0",
        comment: "License name for credits"
    )
    public static let ccByNd3LicenseTitle = NSLocalizedString(
        "[Credits/License/ccByNd]",
        bundle: Bundle.main,
        value: "CC BY-ND 3.0",
        comment: "License name for credits"
    )
    public static let cc0LicenseTitle = NSLocalizedString(
        "[Credits/License/cc0]",
        bundle: Bundle.main,
        value: "CC0 license",
        comment: "License name for credits"
    )
    public static let customPermissiveLicenseTitle = NSLocalizedString(
        "[Credits/License/customPermissiveLicense]",
        bundle: Bundle.main,
        value: "Custom permissive license",
        comment: "License name for credits"
    )
    public static let creditsTranslations = NSLocalizedString(
        "[Credits/Item/translations]",
        bundle: Bundle.main,
        value: "Translation by KeePassium contributors",
        comment: "Item in the credits list"
    )
    public static let creditsKeePass = NSLocalizedString(
        "[Credits/Item/keePass]",
        bundle: Bundle.main,
        value: "KeePass by Dominik Reichl",
        comment: "Item in the credits list"
    )
    public static let creditsFeatherIcons = NSLocalizedString(
        "[Credits/Item/featherIcons]",
        bundle: Bundle.main,
        value: "Feather icons by Cole Bemis",
        comment: "Item in the credits list"
    )
    public static let creditsIonIcons = NSLocalizedString(
        "[Credits/Item/ionIcons]",
        bundle: Bundle.main,
        value: "Ionicons by Ionic",
        comment: "Item in the credits list"
    )
    public static let creditsLineIcons = NSLocalizedString(
        "[Credits/Item/lineIcons]",
        bundle: Bundle.main,
        value: "Linecons by Andrian Valeanu",
        comment: "Item in the credits list"
    )
    public static let creditsIcons8 = NSLocalizedString(
        "[Credits/Item/icons8]",
        bundle: Bundle.main,
        value: "Icons by Icons8",
        comment: "Item in the credits list"
    )
    public static let creditsNuvolaIcons = NSLocalizedString(
        "[Credits/Item/nuvolaIcons]",
        bundle: Bundle.main,
        value: "Nuvola icons by David Vignoni",
        comment: "Item in the credits list"
    )
    public static let creditsKeePassXCIcons = NSLocalizedString(
        "[Credits/Item/keePassXCIcons]",
        bundle: Bundle.main,
        value: "Icons by KeePassXC team",
        comment: "Item in the credits list"
    )
    public static let creditsFancyDebossPattern = NSLocalizedString(
        "[Credits/Item/fancyDebossPattern]",
        bundle: Bundle.main,
        value: "Fancy deboss pattern by Daniel Beaton",
        comment: "Item in the credits list"
    )
    public static let creditsSystemSettingsIcon = NSLocalizedString(
        "[Credits/Item/systemSettingsIcon]",
        bundle: Bundle.main,
        value: "System settings icon by Vicons Design",
        comment: "Item in the credits list"
    )
    public static let creditsAEXML = NSLocalizedString(
        "[Credits/Item/aexml]",
        bundle: Bundle.main,
        value: "AEXML by Marko Tadić",
        comment: "Item in the credits list"
    )
    public static let creditsRijndael = NSLocalizedString(
        "[Credits/Item/rijndael]",
        bundle: Bundle.main,
        value: "Rijndael implementation by Szymon Stefanek",
        comment: "Item in the credits list"
    )
    public static let creditsArgon2 = NSLocalizedString(
        "[Credits/Item/argon2]",
        bundle: Bundle.main,
        value: "Argon2 by Daniel Dinu, Dmitry Khovratovich, Jean-Philippe Aumasson, and Samuel Neves",
        comment: "Item in the credits list"
    )
    public static let creditsChaCha20 = NSLocalizedString(
        "[Credits/Item/chaCha20]",
        bundle: Bundle.main,
        value: "ChaCha20 & Salsa20 implementation by D. J. Bernstein",
        comment: "Item in the credits list"
    )
    public static let creditsTwoFish = NSLocalizedString(
        "[Credits/Item/twoFish]",
        bundle: Bundle.main,
        value: "Twofish implementation by Niels Ferguson",
        comment: "Item in the credits list"
    )
    public static let creditsYubico = NSLocalizedString(
        "[Credits/Item/yubico]",
        bundle: Bundle.main,
        value: "Yubico Mobile iOS SDK by Yubico AB",
        comment: "Item in the credits list"
    )
    public static let creditsTPInAppReceipt = NSLocalizedString(
        "[Credits/Item/tpInappReceipt]",
        bundle: Bundle.main,
        value: "TPInAppReceipt by Pavel Tikhonenko",
        comment: "Item in the credits list"
    )
    public static let creditsSwiftDomainParser = NSLocalizedString(
        "[Credits/Item/swiftDomainParser]",
        bundle: Bundle.main,
        value: "SwiftDomainParser by Dashlane",
        comment: "Item in the credits list"
    )
    public static let creditsGzipSwift = NSLocalizedString(
        "[Credits/Item/gzipSwift]",
        bundle: Bundle.main,
        value: "GzipSwift by 1024jp",
        comment: "Item in the credits list"
    )
    public static let creditsBase32 = NSLocalizedString(
        "[Credits/Item/base32]",
        bundle: Bundle.main,
        value: "Base32 for Swift by Norio Nomura",
        comment: "Item in the credits list"
    )
    public static let creditsToastSwift = NSLocalizedString(
        "[Credits/Item/toastSwift]",
        bundle: Bundle.main,
        value: "Toast-Swift by Charles Scalesse",
        comment: "Item in the credits list"
    )
    public static let creditsZxcvbn = NSLocalizedString(
        "[Credits/Item/zxcvbn]",
        bundle: Bundle.main,
        value: "zxcvbn-ios by Dropbox",
        comment: "Item in the credits list"
    )
    public static let creditsWordlists = NSLocalizedString(
        "[Credits/Item/wordlists]",
        bundle: Bundle.main,
        value: "Passphrase wordlists by EFF",
        comment: "Item in the credits list"
    )
}
