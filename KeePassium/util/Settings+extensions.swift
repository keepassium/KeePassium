//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension Settings.GroupSortOrder {
    var toolbarIcon: UIImage {
        switch self {
        case .noSorting: fallthrough
        case .nameAsc: fallthrough
        case .creationTimeAsc: fallthrough
        case .modificationTimeAsc:
            return UIImage(asset: .sortOrderAscToolbar)
        case .nameDesc: fallthrough
        case .creationTimeDesc: fallthrough
        case .modificationTimeDesc:
            return UIImage(asset: .sortOrderDescToolbar)
        }
    }
}

extension Settings.FilesSortOrder {
    var toolbarIcon: UIImage {
        switch self {
        case .noSorting: fallthrough
        case .nameAsc: fallthrough
        case .creationTimeAsc: fallthrough
        case .modificationTimeAsc:
            return UIImage(asset: .sortOrderAscToolbar)
        case .nameDesc: fallthrough
        case .creationTimeDesc: fallthrough
        case .modificationTimeDesc:
            return UIImage(asset: .sortOrderDescToolbar)
        }
    }
}
