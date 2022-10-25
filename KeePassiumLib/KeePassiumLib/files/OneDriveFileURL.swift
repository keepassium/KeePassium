//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public struct OneDriveFileURL {
    public static let schemePrefix = "keepassium"
    public static let scheme = "onedrive"
    public static let prefixedScheme = schemePrefix + String(urlSchemePrefixSeparator) + scheme

    public static func build(
        fileID: String,
        filePath: String,
        driveInfo: OneDriveDriveInfo
    ) -> URL {
        let result = URL.build(
            schemePrefix: schemePrefix,
            scheme: scheme,
            host: driveInfo.id,
            path: filePath,
            queryItems: [
                URLQueryItem(name: "fileID", value: fileID),
                URLQueryItem(name: "driveType", value: driveInfo.type.rawValue),
                URLQueryItem(name: "owner", value: driveInfo.ownerEmail),
            ]
        )
        return result
    }
    
    internal static func getFilePath(from prefixedURL: URL) -> String? {
        return prefixedURL.relativePath
    }
    
    public static func getDescription(for prefixedURL: URL) -> String? {
        let nakedURL = prefixedURL.withoutSchemePrefix()
        let urlComponents = URLComponents(url: nakedURL, resolvingAgainstBaseURL: true)
        let queryItems = urlComponents?.queryItems
        let path = prefixedURL.relativePath
        
        var serviceName = ""
        let owner = queryItems?.first(where: { $0.name == "owner"})?.value ?? "?"
        if let driveTypeRaw = queryItems?.first(where: { $0.name == "driveType"})?.value,
           let driveType = OneDriveDriveInfo.DriveType(rawValue: driveTypeRaw)
        {
            switch driveType {
            case .personal:
                serviceName = LString.connectionTypeOneDrive
                break
            case .business:
                serviceName = LString.connectionTypeOneDriveForBusiness
                break
            case .sharepoint:
                serviceName = LString.connectionTypeSharePoint
                break
            }
        }
        return "\(serviceName) (\(owner)) → \(path)"
    }
}

internal extension URL {
    var isOneDriveFileURL: Bool {
        return self.scheme == OneDriveFileURL.prefixedScheme
    }
}
