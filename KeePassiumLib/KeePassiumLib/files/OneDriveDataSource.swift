//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class OneDriveDataSource: RemoteDataSource {
    typealias ItemType = OneDriveItem
    typealias Manager = OneDriveManager

    let usedFileProvider: FileProvider
    let recoveryAction: String = LString.actionSignInToOneDrive

    let manager: OneDriveManager

    init(fileProvider: FileProvider) {
        self.usedFileProvider = fileProvider
        manager = OneDriveManager.shared
    }
}
