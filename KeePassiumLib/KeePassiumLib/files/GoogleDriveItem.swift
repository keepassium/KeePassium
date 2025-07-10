//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct GoogleDriveItem: RemoteFileItem {
    public var name: String
    public var id: String
    public var isFolder: Bool
    public var isShortcut: Bool
    public var fileInfo: FileInfo?
    public var accountInfo: GoogleDriveAccountInfo
    public var supportsItemCreation: Bool {
        return isFolder
    }

    public var sharedDriveID: String?

    private var rootType: RootType?

    init(
        name: String,
        id: String,
        isFolder: Bool,
        isShortcut: Bool,
        fileInfo: FileInfo? = nil,
        accountInfo: GoogleDriveAccountInfo,
        sharedDriveID: String? = nil,
        rootType: RootType? = nil
    ) {
        self.name = name
        self.id = id
        self.isFolder = isFolder
        self.isShortcut = isShortcut
        self.fileInfo = fileInfo
        self.accountInfo = accountInfo
        self.sharedDriveID = sharedDriveID
        self.rootType = rootType
    }
}

extension GoogleDriveItem {
    public enum RootType: CustomStringConvertible {
        case myDrive
        case sharedWithMe
        public var description: String {
            switch self {
            case .myDrive:
                return LString.titleGoogleDriveFolderMyDrive
            case .sharedWithMe:
                return LString.titleGoogleDriveFolderSharedWithMe
            }
        }
    }

    public static func getSpecialFolder(_ type: RootType, accountInfo: GoogleDriveAccountInfo) -> Self {
        return GoogleDriveItem(
            name: type.description,
            id: "",
            isFolder: true,
            isShortcut: false,
            accountInfo: accountInfo,
            rootType: type
        )
    }

    public var belongsToCorporateAccount: Bool {
        return accountInfo.isWorkspaceAccount
    }
}

extension GoogleDriveItem {
    enum APIEndpoint {
        case children(nextPageToken: String?)
        case itemInfo
        case content
        case update
        case create
    }

    func getRequestURL(_ endpoint: APIEndpoint) -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "www.googleapis.com"
        urlComponents.queryItems = []
        let addQueryItem = { (name: String, value: String) in
            urlComponents.queryItems!.append(URLQueryItem(name: name, value: value))
        }

        switch endpoint {
        case .children(let nextPageToken):
            urlComponents.path = "/drive/v3/files"
            addQueryItem(GoogleDriveAPI.Keys.fields, "nextPageToken,files(\(GoogleDriveAPI.fileFields))")
            if let sharedDriveID {
                addQueryItem(GoogleDriveAPI.Keys.includeItemsFromAllDrives, "true")
                addQueryItem(GoogleDriveAPI.Keys.corpora, "drive")
                addQueryItem(GoogleDriveAPI.Keys.driveID, sharedDriveID)
            }
            var qParamParts = ["not trashed"]
            if id.isNotEmpty {
                qParamParts.append("'\(id)' in parents")
            } else if rootType == .myDrive {
                qParamParts.append("'root' in parents")
            }

            switch rootType {
            case .myDrive:
                qParamParts.append("'me' in owners")
            case .sharedWithMe:
                qParamParts.append("sharedWithMe")
            default:
                break
            }
            addQueryItem(GoogleDriveAPI.Keys.q, qParamParts.joined(separator: " and "))

            if let nextPageToken {
                addQueryItem(GoogleDriveAPI.Keys.pageToken, nextPageToken)
            }
        case .itemInfo:
            urlComponents.path = "/drive/v3/files/\(id)"
            addQueryItem(GoogleDriveAPI.Keys.supportsAllDrives, "true")
            addQueryItem(GoogleDriveAPI.Keys.fields, GoogleDriveAPI.fileFields)
        case .content:
            urlComponents.path = "/drive/v3/files/\(id)"
            addQueryItem(GoogleDriveAPI.Keys.alt, "media")
        case .update:
            urlComponents.path = "/upload/drive/v3/files/\(id)"
            addQueryItem(GoogleDriveAPI.Keys.uploadType, "media")
        case .create:
            assert(isFolder, "Parent item is a file, cannot create a subfile.")
            urlComponents.path = "/drive/v3/files/"
        }
        addQueryItem(GoogleDriveAPI.Keys.supportsAllDrives, "true")
        return urlComponents.url!
    }
}
