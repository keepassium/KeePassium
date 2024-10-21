//  KeePassium Password Manager
//  Copyright © 2018-2023 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public extension FileProvider {
    var isAllowed: Bool {
        switch self {
        case .keepassiumOneDrivePersonal, .keepassiumOneDriveBusiness:
            if ManagedAppConfig.shared.isAllowed(.keepassiumOneDriveLegacy) {
                return true
            }
            return ManagedAppConfig.shared.isAllowed(self)
        default:
            return ManagedAppConfig.shared.isAllowed(self)
        }
    }
}
