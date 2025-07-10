//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct WebDAVItem: RemoteFileItem {
    public var name: String
    public var isFolder: Bool
    public var fileInfo: FileInfo?
    public var supportsItemCreation: Bool {
        return isFolder
    }
    public var belongsToCorporateAccount: Bool = false
    public var root: URL
    public var url: URL
}

extension WebDAVItem {
    public static func root(url: URL) -> Self {
        return WebDAVItem(name: LString.connectionTypeWebDAV, isFolder: true, root: url, url: url)
    }
}
