//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum PasswordGeneratorMode: Int, Codable, CustomStringConvertible {
    case basic = 0
    case custom = 1
    case passphrase = 2
    
    public var description: String {
        switch self {
        case .basic:
            return LString.PasswordGeneratorMode.titleBasicMode
        case .custom:
            return LString.PasswordGeneratorMode.titleExpertMode
        case .passphrase:
            return LString.PasswordGeneratorMode.titlePassphraseMode
        }
    }
}

public extension LString {
    enum PasswordGeneratorMode {
        public static let title = NSLocalizedString(
            "[PasswordGenerator/Mode/title]",
            value: "Mode",
            comment: "Operation mode of the random text generator (for example, `Basic`, `Expert`, `Passphrase`)"
        )
        public static let titleBasicMode = NSLocalizedString(
            "[PasswordGenerator/Mode/Basic/title]",
            bundle: Bundle.framework,
            value: "Basic",
            comment: "One of the operation modes of the random text generator"
        )
        public static let titleExpertMode = NSLocalizedString(
            "[PasswordGenerator/Mode/Expert/title]",
            bundle: Bundle.framework,
            value: "Expert",
            comment: "One of the operation modes of the random text generator"
        )
        public static let titlePassphraseMode = NSLocalizedString(
            "[PasswordGenerator/Mode/Passphrase/title]",
            bundle: Bundle.framework,
            value: "Passphrase",
            comment: "One of the operation modes of the random text generator, where it generates random phrases."
        )
    }
}
