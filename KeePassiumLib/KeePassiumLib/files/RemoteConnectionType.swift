//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum RemoteConnectionType: CustomStringConvertible {
    public static let allValues: [RemoteConnectionType] = [
        .dropbox,
        .dropboxBusiness,
        .googleDrive,
        .googleWorkspace,
        .oneDrivePersonal,
        .oneDriveForBusiness,
        .webdav,
    ]

    case webdav
    case oneDrivePersonal
    case oneDriveForBusiness
    case dropbox
    case dropboxBusiness
    case googleDrive
    case googleWorkspace

    public var description: String {
        switch self {
        case .webdav:
            return LString.connectionTypeWebDAV
        case .oneDrivePersonal:
            return LString.connectionTypeOneDrivePersonal
        case .oneDriveForBusiness:
            return LString.connectionTypeOneDriveForBusiness
        case .dropbox:
            return LString.connectionTypeDropbox
        case .dropboxBusiness:
            return LString.connectionTypeDropboxBusiness
        case .googleDrive:
            return LString.connectionTypeGoogleDrive
        case .googleWorkspace:
            return LString.connectionTypeGoogleWorkspace
        }
    }

    public var fileProvider: FileProvider {
        switch self {
        case .webdav:
            return .keepassiumWebDAV
        case .oneDrivePersonal:
            return .keepassiumOneDrivePersonal
        case .oneDriveForBusiness:
            return .keepassiumOneDriveBusiness
        case .dropbox,
             .dropboxBusiness:
            return .keepassiumDropbox
        case .googleDrive, .googleWorkspace:
            return .keepassiumGoogleDrive
        }
    }
}

extension RemoteConnectionType {
    public var isBusinessCloud: Bool {
        switch self {
        case .webdav,
             .oneDrivePersonal,
             .dropbox,
             .googleDrive:
            return false
        case .oneDriveForBusiness,
             .dropboxBusiness,
             .googleWorkspace:
            return true
        }
    }

    public var isPremiumUpgradeRequired: Bool {
        return isBusinessCloud &&
               !PremiumManager.shared.isAvailable(feature: .canUseBusinessClouds)
    }
}
