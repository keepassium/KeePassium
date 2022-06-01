//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension LString {
    enum PasswordGenerator {
        public static let titleRandomGenerator = NSLocalizedString(
            "[PasswordGenerator/title]",
            bundle: Bundle.framework,
            value: "Random Generator",
            comment: "Title of the random text/password/username generator dialog.")
        
        public static let editMenuTitle = "🎲"

        public static let actionGenerate = NSLocalizedString(
            "[PasswordGenerator/Generate/action]",
            bundle: Bundle.framework,
            value: "Generate",
            comment: "Action/button: generate random text/password/phrase")
        
        public static let titleGeneratedText = NSLocalizedString(
            "[PasswordGenerator/GeneratedText/title]",
            bundle: Bundle.framework,
            value: "Generated text",
            comment: "Description of randomly generated text/password/phrase")

        public static let titleCustomCharacters = NSLocalizedString(
            "[PasswordGenerator/CustomSet/title]",
            bundle: Bundle.framework,
            value: "Custom characters",
            comment: "User-defined set of characters for password generator."
        )

        public static let titleCustomSetEmpty = NSLocalizedString(
            "[PasswordGenerator/CustomSet/Empty/title]",
            bundle: Bundle.framework,
            value: "Empty",
            comment: "Description of an empty character set for password generator. 'Empty' as 'there are no characters'."
        )

        public static let titleLength = NSLocalizedString(
            "[PasswordGenerator/Length/title]",
            bundle: Bundle.framework,
            value: "Length",
            comment: "Length (number of characters) of the random text to generate")
        public static let titlePasswordLength = NSLocalizedString(
            "[PasswordGenerator/PasswordLength/title]",
            bundle: Bundle.framework,
            value: "Password Length",
            comment: "Length (number of characters) of the password to generate")

        public static let titleWordCount = NSLocalizedString(
            "[PasswordGenerator/WordCount/title]",
            bundle: Bundle.framework,
            value: "Words",
            comment: "Number of words in a generated passphrase. In context: 'Words: 5'")

        public static let spaceCharacterName = NSLocalizedString(
            "[PasswordGenerator/SpaceCharacter/name]",
            bundle: Bundle.framework,
            value: "Space",
            comment: "Name of the space character. https://en.wikipedia.org/wiki/Space_(punctuation)")

        public static let maxConsecutiveTitle = "max-consecutive"

        public static let maxConsecutiveDescription = NSLocalizedString(
            "[PasswordGenerator/MaxConsecutive/description]",
            bundle: Bundle.framework,
            value: "Maximum number of identical characters repeating consecutively.",
            comment: "Description of a password generator parameter. For example, the digit in 'abc222def'.")
    }
}
