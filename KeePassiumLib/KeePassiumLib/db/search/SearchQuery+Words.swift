//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension SearchQuery {
    protocol Word {
        var isNegated: Bool { get }

        func matches(_ searchable: Searchable, query: SearchQuery, scope: SearchScope) -> Bool
        func matchesIgnoringNegation(_ searchable: Searchable, query: SearchQuery, scope: SearchScope) -> Bool
    }

    public final class TextWord: Word {
        let text: Substring
        let isNegated: Bool

        init(text: Substring) {
            isNegated = text.hasPrefix(Prefix.negativeModifier)
            self.text = isNegated ? text.dropFirst() : text
        }

        func matchesIgnoringNegation(_ searchable: Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
            if scope.contains(.fields) {
                for field in searchable.searchableFields {
                    if field.contains(
                        textWord: text,
                        scope: query.fieldScope,
                        options: query.compareOptions)
                    {
                        return true
                    }
                }
            }
            if scope.contains(.tags) {
                for tag in searchable.tags {
                    if tag.localizedContains(text, options: query.compareOptions) {
                        return true
                    }
                }
            }
            return false
        }
    }

    public final class TagWord: Word {
        let tag: Substring
        let isNegated: Bool

        init(tag: Substring, isNegated: Bool) {
            self.tag = tag
            self.isNegated = isNegated
        }

        func matchesIgnoringNegation(_ searchable: any Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
            guard scope.contains(.tags) else { return false }
            for tag in searchable.tags {
                if tag.compare(self.tag, options: query.compareOptions) == .orderedSame {
                    return true
                }
            }
            return false
        }
    }

    public final class FieldWord: Word {
        let name: String
        let term: Substring
        let isNegated: Bool

        init(name: String, term: Substring, isNegated: Bool) {
            self.name = name
            self.term = term
            self.isNegated = isNegated
        }

        convenience init(name: String, term: Substring) {
            let isNegated = name.hasPrefix(Prefix.negativeModifier)
            let name = isNegated ? String(name.dropFirst()) : name
            self.init(name: name, term: term, isNegated: isNegated)
        }

        func matchesIgnoringNegation(_ searchable: any Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
            guard scope.contains(.fields) else { return false }
            let fieldWithMatchingName = searchable.namedSearchableFields.first(where: {
                $0.name.compare(self.name, options: query.compareOptions) == .orderedSame
            })
            if let fieldWithMatchingName {
                return fieldWithMatchingName.value.matchesCaseInsensitive(wildcard: String(term))
            }
            return false
        }
    }

    public final class QualifierWord: Word {
        public enum Qualifier: Substring {
            case entry
            case group
            case expired
            case passkey
            case large
        }

        let qualifier: Qualifier
        let isNegated: Bool

        init(_ qualifier: Qualifier, isNegated: Bool) {
            self.qualifier = qualifier
            self.isNegated = isNegated
        }

        convenience init?(rawValue: Substring, isNegated: Bool) {
            guard let qualifier = Qualifier(rawValue: rawValue) else {
                return nil
            }
            self.init(qualifier, isNegated: isNegated)
        }

        func matchesIgnoringNegation(_ searchable: any Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
            switch qualifier {
            case .entry:
                return (searchable is Entry)
            case .group:
                return (searchable is Group)
            case .expired:
                return searchable.isExpired
            case .passkey:
                guard let entry = searchable as? Entry else { return false }
                return Passkey.probablyPresent(in: entry)
            case .large:
                let underestimatedSize = searchable.getUnderestimatedSize()
                return underestimatedSize > 100_000
            }
        }
    }
}

extension SearchQuery.Word {
    func matches(_ searchable: Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
        let result = matchesIgnoringNegation(searchable, query: query, scope: scope)
        if isNegated {
            return !result
        } else {
            return result
        }
    }
}
