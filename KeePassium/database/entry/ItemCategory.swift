//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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

    func getFieldRanks() -> [String: Int] {
        return [
            EntryField.title: 1,
            EntryField.userName: 2,
            EntryField.passkey: 3,
            EntryField.password: 4,
            EntryField.totp: 5,
            EntryField.url: 6,
            EntryField.tags: 7,
            EntryField.notes: 8]
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
        let ranks = getFieldRanks()
        let rank1 = ranks[fieldName1] ?? Int.max
        let rank2 = ranks[fieldName2] ?? Int.max
        if rank1 != rank2 {
            return rank1 < rank2
        } else {
            return false 
        }
    }
}
