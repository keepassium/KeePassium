//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension URL {
    fileprivate var isOneDriveFileURL: Bool {
        return self.scheme == OneDriveURLHelper.prefixedScheme
    }

    var isOneDrivePersonalFileURL: Bool {
        return isOneDriveFileURL
            && OneDriveURLHelper.getDriveType(from: self) == .personal
    }

    var isOneDriveBusinessFileURL: Bool {
        return isOneDriveFileURL
            && OneDriveURLHelper.getDriveType(from: self) == .business
    }

    func getOneDriveLocationDescription() -> String? {
        guard isOneDriveFileURL else {
            return nil
        }
        return OneDriveURLHelper.getDescription(for: self)
    }
}

extension OneDriveItem: SerializableRemoteFileItem  {
    public static func fromURL(_ prefixedURL: URL) -> OneDriveItem? {
        return OneDriveURLHelper.urlToItem(prefixedURL)
    }

    public func toURL() -> URL {
        return OneDriveURLHelper.build(from: self)
    }
}

private enum OneDriveURLHelper {
    public static let schemePrefix = "keepassium"
    public static let scheme = "onedrive"
    public static let prefixedScheme = schemePrefix + String(urlSchemePrefixSeparator) + scheme

    private enum Key {
        static let fileID = "fileID"
        static let driveType = "driveType"
        static let owner = "owner"
        static let parentDriveID = "parentDriveID"
        static let parentItemID = "parentItemID"
        static let parentName = "parentName"
    }

    static func build(from item: OneDriveItem) -> URL {
        var queryItems = [
            URLQueryItem(name: Key.fileID, value: item.itemID),
            URLQueryItem(name: Key.driveType, value: item.driveInfo.type.rawValue),
            URLQueryItem(name: Key.owner, value: item.driveInfo.ownerName)
        ]
        if let parent = item.parent {
            queryItems.append(URLQueryItem(name: Key.parentDriveID, value: parent.driveID))
            queryItems.append(URLQueryItem(name: Key.parentItemID, value: parent.itemID))
            queryItems.append(URLQueryItem(name: Key.parentName, value: parent.name))
        }
        let result = URL.build(
            schemePrefix: schemePrefix,
            scheme: scheme,
            host: item.driveInfo.id,
            path: item.itemPath,
            queryItems: queryItems
        )
        return result
    }

    public static func urlToItem(_ prefixedURL: URL) -> OneDriveItem? {
        guard prefixedURL.isOneDriveFileURL else {
            Diag.error("Not an OneDrive URL, cancelling")
            assertionFailure()
            return nil
        }
        let queryItems = prefixedURL.queryItems
        guard let itemID = queryItems[Key.fileID] else {
            Diag.error("File ID is missing, cancelling")
            assertionFailure()
            return nil
        }
        let itemName: String = prefixedURL.lastPathComponent
        let itemPath: String = prefixedURL.path
        guard itemName.isNotEmpty && itemPath.isNotEmpty else {
            Diag.error("Item name or path is empty, cancelling")
            assertionFailure()
            return nil
        }

        let parent: OneDriveSharedFolder?
        if let parentDriveID = queryItems[Key.parentDriveID],
           let parentItemID = queryItems[Key.parentItemID],
           let parentName = queryItems[Key.parentName]
        {
            parent = OneDriveSharedFolder(driveID: parentDriveID, itemID: parentItemID, name: parentName)
        } else {
            parent = nil
        }

        guard let driveID = prefixedURL.host,
              let driveTypeString = queryItems[Key.driveType],
              let driveType = OneDriveDriveInfo.DriveType(rawValue: driveTypeString)
        else {
            Diag.error("Failed to parse drive parameters, cancelling")
            assertionFailure()
            return nil
        }
        let driveOwnerName = queryItems[Key.owner]
        let driveInfo = OneDriveDriveInfo(
            id: driveID,
            name: "OneDrive",
            type: driveType,
            ownerName: driveOwnerName
        )
        return OneDriveItem(
            name: itemName,
            itemID: itemID,
            itemPath: itemPath,
            parent: parent,
            isFolder: prefixedURL.hasDirectoryPath,
            fileInfo: nil,
            driveInfo: driveInfo
        )
    }

    static func getDescription(for prefixedURL: URL) -> String? {
        let queryItems = prefixedURL.queryItems
        let path: String
        if let parent = getParent(from: prefixedURL) {
            path = parent.name + prefixedURL.relativePath
        } else {
            path = prefixedURL.relativePath
        }

        var serviceName = ""
        let owner = queryItems[Key.owner] ?? "?"
        if let driveTypeRaw = queryItems[Key.driveType],
           let driveType = OneDriveDriveInfo.DriveType(rawValue: driveTypeRaw)
        {
            serviceName = driveType.description
        }
        return "\(serviceName) (\(owner)) → \(path)"
    }

    static func getParent(from prefixedURL: URL) -> OneDriveSharedFolder? {
        guard prefixedURL.isOneDriveFileURL else {
            return nil
        }
        let queryItems = prefixedURL.queryItems
        guard let parentDriveID = queryItems[Key.parentDriveID],
              let parentItemID = queryItems[Key.parentItemID],
              let parentName = queryItems[Key.parentName]
        else {
            return nil
        }
        return .init(driveID: parentDriveID, itemID: parentItemID, name: parentName)
    }

    fileprivate static func getDriveType(from prefixedURL: URL) -> OneDriveDriveInfo.DriveType? {
        assert(prefixedURL.isOneDriveFileURL)
        guard let driveTypeString = prefixedURL.queryItems[Key.driveType],
              let driveType = OneDriveDriveInfo.DriveType(rawValue: driveTypeString)
        else {
            return nil
        }
        return driveType
    }
}
