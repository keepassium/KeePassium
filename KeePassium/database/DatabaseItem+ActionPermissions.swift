//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension DatabaseItem {
    struct ActionPermissions {
        static let everythingForbidden = ActionPermissions(
            canEditDatabase: false,
            canCreateGroup: false,
            canCreateEntry: false,
            canEditItem: false,
            canDeleteItem: false,
            canMoveItem: false
        )
        var canEditDatabase = false
        var canCreateGroup = false
        var canCreateEntry = false
        var canEditItem = false
        var canDeleteItem = false
        var canMoveItem = false
    }
}
