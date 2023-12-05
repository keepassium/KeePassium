//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public struct OneDriveDriveInfo {
    public enum DriveType: String, CustomStringConvertible {
        case personal = "personal"
        case business = "business"
        case sharepoint = "documentLibrary"
        public var description: String {
            switch self {
            case .personal:
                return LString.connectionTypeOneDrive
            case .business:
                return LString.connectionTypeOneDriveForBusiness
            case .sharepoint:
                return LString.connectionTypeSharePoint
            }
        }
    }

    public var id: String
    public var name: String // e.g. "OneDrive"
    public var type: DriveType
    public var ownerName: String? // e.g. "AdeleV@contoso.com" or "Adele Vance" or nil
}
