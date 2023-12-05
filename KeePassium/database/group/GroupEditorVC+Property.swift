//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension GroupEditorVC {
    struct Property: Equatable {
        enum Kind: Equatable {
            case search
            case autoFill
        }
        var kind: Kind
        var value: Bool?
        var inheritedValue: Bool

        static let possibleValues: [Bool?] = [nil, true, false]

        var title: String {
            switch kind {
            case .search:
                return LString.titleItemPropertySearch
            case .autoFill:
                return LString.titleItemPropertyAutoFill
            }
        }

        static func makeAll(for group: Group, parent: Group) -> [Property] {
            guard let group2 = group as? Group2,
                  let parent2 = parent as? Group2
            else {
                return []
            }
            return [
                Self(
                    kind: .search,
                    value: group2.isSearchingEnabled,
                    inheritedValue: parent2.resolvingIsSearchingEnabled()),
                Self(
                    kind: .autoFill,
                    value: group2.isAutoTypeEnabled,
                    inheritedValue: parent2.resolvingIsAutoTypeEnabled()),
            ]
        }

        func apply(to group: Group?) {
            guard let group2 = group as? Group2 else {
                assertionFailure("Expected a non-nil Group2 instance")
                return
            }
            switch kind {
            case .search:
                group2.isSearchingEnabled = value
            case .autoFill:
                group2.isAutoTypeEnabled = value
            }
        }

        var description: String {
            return description(for: value, inheritedValue: inheritedValue)
        }

        func description(for value: Bool?, inheritedValue: Bool) -> String {
            switch kind {
            case .search:
                if let value {
                    return value ? LString.itemSearchAllowed : LString.itemSearchDisabled
                } else {
                    return String.localizedStringWithFormat(
                        LString.itemPropertyInheritedTemplate,
                        inheritedValue ? LString.itemSearchAllowed : LString.itemSearchDisabled)
                }
            case .autoFill:
                if let value {
                    return value ? LString.itemAutoFillAllowed : LString.itemAutoFillDisabled
                } else {
                    return String.localizedStringWithFormat(
                        LString.itemPropertyInheritedTemplate,
                        inheritedValue ? LString.itemAutoFillAllowed : LString.itemAutoFillDisabled)
                }
            }
        }
    }
}
