//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension URL {
    var isDropboxFileURL: Bool {
        return self.scheme == DropboxURLHelper.prefixedScheme
    }

    func getDropboxLocationDescription() -> String? {
        guard isDropboxFileURL else {
            return nil
        }
        return DropboxURLHelper.getDescription(for: self)
    }
}

public enum DropboxURLHelper {
    public static let schemePrefix = "keepassium"
    public static let scheme = "dropbox"
    public static let prefixedScheme = schemePrefix + String(urlSchemePrefixSeparator) + scheme

    private enum Key {
        static let name = "name"
        static let accountId = "accountId"
        static let email = "email"
        static let type = "type"
    }

    static func build(from item: DropboxItem) -> URL {
        let queryItems = [
            URLQueryItem(name: Key.name, value: item.name),
            URLQueryItem(name: Key.accountId, value: item.info.accountId),
            URLQueryItem(name: Key.email, value: item.info.email),
            URLQueryItem(name: Key.type, value: item.info.type.rawValue)
        ]
        let result = URL.build(
            schemePrefix: schemePrefix,
            scheme: scheme,
            host: "dropbox",
            path: item.pathDisplay,
            queryItems: queryItems
        )
        return result
    }

    public static func urlToItem(_ prefixedURL: URL) -> DropboxItem? {
        guard prefixedURL.isDropboxFileURL else {
            Diag.error("Not an Dropbox URL, cancelling")
            assertionFailure()
            return nil
        }
        let queryItems = prefixedURL.queryItems
        guard let name = queryItems[Key.name] else {
            Diag.error("File name is missing, cancelling")
            assertionFailure()
            return nil
        }
        let path: String = prefixedURL.path
        guard path.isNotEmpty else {
            Diag.error("Item path is empty, cancelling")
            assertionFailure()
            return nil
        }
        guard let accountId = queryItems[Key.accountId],
              let email = queryItems[Key.email],
              let type = DropboxAccountInfo.AccountType.from(queryItems[Key.type])
        else {
            Diag.error("Item info account id or email or type is empty, cancelling")
            assertionFailure()
            return nil
        }
        return DropboxItem(
            name: name,
            isFolder: prefixedURL.hasDirectoryPath,
            pathDisplay: path,
            info: DropboxAccountInfo(accountId: accountId, email: email, type: type)
        )
    }

    static func getDescription(for prefixedURL: URL) -> String? {
        let queryItems = prefixedURL.queryItems
        let accountType = DropboxAccountInfo.AccountType.from(queryItems[Key.type])
        let serviceName = accountType?.description ?? LString.connectionTypeDropbox
        let path = prefixedURL.relativePath
        let email = queryItems[Key.email] ?? "?"
        return "\(serviceName) (\(email)) → \(path)"
    }
}

extension DropboxItem {
    public static func fromURL(_ prefixedURL: URL) -> DropboxItem? {
        return DropboxURLHelper.urlToItem(prefixedURL)
    }

    public func toURL() -> URL {
        return DropboxURLHelper.build(from: self)
    }
}
