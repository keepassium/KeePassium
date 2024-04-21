//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct GoogleDriveAccountInfo {
    public var email: String
    public var canCreateDrives: Bool

    public var isWorkspaceAccount: Bool {
        return canCreateDrives
    }

    public var serviceName: String {
        if isWorkspaceAccount {
            return LString.connectionTypeGoogleWorkspace
        } else {
            return LString.connectionTypeGoogleDrive
        }
    }
}
