//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public protocol OneDriveItem {
    var name: String { get }
    func getRequestURLBase() -> String
    func getChildrenRequestURL() -> URL
}

public struct OneDriveFileItem: OneDriveItem, RemoteFileItem {
    public var name: String
    public var itemID: String
    public var itemPath: String
    public var parent: OneDriveSharedFolder?
    public var isFolder: Bool
    public var fileInfo: FileInfo?
    public var driveInfo: OneDriveDriveInfo?

    public var isSharedItem: Bool {
        return parent != nil
    }

    public func toURL(with driveInfo: OneDriveDriveInfo) -> URL {
        return OneDriveFileURL.build(from: self, driveInfo: driveInfo)
    }

    public func getRequestURLBase() -> String {
        let urlString: String
        let parentPath = parent?.urlPath ?? OneDriveAPI.personalDriveRootPath
        if itemPath == "/" {
            urlString = OneDriveAPI.mainEndpoint + parentPath
        } else {
            let encodedPath = itemPath
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
            urlString = OneDriveAPI.mainEndpoint + parentPath + ":\(encodedPath):"
        }
        return urlString
    }

    public func getChildrenRequestURL() -> URL {
        let urlString = getRequestURLBase() + "/children?select=\(OneDriveAPI.itemFields)"
        return URL(string: urlString)!
    }
}

public struct OneDriveSpecialItem: OneDriveItem, RemoteFileItem {
    public enum Kind {
        case personalFiles
        case sharedWithMe
    }
    public var kind: Kind
    public var fileInfo: FileInfo? { nil }
    public var isFolder: Bool { true }
    public var name: String {
        switch kind {
        case .personalFiles:
            return LString.titleOneDriveFolderFiles
        case .sharedWithMe:
            return LString.titleOneDriveFolderSharedWithMe
        }
    }

    public init(kind: Kind) {
        self.kind = kind
    }

    public func getRequestURLBase() -> String {
        switch kind {
        case .personalFiles:
            return OneDriveAPI.mainEndpoint + OneDriveAPI.personalDriveRootPath
        case .sharedWithMe:
            return OneDriveAPI.mainEndpoint + OneDriveAPI.sharedWithMeRootPath
        }
    }

    public func getChildrenRequestURL() -> URL {
        switch kind {
        case .personalFiles:
            let urlString = getRequestURLBase() + "/children?select=\(OneDriveAPI.itemFields)"
            return URL(string: urlString)!
        case .sharedWithMe:
            let urlString = getRequestURLBase() // no "/children", it's a special case
            return URL(string: urlString)!
        }
    }
}

public struct OneDriveItemReference {
    var path: String
    var parent: OneDriveSharedFolder?

    public static func fromURL(_ url: URL) -> OneDriveItemReference? {
        guard let filePath = OneDriveFileURL.getFilePath(from: url) else {
            return nil
        }
        let parent = OneDriveFileURL.getParent(from: url) 
        return OneDriveItemReference(path: filePath, parent: parent)
    }
}

public struct OneDriveSharedFolder {
    public var driveID: String
    public var itemID: String
    public var name: String

    var urlPath: String {
        return "/drives/\(driveID)/items/\(itemID)"
    }
}

private enum OneDriveFileURL {
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

    public static func build(from fileItem: OneDriveFileItem, driveInfo: OneDriveDriveInfo) -> URL {
        var queryItems = [
            URLQueryItem(name: Key.fileID, value: fileItem.itemID),
            URLQueryItem(name: Key.driveType, value: driveInfo.type.rawValue),
            URLQueryItem(name: Key.owner, value: driveInfo.ownerName)
        ]
        if let parent = fileItem.parent {
            queryItems.append(URLQueryItem(name: Key.parentDriveID, value: parent.driveID))
            queryItems.append(URLQueryItem(name: Key.parentItemID, value: parent.itemID))
            queryItems.append(URLQueryItem(name: Key.parentName, value: parent.name))
        }
        let result = URL.build(
            schemePrefix: schemePrefix,
            scheme: scheme,
            host: driveInfo.id,
            path: fileItem.itemPath,
            queryItems: queryItems
        )
        return result
    }

    internal static func getFilePath(from prefixedURL: URL) -> String? {
        return prefixedURL.relativePath
    }

    internal static func getParent(from prefixedURL: URL) -> OneDriveSharedFolder? {
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

    public static func getDescription(for prefixedURL: URL) -> String? {
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
            switch driveType {
            case .personal:
                serviceName = LString.connectionTypeOneDrive
            case .business:
                serviceName = LString.connectionTypeOneDriveForBusiness
            case .sharepoint:
                serviceName = LString.connectionTypeSharePoint
            }
        }
        return "\(serviceName) (\(owner)) → \(path)"
    }
}

internal extension URL {
    var isOneDriveFileURL: Bool {
        return self.scheme == OneDriveFileURL.prefixedScheme
    }
    func getOneDriveLocationDescription() -> String? {
        guard isOneDriveFileURL else {
            return nil
        }
        return OneDriveFileURL.getDescription(for: self)
    }
}
