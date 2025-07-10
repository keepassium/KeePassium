//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

enum ItemCategory: String {
    public static let all: [ItemCategory] = [.default]

    case `default` = "keepass"

    var fixedFields: [String] {
        return [
            EntryField.title,
            EntryField.userName,
            EntryField.passkey,
            EntryField.password,
            EntryField.totp,
            EntryField.url,
            EntryField.notes]
    }
    var name: String { LString.itemCategoryDefault }

    static let standardFieldRanks: [String: Float] = [
        EntryField.title: 1,
        EntryField.userName: 2,
        EntryField.passkey: 3,
        EntryField.password: 4,
        EntryField.totp: 5,
        EntryField.url: 6,
        EntryField.tags: 7,
        EntryField.notes: 8,
    ]

    public static func getFieldRank(_ fieldName: String) -> Float? {
        if let staticRank = standardFieldRanks[fieldName] {
            return staticRank
        }
        if let urlIndex = EntryField.getExtraURLIndex(from: fieldName) {
            let standardURLRank = standardFieldRanks[EntryField.url]!
            let subRank = 1.0 - 1.0 / (abs(Float(urlIndex)) + 1.1)
            return standardURLRank + subRank
        }
        return nil
    }

    public static func get(for entry: Entry) -> ItemCategory {
        return .default
    }

    public static func get(for group: Group) -> ItemCategory {
        return .default
    }

    public static func fromString(_ categoryString: String) -> ItemCategory {
        return ItemCategory(rawValue: categoryString) ?? .default
    }

    public func compare(_ fieldName1: String, _ fieldName2: String) -> Bool {
        let rank1 = Self.getFieldRank(fieldName1) ?? Float.greatestFiniteMagnitude
        let rank2 = Self.getFieldRank(fieldName2) ?? Float.greatestFiniteMagnitude
        if rank1 != rank2 {
            return rank1 < rank2
        }
        return false
    }
}
