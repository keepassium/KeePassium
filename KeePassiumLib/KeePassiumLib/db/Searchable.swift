//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

protocol SearchableField {
    func contains(
        word: Substring,
        includeFieldNames: Bool,
        includeProtectedValues: Bool,
        includePasswords: Bool,
        options: String.CompareOptions
    ) -> Bool
}

extension EntryField: SearchableField { }

extension String: SearchableField {
    func contains(
        word: Substring,
        includeFieldNames: Bool,
        includeProtectedValues: Bool,
        includePasswords: Bool,
        options: String.CompareOptions
    ) -> Bool {
        return localizedContains(word, options: options)
    }
}

enum SearchScope {
    case any
    case fields
    case tags

    func contains(_ type: Self) -> Bool {
        if self == .any {
            return true
        }
        return self == type
    }
}

protocol Searchable: Taggable {
    var searchableField: [SearchableField] { get }

    func matches(query: SearchQuery, scope: SearchScope) -> Bool
}

extension Entry: Searchable {
    var searchableField: [SearchableField] {
        return fields + attachments.map({ $0.name })
    }
}

extension Group: Searchable {
    var searchableField: [SearchableField] {
        return [name, notes]
    }
}

extension Searchable {
    func matches(query: SearchQuery, scope: SearchScope) -> Bool {
        for word in query.textWords {
            var wordFound = false
            switch word {
            case let .text(word):
                if scope.contains(.fields) {
                    for field in searchableField {
                        wordFound = field.contains(
                            word: word,
                            includeFieldNames: query.includeFieldNames,
                            includeProtectedValues: query.includeProtectedValues,
                            includePasswords: query.includePasswords,
                            options: query.compareOptions)
                        if wordFound {
                            break
                        }
                    }
                    if wordFound {
                        continue
                    }
                }

                if scope.contains(.tags) {
                    for tag in tags {
                        if tag.localizedContains(word, options: query.compareOptions) {
                            wordFound = true
                            break
                        }
                    }
                }
            case let .tag(word):
                if scope.contains(.tags) {
                    for tag in tags {
                        if tag.caseInsensitiveCompare(word) == .orderedSame {
                            wordFound = true
                            break
                        }
                    }
                }
            }

            if !wordFound {
                return false
            }
        }
        return true
    }
}
