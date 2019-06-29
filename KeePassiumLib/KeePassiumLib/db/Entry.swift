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

    public var name: String
    public var value: String
    public var isProtected: Bool
    public var isStandardField: Bool {
        return EntryField.isStandardName(name: self.name)
    }
    public static func isStandardName(name: String) -> Bool {
        return standardNames.contains(name)
    }
    
    public init(name: String, value: String, isProtected: Bool) {
        self.name = name
        self.value = value
        self.isProtected = isProtected
    }
    deinit {
        erase()
    }
    
    public func clone() -> EntryField {
        return EntryField(name: self.name, value: self.value, isProtected: self.isProtected)
    }
    
    public func erase() {
        name.erase()
        value.erase()
        isProtected = false
    }
    
    public func matches(query: SearchQuery) -> Bool {
        if name.localizedCaseInsensitiveContains(query.text) {
            return true
        }
        if !isProtected && value.localizedCaseInsensitiveContains(query.text) {
            return true
        }
        return false
    }
}

public class Entry: Eraseable {
    public static let defaultIconID = IconID.key
    
    public weak var database: Database?
    public weak var parent: Group?
    public var uuid: UUID
    public var iconID: IconID

    public var fields: [EntryField]
    public var isSupportsExtraFields: Bool { get { return false } }
    public var isSupportsMultipleAttachments: Bool { return false }

    public var title: String    {
        get{ return getField(with: EntryField.title)?.value ?? "" }
        set { setField(name: EntryField.title, value: newValue) }
    }
    public var userName: String {
        get{ return getField(with: EntryField.userName)?.value ?? "" }
        set { setField(name: EntryField.userName, value: newValue) }
    }
    public var password: String {
        get{ return getField(with: EntryField.password)?.value ?? "" }
        set { setField(name: EntryField.password, value: newValue) }
    }
    public var url: String {
        get{ return getField(with: EntryField.url)?.value ?? "" }
        set { setField(name: EntryField.url, value: newValue) }
    }
    public var notes: String {
        get{ return getField(with: EntryField.notes)?.value ?? "" }
        set { setField(name: EntryField.notes, value: newValue) }
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
    
    public var description: String { return "Entry[\(title)]" }
    
    init(database: Database?) {
        self.database = database
        parent = nil
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
        return EntryField(name: name, value: value, isProtected: isProtected)
    }
    
    public func populateStandardFields() {
        setField(name: EntryField.title, value: "")
        setField(name: EntryField.userName, value: "")
        setField(name: EntryField.password, value: "", isProtected: true)
        setField(name: EntryField.url, value: "")
        setField(name: EntryField.notes, value: "")
    }
    
    public func setField(name: String, value: String, isProtected: Bool? = nil) {
        for field in fields {
            if field.name == name {
                field.value = value
                if let isProtected = isProtected {
                    field.isProtected = isProtected
                } else {
                }
                return
            }
        }
        fields.append(makeEntryField(name: name, value: value, isProtected: isProtected ?? false))
    }

    public func getField(with name: String) -> EntryField? {
        for field in fields {
            if field.name == name {
                return field
            }
        }
        return nil
    }
    
    public func removeField(_ field: EntryField) {
        if let index = fields.index(where: {$0 === field}) {
            fields.remove(at: index)
        }
    }

    public func clone() -> Entry {
        fatalError("Pure virtual method")
    }
    
    public func apply(to target: Entry) {
        target.uuid = uuid
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
    
    public func accessed() {
        lastAccessTime = Date.now
    }
    public func modified() {
        accessed()
        lastModificationTime = Date.now
    }
    
    public func deleteWithoutBackup() {
        parent?.remove(entry: self)
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
            if title.contains(word) || userName.contains(word) || url.contains(word) || notes.contains(word) {
                continue
            }
            var wordFound = false
            for att in attachments {
                if att.name.contains(word) {
                    wordFound = true
                    break
                }
            }
            if !wordFound { return false }
        }
        return true
    }
}


extension Array where Element == Entry {
    mutating func remove(_ entry: Entry) {
        if let index = index(where: {$0 === entry}) {
            remove(at: index)
        }
    }
}

