//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public struct FileInfo {
    public var fileName: String
    public var hasError: Bool { return error != nil}
    public var errorMessage: String? { return error?.localizedDescription }
    public var error: Error?

    public var hasPermissionError257: Bool {
        guard let nsError = error as NSError? else { return false }
        return (nsError.domain == "NSCocoaErrorDomain") && (nsError.code == 257)
    }

    public var fileSize: Int64?
    public var creationDate: Date?
    public var modificationDate: Date?
}

public class URLReference: Equatable, Codable, CustomDebugStringConvertible {
    public typealias Descriptor = String
    
    public enum Location: Int, Codable, CustomStringConvertible {
        public static let allValues: [Location] =
            [.internalDocuments, .internalBackup, .internalInbox, .external]
        
        public static let allInternal: [Location] =
            [.internalDocuments, .internalBackup, .internalInbox]
        
        case internalDocuments = 0
        case internalBackup = 1
        case internalInbox = 2
        case external = 100
        
        public var isInternal: Bool {
            return self != .external
        }
        
        public var description: String {
            switch self {
            case .internalDocuments:
                return NSLocalizedString(
                    "[URLReference/Location] Local copy",
                    bundle: Bundle.framework,
                    value: "Local copy",
                    comment: "Human-readable file location: the file is on device, inside the app sandbox. Example: 'File Location: Local copy'")
            case .internalInbox:
                return NSLocalizedString(
                    "[URLReference/Location] Internal inbox",
                    bundle: Bundle.framework,
                    value: "Internal inbox",
                    comment: "Human-readable file location: the file is on device, inside the app sandbox. 'Inbox' is a special directory for files that are being imported. Can be also 'Internal import'. Example: 'File Location: Internal inbox'")
            case .internalBackup:
                return NSLocalizedString(
                    "[URLReference/Location] Internal backup",
                    bundle: Bundle.framework,
                    value: "Internal backup",
                    comment: "Human-readable file location: the file is on device, inside the app sandbox. 'Backup' is a dedicated directory for database backup files. Example: 'File Location: Internal backup'")
            case .external:
                return NSLocalizedString(
                    "[URLReference/Location] Cloud storage / Another app",
                    bundle: Bundle.framework,
                    value: "Cloud storage / Another app",
                    comment: "Human-readable file location. The file is situated either online / in cloud storage, or on the same device, but in some other app. Example: 'File Location: Cloud storage / Another app'")
            }
        }
    }
    
    private let data: Data
    lazy private(set) var hash: ByteArray = getHash()
    public let location: Location
    private var url: URL?
    
    private enum CodingKeys: String, CodingKey {
        case data = "data"
        case location = "location"
        case url = "url"
    }
    
    public init(from url: URL, location: Location) throws {
        let isAccessed = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        self.url = url
        self.location = location
        if location.isInternal {
            data = Data() 
            hash = ByteArray(data: url.dataRepresentation).sha256
        } else {
            data = try url.bookmarkData(
                options: [.minimalBookmark],
                includingResourceValuesForKeys: nil,
                relativeTo: nil) 
            hash = ByteArray(data: data).sha256
        }
    }

    public static func == (lhs: URLReference, rhs: URLReference) -> Bool {
        guard lhs.location == rhs.location else { return false }
        if lhs.location.isInternal {
            guard let leftURL = try? lhs.resolve(),
                let rightURL = try? rhs.resolve() else { return false }
            return leftURL == rightURL
        } else {
            return !lhs.hash.isEmpty && (lhs.hash == rhs.hash)
        }
    }
    
    public func serialize() -> Data {
        return try! JSONEncoder().encode(self)
    }
    public static func deserialize(from data: Data) -> URLReference? {
        guard let ref = try? JSONDecoder().decode(URLReference.self, from: data) else {
            return nil
        }
        ref.hash = ref.getHash()
        return ref
    }
    
    public var debugDescription: String {
        return " ‣ Location: \(location)\n" +
            " ‣ URL: \(url?.relativeString ?? "nil")\n" +
            " ‣ data: \(data.count) bytes"
    }
    
    
    private func getHash() -> ByteArray {
        guard location.isInternal else {
            return ByteArray(data: data).sha256
        }

        do {
            let _url = try resolve()
            return ByteArray(data: _url.dataRepresentation).sha256
        } catch {
            Diag.warning("Failed to resolve the URL: \(error.localizedDescription)")
            return ByteArray() 
        }
    }
    
    public func resolve() throws -> URL {
        if let url = url, location.isInternal {
            return url
        }
        
        var isStale = false
        let resolvedUrl = try URL(
            resolvingBookmarkData: data,
            options: [URL.BookmarkResolutionOptions.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale)
        self.url = resolvedUrl
        return resolvedUrl
    }
    
    public func getDescriptor() -> Descriptor? {
        guard !info.hasError else {
            return nil
        }
        return info.fileName
    }
    
    public lazy var info: FileInfo = getInfo()
    
    public func getInfo() -> FileInfo {
        refreshInfo()
        return info
    }
    
    public func refreshInfo() {
        let result: FileInfo
        do {
            let url = try resolve()
            let isAccessed = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            result = FileInfo(
                fileName: url.lastPathComponent,
                error: nil,
                fileSize: url.fileSize,
                creationDate: url.fileCreationDate,
                modificationDate: url.fileModificationDate)
        } catch {
            result = FileInfo(
                fileName: "?",
                error: error,
                fileSize: nil,
                creationDate: nil,
                modificationDate: nil)
        }
        self.info = result
    }
    
    public func find(in refs: [URLReference], fallbackToNamesake: Bool=false) -> URLReference? {
        if let exactMatchIndex = refs.firstIndex(of: self) {
            return refs[exactMatchIndex]
        }
        if fallbackToNamesake {
            let fileName = self.info.fileName
            return refs.first(where: { $0.info.fileName == fileName })
        }
        return nil
    }
}
