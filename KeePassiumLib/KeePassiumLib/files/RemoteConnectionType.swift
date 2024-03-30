//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum RemoteConnectionType: String, CustomStringConvertible {
    public static let allValues: [RemoteConnectionType] = [
        .dropbox,
        .dropboxBusiness,
        .oneDrive,
        .oneDriveForBusiness,
        .webdav,
    ]

    // swiftlint:disable redundant_string_enum_value
    case webdav = "webdav"
    case oneDrive = "oneDrive"
    case oneDriveForBusiness = "oneDriveForBusiness"
    case dropbox = "dropbox"
    case dropboxBusiness = "dropboxBusiness"
    // swiftlint:enable redundant_string_enum_value

    public var description: String {
        switch self {
        case .webdav:
            return LString.connectionTypeWebDAV
        case .oneDrive:
            return LString.connectionTypeOneDrive
        case .oneDriveForBusiness:
            return LString.connectionTypeOneDriveForBusiness
        case .dropbox:
            return LString.connectionTypeDropbox
        case .dropboxBusiness:
            return LString.connectionTypeDropboxBusiness
        }
    }

    public var fileProvider: FileProvider {
        switch self {
        case .webdav:
            return .keepassiumWebDAV
        case .oneDrive,
             .oneDriveForBusiness:
            return .keepassiumOneDrive
        case .dropbox,
             .dropboxBusiness:
            return .keepassiumDropbox
        }
    }
}

extension RemoteConnectionType {
    public var isBusinessCloud: Bool {
        switch self {
        case .webdav,
             .oneDrive,
             .dropbox:
            return false
        case .oneDriveForBusiness,
             .dropboxBusiness:
            return true
        }
    }

    public var isPremiumUpgradeRequired: Bool {
        return isBusinessCloud &&
               !PremiumManager.shared.isAvailable(feature: .canUseBusinessClouds)
    }
}
