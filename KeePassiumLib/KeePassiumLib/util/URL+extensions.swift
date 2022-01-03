//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
    static func from(malformedString: String, defaultScheme: String = "https") -> URL? {
        guard var urlComponents = URLComponents(string: malformedString),
              let urlHost = urlComponents.host,
              urlHost.isNotEmpty
        else {
            return nil
        }
        
        if let urlScheme = urlComponents.scheme {
            if urlScheme == "otpauth" || urlScheme == "mailto" {
                return nil
            }
            return urlComponents.url
        } else {
            urlComponents.scheme = defaultScheme
            return urlComponents.url
        }
    }
}


fileprivate let urlSchemeSeparator: Character = "+"

public extension URL {
    var schemePrefix: String? {
        guard let scheme = self.scheme else {
            return nil
        }
        let schemeParts = scheme.split(separator: urlSchemeSeparator)
        guard schemeParts.count > 1,
              let prefix = schemeParts.first
        else {
            return nil
        }
        return String(prefix)
    }
    
    var schemeWithoutPrefix: String? {
        if let mainScheme = self.scheme?
            .split(separator: urlSchemeSeparator, maxSplits: 1)
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
           let _mainScheme = scheme.split(separator: urlSchemeSeparator, maxSplits: 1).last
        {
            mainScheme = String(_mainScheme)
        }
        if let prefix = prefix {
            components.scheme = prefix + String(urlSchemeSeparator) + mainScheme
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
}
