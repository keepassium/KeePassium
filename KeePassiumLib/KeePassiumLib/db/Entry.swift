//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class EntryField: Eraseable {
    public static let title    = "Title"
    public static let userName = "UserName"
    public static let password = "Password"
    public static let url      = "URL"
    public static let notes    = "Notes"
    public static let standardNames = [title, userName, password, url, notes]
    
    public static let totp = "TOTP"
    public static let otp = "otp"

    public var name: String
    public var value: String {
        didSet {
            resolvedValueInternal = value
        }
    }
    public var isProtected: Bool
    
    internal var resolvedValueInternal: String?
    
    public var resolvedValue: String {
        guard resolvedValueInternal != nil else {
            assertionFailure()
            return value
        }
        return resolvedValueInternal!
    }
    
    private(set) public var resolveStatus = EntryFieldReference.ResolveStatus.noReferences
    
    public var hasReferences: Bool {
        return resolveStatus != .noReferences
    }
    
    public var isStandardField: Bool {
        return EntryField.isStandardName(name: self.name)
    }
    public static func isStandardName(name: String) -> Bool {
        return standardNames.contains(name)
    }
    
    public convenience init(name: String, value: String, isProtected: Bool) {
        self.init(
            name: name,
            value: value,
            isProtected: isProtected,
            resolvedValue: value,  
            resolveStatus: .noReferences
        )
    }
    
    internal init(
        name: String,
        value: String,
        isProtected: Bool,
        resolvedValue: String?,
        resolveStatus: EntryFieldReference.ResolveStatus
    ) {
        self.name = name
        self.value = value
        self.isProtected = isProtected
        self.resolvedValueInternal = resolvedValue
        self.resolveStatus = resolveStatus
    }
    
    deinit {
        erase()
    }
    
    public func clone() -> EntryField {
        let clone = EntryField(
            name: name,
            value: value,
            isProtected: isProtected,
            resolvedValue: resolvedValue,
            resolveStatus: resolveStatus
        )
        return clone
    }
    
    public func erase() {
        name.erase()
        value.erase()
        isProtected = false

        resolvedValueInternal?.erase()
        resolvedValueInternal = nil
        resolveStatus = .noReferences
    }
    
    public func contains(
        word: Substring,
        includeFieldNames: Bool,
        includeProtectedValues: Bool,
        options: String.CompareOptions
    ) -> Bool {
        guard name != EntryField.password else { return false } 
        
        if includeFieldNames
            && !isStandardField
            && name.localizedContains(word, options: options)
        {
            return true
        }
        
        let includeFieldValue = !isProtected || includeProtectedValues
        if includeFieldValue {
            return resolvedValue.localizedContains(word, options: options)
        }
        return false
    }
    
    @discardableResult
    public func resolveReferences<T>(entries: T, maxDepth: Int = 3) -> String
        where T: Collection, T.Element: Entry
    {
        guard resolvedValueInternal == nil else {
            return resolvedValueInternal!
        }
        
        var _resolvedValue = value
        let status = EntryFieldReference.resolveReferences(
            in: value,
            entries: entries,
            maxDepth: maxDepth,
            resolvedValue: &_resolvedValue
        )
        resolveStatus = status
        resolvedValueInternal = _resolvedValue
        return _resolvedValue
    }
    
    public func unresolveReferences() {
        resolvedValueInternal = nil
        resolveStatus = .noReferences
    }
}

public class Entry: DatabaseItem, Eraseable {
    public static let defaultIconID = IconID.key
    
    public weak var database: Database?
    public var uuid: UUID
    public var iconID: IconID

    public var fields: [EntryField]
    public var isSupportsExtraFields: Bool { get { return false } }
    public var isSupportsMultipleAttachments: Bool { return false }

    public var rawTitle: String {
        get{ return getField(EntryField.title)?.value ?? "" }
        set { setField(name: EntryField.title, value: newValue) }
    }
    public var resolvedTitle: String {
        get{ return getField(EntryField.title)?.resolvedValue ?? "" }
    }

    public var rawUserName: String {
        get{ return getField(EntryField.userName)?.value ?? "" }
        set { setField(name: EntryField.userName, value: newValue) }
    }
    public var resolvedUserName: String {
        get{ return getField(EntryField.userName)?.resolvedValue ?? "" }
    }

    public var rawPassword: String {
        get{ return getField(EntryField.password)?.value ?? "" }
        set { setField(name: EntryField.password, value: newValue) }
    }
    public var resolvedPassword: String {
        get{ return getField(EntryField.password)?.resolvedValue ?? "" }
    }

    public var rawURL: String {
        get{ return getField(EntryField.url)?.value ?? "" }
        set { setField(name: EntryField.url, value: newValue) }
    }
    public var resolvedURL: String {
        get{ return getField(EntryField.url)?.resolvedValue ?? "" }
    }

    public var rawNotes: String {
        get{ return getField(EntryField.notes)?.value ?? "" }
        set { setField(name: EntryField.notes, value: newValue) }
    }
    public var resolvedNotes: String {
        get{ return getField(EntryField.notes)?.resolvedValue ?? "" }
    }
    
    public internal(set) var creationTime: Date
    public internal(set) var lastModificationTime: Date
    public internal(set) var lastAccessTime: Date
    public var expiryTime: Date
    public var canExpire: Bool {
        get { return false }
        set { /* ignored */ }
    }
    public var isExpired: Bool { return canExpire && (Date() > expiryTime) }
    public var isDeleted: Bool
    
    public var attachments: Array<Attachment>
    
    public var description: String { return "Entry[\(rawTitle)]" }
    
    init(database: Database?) {
        self.database = database
        attachments = []
        fields = []

        uuid = UUID.ZERO
        iconID = Entry.defaultIconID
        isDeleted = false
        
        let now = Date()
        creationTime = now
        lastModificationTime = now
        lastAccessTime = now
        expiryTime = now
        
        super.init()
        
        canExpire = false
        populateStandardFields()
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        attachments.erase()
        fields.erase()
        populateStandardFields()
        
        uuid = UUID.ZERO
        iconID = Entry.defaultIconID
        isDeleted = false
        canExpire = false

        parent = nil

        let now = Date()
        creationTime = now
        lastModificationTime = now
        lastAccessTime = now
        expiryTime = now
    }
    
    func makeEntryField(name: String, value: String, isProtected: Bool) -> EntryField {
        return EntryField(
            name: name,
            value: value,
            isProtected: isProtected,
            resolvedValue: value, 
            resolveStatus: .noReferences)
    }
    
    public func populateStandardFields() {
        setField(name: EntryField.title, value: "")
        setField(name: EntryField.userName, value: "")
        setField(name: EntryField.password, value: "", isProtected: true)
        setField(name: EntryField.url, value: "")
        setField(name: EntryField.notes, value: "")
    }
    
    public func setField(name: String, value: String, isProtected: Bool? = nil) {
        if let field = fields.first { $0.name == name } {
            field.value = value
            if let isProtected = isProtected {
                field.isProtected = isProtected
            } else {
            }
            return
        }

        fields.append(makeEntryField(name: name, value: value, isProtected: isProtected ?? false))
    }

    public func getField<T: StringProtocol>(_ name: T) -> EntryField? {
        return fields.first(where: {
            $0.name.compare(name) == .orderedSame
        })
    }
    
    public func removeField(_ field: EntryField) {
        if let index = fields.firstIndex(where: {$0 === field}) {
            fields.remove(at: index)
        }
    }

    public func clone(makeNewUUID: Bool) -> Entry {
        fatalError("Pure virtual method")
    }
    
    public func apply(to target: Entry, makeNewUUID: Bool) {
        if makeNewUUID {
            target.uuid = UUID()
        } else {
            target.uuid = uuid
        }
        target.iconID = iconID
        target.isDeleted = isDeleted
        target.lastModificationTime = lastModificationTime
        target.creationTime = creationTime
        target.lastAccessTime = lastAccessTime
        target.expiryTime = expiryTime
        target.canExpire = canExpire
        
        target.attachments.removeAll()
        for att in attachments {
            target.attachments.append(att.clone())
        }
        target.fields.removeAll()
        for field in fields {
            target.fields.append(field.clone())
        }
    }
    
    public func backupState() {
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
    
    public func deleteWithoutBackup() {
        parent?.remove(entry: self)
    }
    
    public func move(to newGroup: Group) {
        guard newGroup !== parent else { return }
        parent?.remove(entry: self)
        newGroup.add(entry: self)
    }
    
    public func getGroupPath() -> String {
        var groupNames = Array<String>()
        var parentGroup = self.parent
        while parentGroup != nil {
            let parentGroupUnwrapped = parentGroup! 
            groupNames.append(parentGroupUnwrapped.name)
            parentGroup = parentGroupUnwrapped.parent
        }
        return groupNames.reversed().joined(separator: "/")
    }
    
    public func matches(query: SearchQuery) -> Bool {
        for word in query.textWords {
            var wordFound = false
            for field in fields {
                wordFound = field.contains(
                    word: word,
                    includeFieldNames: query.includeFieldNames,
                    includeProtectedValues: query.includeProtectedValues,
                    options: query.compareOptions)
                if wordFound {
                    break
                }
            }
            if wordFound {
                continue
            }

            for att in attachments {
                if att.name.localizedContains(word, options: query.compareOptions) {
                    wordFound = true
                    break
                }
            }
            if !wordFound {
                return false
            }
        }
        return true
    }
}


extension Array where Element == Entry {
    mutating func remove(_ entry: Entry) {
        if let index = firstIndex(where: {$0 === entry}) {
            remove(at: index)
        }
    }
}
