//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Group: DatabaseItem, Eraseable {
    public static let defaultIconID = IconID.folder
    public static let defaultOpenIconID = IconID.folderOpen
    
    public weak var database: Database?
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
    
    public var isIncludeEntriesInSearch: Bool {
        return true 
    }
    
    private var isChildrenModified: Bool
    public var groups = [Group]()
    public var entries = [Entry]()
    
    public var isRoot: Bool { return database?.root === self }

    public func isNameReserved(name: String) -> Bool {
        return false
    }

    init(database: Database?) {
        self.database = database
        
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
        
        super.init()
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
    
    public func clone(makeNewUUID: Bool) -> Group {
        fatalError("Pure virtual method")
    }
    
    public func deepClone(makeNewUUIDs: Bool) -> Group {
        let selfCopy = clone(makeNewUUID: makeNewUUIDs) 
        groups.forEach {
            let subgroupDeepCopy = $0.deepClone(makeNewUUIDs: makeNewUUIDs)
            selfCopy.add(group: subgroupDeepCopy)
        }
        entries.forEach {
            let entryClone = $0.clone(makeNewUUID: makeNewUUIDs)
            selfCopy.add(entry: entryClone)
        }
        return selfCopy
    }

    
    public func apply(to target: Group, makeNewUUID: Bool) {
        if makeNewUUID {
            target.uuid = UUID()
        } else {
            target.uuid = uuid
        }
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
        assert(group !== self)
        group.parent = self
        groups.append(group)
        group.deepSetDeleted(self.isDeleted)
        isChildrenModified = true
    }
    
    public func deepSetDeleted(_ isDeleted: Bool) {
        self.isDeleted = isDeleted
        groups.forEach { $0.deepSetDeleted(isDeleted) }
        entries.forEach { $0.isDeleted = isDeleted }
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
    
    public func move(to newGroup: Group) {
        guard parent !== newGroup else { return }
        parent?.remove(group: self)
        newGroup.add(group: self)
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

    public func createEntry(detached: Bool = false) -> Entry {
        fatalError("Pure virtual method")
    }
    
    public func createGroup(detached: Bool = false) -> Group {
        fatalError("Pure virtual method")
    }
    
    override public func touch(_ mode: DatabaseItem.TouchMode, updateParents: Bool = true) {
        lastAccessTime = Date.now
        if mode == .modified {
            lastModificationTime = Date.now
        }
        if updateParents {
            parent?.touch(mode, updateParents: true)
        }
    }

    public func collectAllChildren(groups: inout Array<Group>, entries: inout Array<Entry>) {
        for group in self.groups {
            groups.append(group)
            group.collectAllChildren(groups: &groups, entries: &entries)
        }
        entries.append(contentsOf: self.entries)
    }
    
    public func applyToAllChildren(groupHandler: ((Group)->Void)?, entryHandler: ((Entry)->Void)?) {
        groupHandler?(self)
        entries.forEach { entryHandler?($0) }
        groups.forEach {
            $0.applyToAllChildren(groupHandler: groupHandler, entryHandler: entryHandler)
        }
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
        
        guard isIncludeEntriesInSearch else {
            return
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
        if let index = firstIndex(where: {$0 === group}) {
            remove(at: index)
        }
    }
}


