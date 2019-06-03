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
    public var hasError: Bool { return errorMessage != nil}
    public var errorMessage: String?
    
    public var fileSize: Int64?
    public var creationDate: Date?
    public var modificationDate: Date?
}

public class URLReference: Equatable, Codable {

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
                return NSLocalizedString("Local (in-app copy)", comment: "Human-readable file location. 'Local' means the file is inside app sandbox.")
            case .internalInbox:
                return NSLocalizedString("Local (in-app copy): Inbox", comment: "Human-readable file location. 'Local' means the file is inside app sandbox.")
            case .internalBackup:
                return NSLocalizedString("Local (in-app copy): Backup", comment: "Human-readable file location. 'Local' means the file is inside app sandbox.")
            case .external:
                return NSLocalizedString("Another App / Cloud Storage", comment: "Human-readable file location. The file is situated in some other app or in cloud storage.")
            }
        }
    }
    
    private let data: Data
    lazy private(set) var hash: ByteArray = CryptoManager.sha256(of: ByteArray(data: data))
    public let location: Location
    
    private enum CodingKeys: String, CodingKey {
        case data = "data"
        case location = "location"
    }
    
    public init(from url: URL, location: Location) throws {
        let resourceKeys = Set<URLResourceKey>(
            [.canonicalPathKey, .nameKey, .fileSizeKey,
            .creationDateKey, .contentModificationDateKey]
        )
        data = try url.bookmarkData(
            options: [], 
            includingResourceValuesForKeys: resourceKeys,
            relativeTo: nil) 
        self.location = location
    }

    public static func == (lhs: URLReference, rhs: URLReference) -> Bool {
        guard lhs.location == rhs.location else { return false }
        if lhs.location.isInternal {
            guard let leftURL = try? lhs.resolve(),
                let rightURL = try? rhs.resolve() else { return false }
            return leftURL == rightURL
        } else {
            return lhs.hash == rhs.hash
        }
    }
    
    public func serialize() -> Data {
        return try! JSONEncoder().encode(self)
    }
    public static func deserialize(from data: Data) -> URLReference? {
        return try? JSONDecoder().decode(URLReference.self, from: data)
    }
    
    public func resolve() throws -> URL {
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        return url
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
                errorMessage: nil,
                fileSize: url.fileSize,
                creationDate: url.fileCreationDate,
                modificationDate: url.fileModificationDate)
        } catch {
            result = FileInfo(
                fileName: "?",
                errorMessage: error.localizedDescription,
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
