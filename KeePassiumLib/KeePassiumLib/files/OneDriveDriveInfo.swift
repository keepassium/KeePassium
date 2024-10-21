//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public struct OneDriveDriveInfo: Equatable {
    public enum DriveType: String, CustomStringConvertible {
        case personal = "personal"
        case business = "business"
        case sharepoint = "documentLibrary"
        public var description: String {
            switch self {
            case .personal:
                return LString.connectionTypeOneDrivePersonal
            case .business:
                return LString.connectionTypeOneDriveForBusiness
            case .sharepoint:
                return LString.connectionTypeSharePoint
            }
        }

        public var isCorporate: Bool {
            switch self {
            case .personal:
                return false
            case .business, .sharepoint:
                return true
            }
        }

        public var matchingFileProvider: FileProvider {
            switch self {
            case .personal:
                return .keepassiumOneDrivePersonal
            case .business,
                 .sharepoint:
                return .keepassiumOneDriveBusiness
            }
        }
    }

    public var id: String
    public var name: String // e.g. "OneDrive"
    public var type: DriveType
    public var ownerName: String? // e.g. "AdeleV@contoso.com" or "Adele Vance" or nil

    public static func == (lhs: OneDriveDriveInfo, rhs: OneDriveDriveInfo) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.type == rhs.type
            && lhs.ownerName == rhs.ownerName
    }
}
