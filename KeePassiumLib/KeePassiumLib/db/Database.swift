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
            return NSLocalizedString(
                "[DatabaseError] Cannot open database",
                bundle: Bundle.framework,
                value: "Cannot open database",
                comment: "Error message while opening a database")
        case .invalidKey:
            return NSLocalizedString(
                "[DatabaseError] Invalid password or key file",
                bundle: Bundle.framework,
                value: "Invalid password or key file",
                comment: "Error message: user provided a wrong master key for decryption.")
        case .saveError:
            return NSLocalizedString(
                "[DatabaseError] Cannot save database",
                bundle: Bundle.framework,
                value: "Cannot save database",
                comment: "Error message while saving a database")
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
    public let includeSubgroups: Bool
    public let includeDeleted: Bool
    public let includeFieldNames: Bool
    public let includeProtectedValues: Bool
    public let compareOptions: String.CompareOptions
    
    public let text: String
    public let textWords: Array<Substring>
    
    public init(
        includeSubgroups: Bool,
        includeDeleted: Bool,
        includeFieldNames: Bool,
        includeProtectedValues: Bool,
        compareOptions: String.CompareOptions,
        text: String,
        textWords: Array<Substring>)
    {
        self.includeSubgroups = includeSubgroups
        self.includeDeleted = includeDeleted
        self.includeFieldNames = includeFieldNames
        self.includeProtectedValues = includeProtectedValues
        self.compareOptions = compareOptions
        self.text = text
        self.textWords = text.split(separator: " ")
    }
}

public class DatabaseLoadingWarnings {
    public internal(set) var databaseGenerator: String?
    public internal(set) var messages: [String]
    
    public var isEmpty: Bool { return messages.isEmpty }
    
    public var isGeneratorImportant = false
    
    internal init() {
        databaseGenerator = nil
        messages = []
    }
}

open class Database: Eraseable {
    var filePath: String?
    
    public internal(set) var root: Group?

    public internal(set) var progress = ProgressEx()

    internal var compositeKey = CompositeKey.empty
    
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
        dbFileName: String,
        dbFileData: ByteArray,
        compositeKey: CompositeKey,
        warnings: DatabaseLoadingWarnings
    ) throws {
        fatalError("Pure virtual method")
    }
    
    public func save() throws -> ByteArray {
        fatalError("Pure virtual method")
    }
    
    public func changeCompositeKey(to newKey: CompositeKey) {
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
    
    internal func resolveReferences<T>(
        allEntries: T,
        parentProgress: ProgressEx,
        pendingProgressUnits: Int64)
        where T: Collection, T.Element: Entry
    {
        Diag.debug("Resolving references")
        
        let resolvingProgress = ProgressEx()
        resolvingProgress.totalUnitCount = Int64(allEntries.count)
        resolvingProgress.localizedDescription = LString.Progress.resolvingFieldReferences
        progress.addChild(resolvingProgress, withPendingUnitCount: pendingProgressUnits)
        
        allEntries.forEach { entry in
            entry.fields.forEach { field in
                field.unresolveReferences()
            }
        }
        
        var entriesProcessed = 0
        allEntries.forEach { entry in
            entry.fields.forEach { field in
                field.resolveReferences(entries: allEntries)
            }
            entriesProcessed += 1
            if entriesProcessed % 100 == 0 {
                resolvingProgress.completedUnitCount = Int64(entriesProcessed)
            }
        }
        resolvingProgress.completedUnitCount = resolvingProgress.totalUnitCount 
        Diag.debug("References resolved OK")
    }
}

