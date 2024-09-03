//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public enum ExternalUpdateBehavior: Int, CaseIterable, Codable {
    case dontCheck
    case checkAndNotify
    case checkAndReload

    public var title: String {
        switch self {
        case .dontCheck:
            return LString.titleIfDatabaseModifiedExternallyDontCheck
        case .checkAndNotify:
            return LString.titleIfDatabaseModifiedExternallyNotify
        case .checkAndReload:
            return LString.titleIfDatabaseModifiedExternallyReload
        }
    }
}
