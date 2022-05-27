//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class PassphraseGeneratorParams: Codable, Equatable {
    public static let wordCountRange = 4...20
    public var wordCount: Int = 7
    
    public var separator: String = " "
    public var wordCase: PassphraseGenerator.WordCase = .lowerCase
    public var wordlist: PassphraseWordlist = .effLarge {
        didSet {
            loadedStringSet = wordlist.load()
        }
    }
    
    private var loadedStringSet: StringSet? 
    
    public static func == (lhs: PassphraseGeneratorParams, rhs: PassphraseGeneratorParams) -> Bool {
        return (lhs.wordCount == rhs.wordCount) &&
               (lhs.separator == rhs.separator) &&
               (lhs.wordCase == rhs.wordCase) &&
               (lhs.wordlist == rhs.wordlist)
    }
}

extension PassphraseGeneratorParams: PasswordGeneratorRequirementsConvertible {
    public func toRequirements() -> PasswordGeneratorRequirements {
        if loadedStringSet == nil {
            loadedStringSet = wordlist.load()
        }
        let stringSet = loadedStringSet ?? StringSet()
        let conditionalSet = ConditionalStringSet(stringSet, condition: .allowed)
        
        let preprocessor = makePreprocessorFunction(for: wordCase)
        let merger: PasswordGenerator.ElementMergingFunction = { [separator] elements in
            elements.joined(separator: separator)
        }
        return PasswordGeneratorRequirements(
            length: wordCount,
            sets: [conditionalSet],
            maxConsecutive: nil, 
            elementPreprocessor: preprocessor,
            elementMerger: merger
        )
    }
    
    private func makePreprocessorFunction(
        for wordCase: PassphraseGenerator.WordCase
    ) -> PassphraseGenerator.ElementPreprocessingFunction {
        let preprocessor: PassphraseGenerator.ElementPreprocessingFunction
        switch wordCase {
        case .upperCase:
            preprocessor = { elements in
                elements = elements.map { $0.localizedUppercase }
            }
        case .lowerCase:
            preprocessor = { elements in
                elements = elements.map { $0.localizedLowercase }
            }
        case .titleCase:
            preprocessor = { elements in
                elements = elements.map { $0.localizedCapitalized }
            }
        }
        return preprocessor
    }
}

extension LString.PasswordGenerator {
    public static let titleWordlist = NSLocalizedString(
        "[PasswordGenerator/Wordlist/title]",
        bundle: Bundle.framework,
        value: "Wordlist",
        comment: "List of words to be used for a passphrase."
    )
    public static let titleWordSepartor = NSLocalizedString(
        "[PasswordGenerator/Word Separtor/title]",
        bundle: Bundle.framework,
        value: "Separator",
        comment: "Character to be inserted between words of a passphrase."
    )
}
