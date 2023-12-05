//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum WebDAVFileURL {
    public static let schemePrefix = "webdav"
    public static let schemes = ["http", "https"]
    public static let prefixedSchemes = [
        "webdav\(urlSchemePrefixSeparator)http",
        "webdav\(urlSchemePrefixSeparator)https"
    ]

    public static func build(nakedURL: URL) -> URL {
        let prefixedURL = nakedURL.withSchemePrefix(schemePrefix)
        return prefixedURL
    }

    internal static func getNakedURL(from prefixedURL: URL) -> URL {
        return prefixedURL.withoutSchemePrefix()
    }

    public static func getDescription(for prefixedURL: URL) -> String? {
        let urlString = getNakedURL(from: prefixedURL).absoluteString
        return "\(LString.connectionTypeWebDAV) → \(urlString)"
    }
}

internal extension URL {
    var isWebDAVFileURL: Bool {
        guard let scheme = self.scheme else {
            return false
        }
        return WebDAVFileURL.prefixedSchemes.contains(scheme)
    }
}
