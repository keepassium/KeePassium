//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct DropboxItem: RemoteFileItem {
    public var name: String
    public var isFolder: Bool
    public var fileInfo: FileInfo?
    public var pathDisplay: String
    public var info: DropboxAccountInfo
    public let supportsItemCreation: Bool = true
}

extension DropboxItem {
    public static func root(info: DropboxAccountInfo) -> Self {
        return DropboxItem(name: LString.connectionTypeDropbox, isFolder: true, pathDisplay: "", info: info)
    }

    public var escapedPath: String {
        let result = pathDisplay.applyingTransform(.init("Hex-Any"), reverse: true)
        assert(result != nil, "Failed to escape pathDisplay, this should not happen")
        return result ?? pathDisplay
    }
}
