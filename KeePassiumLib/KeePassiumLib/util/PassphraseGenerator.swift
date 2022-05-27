//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class PassphraseGenerator: PasswordGenerator {
    public enum WordCase: Int, Codable, CaseIterable, CustomStringConvertible {
        case lowerCase = 0
        case upperCase = 1
        case titleCase = 2
        public var description: String {
            switch self {
            case .lowerCase:
                return LString.PasswordGenerator.WordCase.lowerCase
            case .upperCase:
                return LString.PasswordGenerator.WordCase.upperCase
            case .titleCase:
                return LString.PasswordGenerator.WordCase.titleCase
            }
        }
    }

    var separator: String = " "
    var wordCase: WordCase = .lowerCase
}

extension LString.PasswordGenerator {
    public enum WordCase {
        public static let title = NSLocalizedString(
            "[PasswordGenerator/WordCase/title]",
            bundle: Bundle.framework,
            value: "Case",
            comment: "Case of letters in a word (e.g. UPPER, lower, Title Case)")
        public static let upperCase = NSLocalizedString(
            "[PasswordGenerator/WordCase/upperCase]",
            bundle: Bundle.framework,
            value: "UPPERCASE",
            comment: "Word capitalization style. Written in that style, if possible.")
        public static let lowerCase = NSLocalizedString(
            "[PasswordGenerator/WordCase/lowerCase]",
            bundle: Bundle.framework,
            value: "lowercase",
            comment: "Word capitalization style. Written in that style, if possible.")
        public static let titleCase = NSLocalizedString(
            "[PasswordGenerator/WordCase/titleCase]",
            bundle: Bundle.framework,
            value: "Title Case",
            comment: "Word capitalization style: first letters of significant words capitalized. Written in that style, if possible.")
    }
}
