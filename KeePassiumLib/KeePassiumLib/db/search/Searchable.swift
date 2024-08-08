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
        textWord: Substring,
        scope: SearchQuery.FieldScope,
        options: String.CompareOptions
    ) -> Bool
}

protocol NamedSearchableField {
    var name: String { get }
    var value: String { get }
}

extension EntryField: SearchableField { }

extension String: SearchableField {
    func contains(
        textWord: Substring,
        scope: SearchQuery.FieldScope,
        options: String.CompareOptions
    ) -> Bool {
        return localizedContains(textWord, options: options)
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
    var isExpired: Bool { get }
    var searchableFields: [SearchableField] { get }
    var namedSearchableFields: [NamedSearchableField] { get }

    func matches(query: SearchQuery, scope: SearchScope) -> Bool
}

extension EntryField: NamedSearchableField {}

extension Entry: Searchable {
    var searchableFields: [SearchableField] {
        return fields + attachments.map({ $0.name })
    }
    var namedSearchableFields: [NamedSearchableField] {
        return fields
    }
}

extension Group: Searchable {
    struct GroupValueField: NamedSearchableField {
        let name: String
        let value: String
    }

    var searchableFields: [SearchableField] {
        return [name, notes]
    }
    var namedSearchableFields: [NamedSearchableField] {
        return [
            GroupValueField(name: "notes", value: notes),
            GroupValueField(name: "name", value: name)
        ]
    }
}

extension Searchable {
    func matches(query: SearchQuery, scope: SearchScope) -> Bool {
        let allWordsMatch = query.queryWords.allSatisfy { word in
            word.matches(self, query: query, scope: scope)
        }
        return allWordsMatch
    }
}
