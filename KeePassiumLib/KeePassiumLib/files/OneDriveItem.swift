//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public struct OneDriveSharedFolder: Equatable {
    public var driveID: String
    public var itemID: String
    public var name: String

    var urlPath: String {
        return "/drives/\(driveID)/items/\(itemID)"
    }

    public static func == (lhs: OneDriveSharedFolder, rhs: OneDriveSharedFolder) -> Bool {
        return lhs.driveID == rhs.driveID
            && lhs.itemID == rhs.itemID
            && lhs.name == rhs.name
    }
}

public struct OneDriveItem: RemoteFileItem {
    public var name: String
    public var itemID: String
    public var itemPath: String
    public var parent: OneDriveSharedFolder?
    public var isFolder: Bool
    public var fileInfo: FileInfo?
    public let driveInfo: OneDriveDriveInfo

    private let requestURLBaseOverride: String?
    private let childrenRequestOverride: String?

    public let supportsItemCreation: Bool

    public var isSharedItem: Bool {
        return parent != nil
    }

    init(
        name: String,
        itemID: String,
        itemPath: String,
        parent: OneDriveSharedFolder? = nil,
        isFolder: Bool,
        fileInfo: FileInfo? = nil,
        driveInfo: OneDriveDriveInfo
    ) {
        self.init(
            name: name,
            itemID: itemID,
            itemPath: itemPath,
            parent: parent,
            isFolder: isFolder,
            fileInfo: fileInfo,
            driveInfo: driveInfo,
            requestURLBaseOverride: nil,
            childrenRequestOverride: nil,
            supportsItemCreation: true
        )
    }

    private init(
        name: String,
        itemID: String,
        itemPath: String,
        parent: OneDriveSharedFolder? = nil,
        isFolder: Bool,
        fileInfo: FileInfo? = nil,
        driveInfo: OneDriveDriveInfo,
        requestURLBaseOverride: String?,
        childrenRequestOverride: String?,
        supportsItemCreation: Bool
    ) {
        self.name = name
        self.itemID = itemID
        self.itemPath = itemPath
        self.parent = parent
        self.isFolder = isFolder
        self.fileInfo = fileInfo
        self.driveInfo = driveInfo
        self.requestURLBaseOverride = requestURLBaseOverride
        self.childrenRequestOverride = childrenRequestOverride
        self.supportsItemCreation = supportsItemCreation
    }

    public static func getPersonalFilesFolder(driveInfo: OneDriveDriveInfo) -> OneDriveItem {
        OneDriveItem(
            name: LString.titleOneDriveFolderFiles,
            itemID: "",
            itemPath: "/",
            isFolder: true,
            driveInfo: driveInfo,
            requestURLBaseOverride: nil,
            childrenRequestOverride: nil,
            supportsItemCreation: true
        )
    }

    public static func getSharedWithMeFolder(driveInfo: OneDriveDriveInfo) -> OneDriveItem {
        OneDriveItem(
            name: LString.titleOneDriveFolderSharedWithMe,
            itemID: "",
            itemPath: "",
            isFolder: true,
            driveInfo: driveInfo,
            requestURLBaseOverride: OneDriveAPI.mainEndpoint + OneDriveAPI.sharedWithMeRootPath,
            childrenRequestOverride: "", // same as base URL, no "/children" - it's a special case
            supportsItemCreation: false
        )
    }

    public func childFileItem(name: String, itemID: String) -> Self {
        assert(self.isFolder, "childFileItem should be used on folder items")
        return OneDriveItem(
            name: name,
            itemID: itemID,
            itemPath: self.itemPath.withTrailingSlash() + name,
            parent: self.parent,
            isFolder: false,
            fileInfo: nil,
            driveInfo: self.driveInfo,
            requestURLBaseOverride: self.requestURLBaseOverride,
            childrenRequestOverride: self.childrenRequestOverride,
            supportsItemCreation: false
        )
    }
}

extension OneDriveItem: Equatable {
    public static func == (lhs: OneDriveItem, rhs: OneDriveItem) -> Bool {
        return lhs.name == rhs.name
            && lhs.itemID == rhs.itemID
            && lhs.itemPath == rhs.itemPath
            && lhs.parent == rhs.parent
            && lhs.isFolder == rhs.isFolder
            && lhs.fileInfo == rhs.fileInfo
            && lhs.driveInfo == rhs.driveInfo
            && lhs.requestURLBaseOverride == rhs.requestURLBaseOverride
            && lhs.childrenRequestOverride == rhs.childrenRequestOverride
    }
}

extension OneDriveItem {
    enum APIEndpoint {
        case children
        case itemInfo
        case content
        case createUploadSessionForUpdating
        case createUploadSessionForCreating(newFileName: String)
    }

    private func getRequestURLBase(path: String? = nil) -> String {
        if let requestURLBaseOverride {
            return requestURLBaseOverride
        }

        let path = path ?? itemPath
        let urlString: String
        let parentPath = parent?.urlPath ?? OneDriveAPI.personalDriveRootPath
        if path == "/" {
            urlString = OneDriveAPI.mainEndpoint + parentPath
        } else {
            let encodedPath = path
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
            urlString = OneDriveAPI.mainEndpoint + parentPath + ":\(encodedPath):"
        }
        return urlString
    }

    func getRequestURL(_ endpoint: APIEndpoint) -> URL {
        var urlString = getRequestURLBase()
        switch endpoint {
        case .children:
            urlString += childrenRequestOverride ?? "/children?select=\(OneDriveAPI.itemFields)"
        case .itemInfo:
            break
        case .content:
            urlString += "/content"
        case .createUploadSessionForUpdating:
            urlString += "/createUploadSession"
        case .createUploadSessionForCreating(let newFileName):
            assert(isFolder, "Parent item is a file, cannot create a subfile.")
            assert(newFileName.isNotEmpty, "File name cannot be empty")
            urlString = getRequestURLBase(path: itemPath.withTrailingSlash() + newFileName) + "/createUploadSession"
        }
        return URL(string: urlString)!
    }
}
