//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum DatabaseError: LocalizedError {
    case loadError(reason: String)
    case invalidKey
    case saveError(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .loadError:
            return NSLocalizedString("Cannot open database", comment: "Error message while opening a database")
        case .invalidKey:
            return NSLocalizedString("Invalid password or key file", comment: "Error message - the user provided wrong master key for decryption.")
        case .saveError:
            return NSLocalizedString("Cannot save database", comment: "Error message while saving a database")
        }
    }
    public var failureReason: String? {
        switch self {
        case .loadError(let reason):
            return reason
        case .saveError(let reason):
            return reason
        default:
            return nil
        }
    }
}

public struct SearchQuery {
    public var includeSubgroups: Bool
    public var includeDeleted: Bool
    public var text: String {
        didSet {
            textWords = text.split(separator: " ")
        }
    }
    public var textWords: Array<Substring>
    public init(
        includeSubgroups: Bool, includeDeleted: Bool, text: String, textWords: Array<Substring>)
    {
        self.includeSubgroups = includeSubgroups
        self.includeDeleted = includeDeleted
        self.text = text
        self.textWords = textWords
    }
}

public class DatabaseLoadingWarnings {
    public internal(set) var databaseGenerator: String?
    public internal(set) var messages: [String]
    
    public var isEmpty: Bool { return messages.isEmpty }
    
    internal init() {
        databaseGenerator = nil
        messages = []
    }
}

public protocol DatabaseProgressDelegate {
    func databaseProgressChanged(percent: Int)
}

open class Database: Eraseable {
    var filePath: String?
    
    public internal(set) var root: Group?

    public internal(set) var progress = ProgressEx()

    internal var compositeKey = SecureByteArray()
    
    public func initProgress() -> ProgressEx {
        progress = ProgressEx()
        return progress
    }
    
    public var keyHelper: KeyHelper {
        fatalError("Pure virtual method")
    }
    
    internal init() {
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        root?.erase()
        root = nil
        filePath?.erase()
        compositeKey.erase()
    }

    public class func isSignatureMatches(data: ByteArray) -> Bool {
        fatalError("Pure virtual method")
    }
    
    public func load(
        dbFileData: ByteArray,
        compositeKey: SecureByteArray,
        warnings: DatabaseLoadingWarnings
    ) throws {
        fatalError("Pure virtual method")
    }
    
    public func save() throws -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func changeCompositeKey(to newKey: SecureByteArray) {
        fatalError("Pure virtual method")
    }
    
    public func getBackupGroup(createIfMissing: Bool) -> Group? {
        fatalError("Pure virtual method")
    }
    
    public func count(includeGroups: Bool = true, includeEntries: Bool = true) -> Int {
        var result = 0
        if let root = self.root {
            var groups = Array<Group>()
            var entries = Array<Entry>()
            root.collectAllChildren(groups: &groups, entries: &entries)
            result += includeGroups ? groups.count : 0
            result += includeEntries ? entries.count : 0
        }
        return result
    }
    
    public func search(query: SearchQuery, result: inout Array<Entry>) -> Int {
        result.removeAll()
        root?.filterEntries(query: query, result: &result)
        return result.count
    }
    
    public func delete(group: Group) {
        fatalError("Pure virtual method")
    }
    
    public func delete(entry: Entry) {
        fatalError("Pure virtual method")
    }

    public func makeAttachment(name: String, data: ByteArray) -> Attachment {
        fatalError("Pure virtual method")
    }
}

