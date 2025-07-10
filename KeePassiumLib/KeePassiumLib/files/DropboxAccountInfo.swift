//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct DropboxAccountInfo: Equatable {
    public enum AccountType: String, CustomStringConvertible {
        case basic
        case pro
        case business

        public static func from(_ rawValue: String?) -> Self? {
            guard let rawValue else { return nil }
            return Self(rawValue: rawValue)
        }

        public var description: String {
            switch self {
            case .basic:
                return LString.connectionTypeDropbox
            case .pro:
                return LString.connectionTypeDropboxPro
            case .business:
                return LString.connectionTypeDropboxBusiness
            }
        }

        public var isCorporate: Bool {
            switch self {
            case .basic, .pro:
                return false
            case .business:
                return true
            }
        }
    }

    public var accountId: String
    public var email: String
    public var type: AccountType
}
