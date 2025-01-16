//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct SearchQuery {
    enum Prefix {
        static let negativeModifier = "-"
        private static let tagPrefix = "tag"
        private static let isPrefix = "is"

        case tag(isNegated: Bool)
        case `is`(isNegated: Bool)

        init?(value: String) {
            let isNegated = value.hasPrefix(Self.negativeModifier)
            let prefix = isNegated ? value.dropFirst() : Substring(value)

            switch prefix {
            case Self.tagPrefix:
                self = .tag(isNegated: isNegated)
            case Self.isPrefix:
                self = .`is`(isNegated: isNegated)
            default:
                return nil
            }
        }
    }

    private static let separator = ":" as Character

    public let excludeGroupUUID: UUID?

    public struct FieldScope: OptionSet {
        public var rawValue: Int

        public static let fieldNames      = FieldScope(rawValue: 1 << 0)
        public static let protectedValues = FieldScope(rawValue: 1 << 1)
        public static let passwordField   = FieldScope(rawValue: 1 << 2)
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    public let fieldScope: FieldScope
    public let compareOptions: String.CompareOptions
    public let flattenGroups: Bool

    public let text: String
    let queryWords: [any Word]

    public init(
        fieldScope: FieldScope,
        compareOptions: String.CompareOptions,
        excludeGroupUUID: UUID?,
        flattenGroups: Bool,
        text: String
    ) {
        self.fieldScope = fieldScope
        self.compareOptions = compareOptions
        self.excludeGroupUUID = excludeGroupUUID
        self.flattenGroups = flattenGroups
        self.text = text
        self.queryWords = Self.makeWords(from: text)
    }

    static func makeWords(from text: String) -> [any Word] {
        let queryTokens = parse(text)
        return queryTokens.map { token in
            let subTokens = token
                .split(separator: separator, maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard subTokens.count == 2 else {
                return TextWord(text: token.prefix(token.count))
            }
            guard let index = subTokens[1].firstIndex(where: { !$0.isWhitespace }) else {
                return TextWord(text: token.prefix(token.count))
            }

            let prefix = subTokens[0].lowercased()
            let value = subTokens[1].suffix(from: index)
            switch Prefix(value: prefix) {
            case let .tag(isNegated):
                return TagWord(tag: value, isNegated: isNegated)
            case let .`is`(isNegated):
                if let qualifierWord = QualifierWord(rawValue: value, isNegated: isNegated)  {
                    return qualifierWord
                } else {
                    return FieldWord(name: prefix, term: value)
                }
            case .none:
                return FieldWord(name: subTokens[0], term: value)
            }
        }
    }

    private static func parse(_ text: String) -> [String] {
        let delimiter = Character(" ")
        let quote = Character("\"")

        var tokens = [String]()
        var pending = ""
        var isQuoted = false
        for character in text {
            if character == quote {
                isQuoted = !isQuoted
            } else if character == delimiter && !isQuoted {
                if !pending.isEmpty {
                    tokens.append(pending)
                }
                pending = ""
            } else {
                pending.append(character)
            }
        }

        if !pending.isEmpty {
            tokens.append(pending)
        }

        return tokens
    }
}
