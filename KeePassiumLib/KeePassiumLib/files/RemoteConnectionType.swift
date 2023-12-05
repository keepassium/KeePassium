//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum RemoteConnectionType: String, CustomStringConvertible {
    public static let allValues: [RemoteConnectionType] = [
        .webdav,
        .oneDrive,
        .oneDriveForBusiness
    ]

    // swiftlint:disable redundant_string_enum_value
    case webdav = "webdav"
    case oneDrive = "oneDrive"
    case oneDriveForBusiness = "oneDriveForBusiness"
    // swiftlint:enable redundant_string_enum_value

    public var description: String {
        switch self {
        case .webdav:
            return LString.connectionTypeWebDAV
        case .oneDrive:
            return LString.connectionTypeOneDrive
        case .oneDriveForBusiness:
            return LString.connectionTypeOneDriveForBusiness
        }
    }
}

extension RemoteConnectionType {
    public var isBusinessCloud: Bool {
        switch self {
        case .webdav,
             .oneDrive:
            return false
        case .oneDriveForBusiness:
            return true
        }
    }

    public var isPremiumUpgradeRequired: Bool {
        return isBusinessCloud &&
               !PremiumManager.shared.isAvailable(feature: .canUseBusinessClouds)
    }
}
