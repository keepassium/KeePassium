//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension URL {
    var isDirectory: Bool {
        let res = try? resourceValues(forKeys: [.isDirectoryKey])
        return res?.isDirectory ?? false
    }

    var isRemoteURL: Bool { !isFileURL }

    var isExcludedFromBackup: Bool? {
        let res = try? resourceValues(forKeys: [.isExcludedFromBackupKey])
        return res?.isExcludedFromBackup
    }

    var isInTrashDirectory: Bool {
        do {
            let fileManager = FileManager.default
            var relationship = FileManager.URLRelationship.other
            try fileManager.getRelationship(&relationship, of: .trashDirectory, in: [], toItemAt: self)
            return relationship == .contains
        } catch {
            let isSimpleNameMatch = self.pathComponents.contains(".Trash")
            return isSimpleNameMatch
        }
    }

    @discardableResult
    mutating func setExcludedFromBackup(_ isExcluded: Bool) -> Bool {
        var values = URLResourceValues()
        values.isExcludedFromBackup = isExcluded
        do {
            try setResourceValues(values)
            if isExcludedFromBackup != nil && isExcludedFromBackup! == isExcluded {
                return true
            }
            Diag.warning("Failed to change backup attribute: the modification did not last.")
            return false
        } catch {
            Diag.warning("Failed to change backup attribute [reason: \(error.localizedDescription)]")
            return false
        }
    }

    var redacted: URL {
        let isDirectory = self.isDirectory
        return self.deletingLastPathComponent().appendingPathComponent("_redacted_", isDirectory: isDirectory)
    }

    func readLocalFileInfo(
        canUseCache: Bool,
        completionQueue: OperationQueue = .main,
        completion: @escaping ((Result<FileInfo, FileAccessError>) -> Void)
    ) {
        assert(!Thread.isMainThread)
        assert(self.isFileURL)
        let attributeKeys: Set<URLResourceKey> = [
            .fileSizeKey,
            .creationDateKey,
            .contentModificationDateKey,
            .isExcludedFromBackupKey,
        ]

        var targetURL = self
        if !canUseCache {
            targetURL.removeAllCachedResourceValues()
        }

        let attributes: URLResourceValues
        do {
            attributes = try targetURL.resourceValues(forKeys: attributeKeys)
        } catch {
            Diag.error("Failed to get file info [reason: \(error.localizedDescription)]")
            let fileAccessError = FileAccessError.systemError(error)
            completionQueue.addOperation {
                completion(.failure(fileAccessError))
            }
            return
        }

        let latestInfo = FileInfo(
            fileName: targetURL.lastPathComponent,
            fileSize: Int64(attributes.fileSize ?? -1),
            creationDate: attributes.creationDate,
            modificationDate: attributes.contentModificationDate,
            isExcludedFromBackup: attributes.isExcludedFromBackup ?? false,
            isInTrash: self.isInTrashDirectory)
        completionQueue.addOperation {
            completion(.success(latestInfo))
        }
    }
}

public extension URL {
    private static let commonSchemePrefixes = ["https://", "http://"]
    private static let defaultSchemePrefix = "https://"

    static func from(malformedString input: String) -> URL? {
        let hasScheme = URL.commonSchemePrefixes.contains(where: { input.starts(with: $0) })
        let inputString = hasScheme ? input : URL.defaultSchemePrefix + input

        guard let urlComponents = URLComponents(string: inputString),
              let urlHost = urlComponents.host,
              urlHost.isNotEmpty
        else {
            return nil
        }

        let urlScheme = urlComponents.scheme
        if urlScheme == "otpauth" || urlScheme == "mailto" {
            return nil
        }
        return urlComponents.url
    }
}


internal let urlSchemePrefixSeparator: Character = "+"

public extension URL {
    var schemePrefix: String? {
        guard let scheme = self.scheme else {
            return nil
        }
        let schemeParts = scheme.split(separator: urlSchemePrefixSeparator)
        guard schemeParts.count > 1,
              let prefix = schemeParts.first
        else {
            return nil
        }
        return String(prefix)
    }

    var schemeWithoutPrefix: String? {
        if let mainScheme = self.scheme?
            .split(separator: urlSchemePrefixSeparator, maxSplits: 1)
            .last
        {
            return String(mainScheme)
        }
        return nil
    }

    func withSchemePrefix(_ prefix: String?) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        var mainScheme: String = ""
        if let scheme = components.scheme,
           let _mainScheme = scheme.split(separator: urlSchemePrefixSeparator, maxSplits: 1).last
        {
            mainScheme = String(_mainScheme)
        }
        if let prefix = prefix {
            components.scheme = prefix + String(urlSchemePrefixSeparator) + mainScheme
        } else {
            components.scheme = mainScheme
        }
        return components.url!
    }

    func withoutSchemePrefix() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.scheme = self.schemeWithoutPrefix
        return components.url!
    }

    static func build(
        schemePrefix: String,
        scheme: String,
        host: String,
        path: String,
        queryItems: [URLQueryItem]?
    ) -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = [schemePrefix, scheme]
            .joined(separator: String(urlSchemePrefixSeparator))
        urlComponents.host = host
        urlComponents.path = path
        urlComponents.queryItems = queryItems
        return urlComponents.url!
    }
}

public extension URL {
    func getRemoteLocationDescription() -> String? {
        if isWebDAVFileURL {
            return WebDAVFileURL.getDescription(for: self)
        } else if isOneDriveFileURL {
            return self.getOneDriveLocationDescription()
        } else {
            assertionFailure("Description missing, remote location unknown?")
            return nil
        }
    }
}

public extension URL {
    /* Based on https://stackoverflow.com/a/38343753/1671985 */

    func getExtendedAttribute(name: String) throws -> ByteArray {
        let data = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in
            let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
            guard length >= 0 else {
                throw URL.posixError(errno)
            }

            var data = Data(count: length)

            let result = data.withUnsafeMutableBytes { [count = data.count] in
                getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
            }
            guard result >= 0 else {
                throw URL.posixError(errno)
            }
            return data
        }
        return ByteArray(data: data)
    }

    func setExtendedAttribute(name: String, value: ByteArray) throws {
        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = value.asData.withUnsafeBytes {
                setxattr(fileSystemPath, name, $0.baseAddress, value.count, 0, 0)
            }
            guard result >= 0 else {
                throw URL.posixError(errno)
            }
        }
    }

    private static func posixError(_ err: Int32) -> NSError {
        return NSError(domain: NSPOSIXErrorDomain, code: Int(err),
                       userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
    }
}

extension URL {
    public var queryItems: [String: String] {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems
        else {
            return [:]
        }
        return queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }
    }
}
