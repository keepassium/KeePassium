//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Group: Eraseable {
    public static let defaultIconID = IconID.folder
    public static let defaultOpenIconID = IconID.folderOpen
    
    public weak var database: Database?
    public weak var parent: Group?
    public var uuid: UUID
    public var iconID: IconID
    public var name: String
    public var notes: String
    public internal(set) var creationTime: Date
    public internal(set) var lastModificationTime: Date
    public internal(set) var lastAccessTime: Date
    public var expiryTime: Date
    public var canExpire: Bool
    public var isExpired: Bool {
        return canExpire && Date() > expiryTime
    }
    public var isDeleted: Bool
    
    private var isChildrenModified: Bool
    public var groups = [Group]()
    public var entries = [Entry]()
    
    public var isRoot: Bool { return database?.root === self }

    public func isNameReserved(name: String) -> Bool {
        return false
    }

    init(database: Database?) {
        self.database = database
        parent = nil
        
        uuid = UUID.ZERO
        iconID = Group.defaultIconID
        name = ""
        notes = ""
        isChildrenModified = true
        canExpire = false
        isDeleted = false
        groups = []
        entries = []

        let now = Date()
        creationTime = now
        lastModificationTime = now
        lastAccessTime = now
        expiryTime = now
    }
    deinit {
        erase()
    }
    public func erase() {
        entries.removeAll() 
        groups.removeAll() 

        uuid = UUID.ZERO
        iconID = Group.defaultIconID
        name.erase()
        notes.erase()
        isChildrenModified = true
        canExpire = false
        isDeleted = false
        
        parent = nil

        let now = Date()
        creationTime = now
        lastModificationTime = now
        lastAccessTime = now
        expiryTime = now
    }
    
    public func clone() -> Group {
        fatalError("Pure virtual method")
    }
    
    public func apply(to target: Group) {
        target.uuid = uuid
        target.iconID = iconID
        target.name = name
        target.notes = notes
        target.canExpire = canExpire
        target.isDeleted = isDeleted
        
        
        target.creationTime = creationTime
        target.lastModificationTime = lastModificationTime
        target.lastAccessTime = lastAccessTime
        target.expiryTime = expiryTime
    }
    
    public func count(includeGroups: Bool = true, includeEntries: Bool = true) {
        var result = 0
        if includeGroups {
            result += groups.count
        }
        if includeEntries {
            result += entries.count
        }
    }
    
    public func add(group: Group) {
        group.parent = self
        groups.append(group)
        isChildrenModified = true
    }
    
    public func remove(group: Group) {
        guard group.parent === self else {
            return
        }
        groups.remove(group)
        group.parent = nil
        isChildrenModified = true
    }
    
    public func add(entry: Entry) {
        entry.parent = self
        entry.isDeleted = self.isDeleted
        entries.append(entry)
        isChildrenModified = true
    }
    
    public func remove(entry: Entry) {
        guard entry.parent === self else {
            return
        }
        entries.remove(entry)
        entry.parent = nil
        isChildrenModified = true
    }

    public func moveEntry(entry: Entry) {
        if let oldParent = entry.parent {
            oldParent.remove(entry: entry)
        }
        self.add(entry: entry)
    }

    public func findGroup(byUUID uuid: UUID) -> Group? {
        if self.uuid == uuid {
            return self
        }
        for group in groups {
            if let result = group.findGroup(byUUID: uuid) {
                return result
            }
        }
        return nil
    }

    public func createEntry() -> Entry {
        fatalError("Pure virtual method")
    }
    
    public func createGroup() -> Group {
        fatalError("Pure virtual method")
    }
    
    public func accessed() {
        lastAccessTime = Date.now
    }
    public func modified() {
        accessed()
        lastModificationTime = Date.now
    }

    public func collectAllChildren(groups: inout Array<Group>, entries: inout Array<Entry>) {
        for group in self.groups {
            groups.append(group)
            group.collectAllChildren(groups: &groups, entries: &entries)
        }
        entries.append(contentsOf: self.entries)
    }
    
    public func collectAllEntries(to entries: inout Array<Entry>) {
        for group in self.groups {
            group.collectAllEntries(to: &entries)
        }
        entries.append(contentsOf: self.entries)
    }
    
    public func filterEntries(query: SearchQuery, result: inout Array<Entry>) {
        if self.isDeleted && !query.includeDeleted {
            return
        }
        
        if query.includeSubgroups {
            for group in groups {
                group.filterEntries(query: query, result: &result)
            }
        }
        
        for entry in entries {
            if entry.matches(query: query) {
                result.append(entry)
            }
        }
    }
}

extension Array where Element == Group {
    mutating func remove(_ group: Group) {
        if let index = index(where: {$0 === group}) {
            remove(at: index)
        }
    }
}


