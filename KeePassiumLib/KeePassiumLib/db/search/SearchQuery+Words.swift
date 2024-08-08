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
        func matches(_ searchable: Searchable, query: SearchQuery, scope: SearchScope) -> Bool
        func equalsTo(_ anotherWord: any Word) -> Bool
    }

    public final class TextWord: Word {
        private let text: Substring
        init(text: Substring) {
            self.text = text
        }

        func equalsTo(_ anotherWord: any Word) -> Bool {
            guard let word = anotherWord as? Self else { return false }
            return self.text == word.text
        }

        func matches(_ searchable: Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
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
        private let tag: Substring
        init(tag: Substring) {
            self.tag = tag
        }

        func equalsTo(_ anotherWord: any Word) -> Bool {
            guard let word = anotherWord as? Self else { return false }
            return self.tag == word.tag
        }

        func matches(_ searchable: any Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
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
        private let name: String
        private let term: Substring
        init(name: String, term: Substring) {
            self.name = name
            self.term = term
        }

        func equalsTo(_ anotherWord: any Word) -> Bool {
            guard let word = anotherWord as? Self else { return false }
            return (self.name == word.name) && (self.term == word.term)
        }

        func matches(_ searchable: any Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
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
        }

        private let qualifier: Qualifier

        init(_ qualifier: Qualifier) {
            self.qualifier = qualifier
        }

        convenience init?(rawValue: Substring) {
            guard let qualifier = Qualifier(rawValue: rawValue) else {
                return nil
            }
            self.init(qualifier)
        }

        func equalsTo(_ anotherWord: any Word) -> Bool {
            guard let word = anotherWord as? Self else { return false }
            return self.qualifier == word.qualifier
        }

        func matches(_ searchable: any Searchable, query: SearchQuery, scope: SearchScope) -> Bool {
            switch qualifier {
            case .entry:
                return (searchable is Entry)
            case .group:
                return (searchable is Group)
            case .expired:
                return searchable.isExpired
            }
        }
    }
}
