//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public protocol RemoteFileItem {
    var name: String { get }
    var isFolder: Bool { get }
    var fileInfo: FileInfo? { get }
    var supportsItemCreation: Bool { get }
    var belongsToCorporateAccount: Bool { get }
}

public protocol SerializableRemoteFileItem: RemoteFileItem {
    static func fromURL(_ url: URL) -> Self?
    func toURL() -> URL
}
