//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import CryptoKit
import Foundation

public extension URL {
    var isDirectory: Bool {
        let res = try? resourceValues(forKeys: [.isDirectoryKey])
        return res?.isDirectory ?? false
    }

    var isRemoteURL: Bool { !isFileURL }

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

    func getFileAttribute(_ attribute: FileInfo.Attribute) -> Bool? {
        assert(isFileURL)
        let res = try? resourceValues(forKeys: [attribute.asURLResourceKey])
        return attribute.fromURLResourceValues(res)
    }

    @discardableResult
    mutating func setFileAttribute(_ attribute: FileInfo.Attribute, to value: Bool) -> Bool {
        assert(isFileURL)
        var resourceValues = URLResourceValues()
        attribute.apply(value, to: &resourceValues)
        do {
            try setResourceValues(resourceValues)
            guard let newValue = getFileAttribute(attribute),
                  newValue == value
            else {
                Diag.warning("Failed to change attribute, the change did not last. [attr: \(attribute)]")
                return false
            }
            return true
        } catch {
            Diag.warning("Failed to change attribute [attr: \(attribute), reason: \(error.localizedDescription)]")
            return false
        }
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
            .isHiddenKey
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
            let fileAccessError = FileAccessError.make(
                from: error,
                fileName: self.lastPathComponent,
                fileProvider: FileProvider.find(for: self))
            completionQueue.addOperation {
                completion(.failure(fileAccessError))
            }
            return
        }

        let contentHash = try? FileHasher.sha256(fileURL: self).asHexString
        let latestInfo = FileInfo(
            fileName: targetURL.lastPathComponent,
            fileSize: Int64(attributes.fileSize ?? -1),
            creationDate: attributes.creationDate,
            modificationDate: attributes.contentModificationDate,
            attributes: [
                .excludedFromBackup: attributes.isExcludedFromBackup,
                .hidden: attributes.isHidden
            ],
            isInTrash: self.isInTrashDirectory,
            hash: contentHash
        )
        completionQueue.addOperation {
            completion(.success(latestInfo))
        }
    }
}

public extension URL {
    private static let sensitiveQueryParams = ["email", "owner"]
    private static let redactedValue = "_redacted_"

    var redacted: URL {
        let isDirectory = self.isDirectory
        let redactedPathURL = self.deletingLastPathComponent()
            .appendingPathComponent(Self.redactedValue, isDirectory: isDirectory)

        guard var components = URLComponents(url: redactedPathURL, resolvingAgainstBaseURL: false) else {
            return redactedPathURL
        }
        let originalQueryItems = components.queryItems
        components.queryItems = originalQueryItems?.compactMap {
            if Self.sensitiveQueryParams.contains($0.name) {
                return URLQueryItem(name: $0.name, value: Self.redactedValue)
            } else {
                return $0
            }
        }
        return components.url ?? redactedPathURL
    }
}

public extension URL {
    private static let commonSchemePrefixes = ["https://", "http://", "otpauth://"]
    private static let assumedSchemePrefix = "https://"

    static func from(malformedString input: String) -> URL? {
        let hasScheme = URL.commonSchemePrefixes.contains(where: { input.starts(with: $0) })
        let inputString = hasScheme ? input : URL.assumedSchemePrefix + input

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
        } else if isOneDrivePersonalFileURL || isOneDriveBusinessFileURL {
            return self.getOneDriveLocationDescription()
        } else if isDropboxFileURL {
            return self.getDropboxLocationDescription()
        } else if isGoogleDriveFileURL {
            return self.getGoogleDriveLocationDescription()
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
