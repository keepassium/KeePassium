//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

typealias Group1ID = Int32

public class Group1: Group {
    private enum FieldID: UInt16 {
        case reserved  = 0x0000
        case groupID   = 0x0001
        case name      = 0x0002
        case creationTime     = 0x0003
        case lastModifiedTime = 0x0004
        case lastAccessTime   = 0x0005
        case expirationTime   = 0x0006
        case iconID           = 0x0007
        case groupLevel       = 0x0008
        case groupFlags       = 0x0009
        case end              = 0xFFFF
    }
    
    public static let backupGroupName = "Backup" 
    public static let backupGroupIconID = IconID.trashBin
    
    private(set)  var id: Group1ID
    internal var level: Int16
    private(set)  var flags: Int32 

    override public var canExpire: Bool {
        get { return expiryTime != Date.kp1Never }
        set {
            let never = Date.kp1Never
            if newValue {
                expiryTime = never - 1.0
            } else {
                expiryTime = never
            }
        }
    }
    
    override init(database: Database?) {
        id = -1
        level = 0
        flags = 0
        super.init(database: database)
        
        canExpire = false
    }
    
    deinit {
        erase()
    }
    
    override public func erase() {
        id = -1
        level = 0
        flags = 0
        super.erase()
        
        canExpire = false
    }
    
    override public func isNameReserved(name: String) -> Bool {
        return name == Group1.backupGroupName
    }
    
    override public func clone(makeNewUUID: Bool) -> Group {
        let copy = Group1(database: database)
        apply(to: copy, makeNewUUID: makeNewUUID)
        return copy
    }
    
    override public func apply(to target: Group, makeNewUUID: Bool) {
        super.apply(to: target, makeNewUUID: makeNewUUID)
        guard let targetGroup1 = target as? Group1 else {
            Diag.warning("Tried to apply group state to unexpected group class")
            assertionFailure()
            return
        }
        targetGroup1.id = id
        targetGroup1.level = level
        targetGroup1.flags = flags
    }
    
    override public func add(group: Group) {
        super.add(group: group)
        (group as! Group1).level = self.level + 1
    }
    override public func remove(group: Group) {
        super.remove(group: group)
        (group as! Group1).level = 0
    }
    override public func add(entry: Entry) {
        super.add(entry: entry)
        (entry as! Entry1).groupID = self.id
    }
    override public func remove(entry: Entry) {
        super.remove(entry: entry)
        (entry as! Entry1).groupID = -1
    }
    
    override public func createEntry(detached: Bool = false) -> Entry {
        let newEntry = Entry1(database: database)
        newEntry.uuid = UUID()
        
        if self.iconID != Group.defaultIconID && self.iconID != Group.defaultOpenIconID {
            newEntry.iconID = self.iconID
        }
        
        newEntry.isDeleted = isDeleted
        
        newEntry.creationTime = Date.now
        newEntry.lastAccessTime = Date.now
        newEntry.lastModificationTime = Date.now
        newEntry.expiryTime = Date.kp1Never
        
        newEntry.groupID = self.id
        if !detached {
            self.add(entry: newEntry)
        }
        return newEntry
    }
    
    override public func createGroup(detached: Bool = false) -> Group {
        let newGroup = Group1(database: database)
        newGroup.uuid = UUID()
        newGroup.flags = 0
        
        newGroup.id = (database as! Database1).createNewGroupID()
        
        newGroup.iconID = self.iconID
        newGroup.isDeleted = self.isDeleted
        
        newGroup.creationTime = Date.now
        newGroup.lastAccessTime = Date.now
        newGroup.lastModificationTime = Date.now
        newGroup.expiryTime = Date.kp1Never
        
        newGroup.level = self.level + 1
        if !detached {
            self.add(group: newGroup)
        }
        return newGroup
    }
    
    func load(from stream: ByteArray.InputStream) throws {
        Diag.verbose("Loading group")
        erase()
        
        while stream.hasBytesAvailable {
            guard let fieldIDraw = stream.readUInt16() else {
                throw Database1.FormatError.prematureDataEnd
            }
            guard let fieldID = FieldID(rawValue: fieldIDraw) else {
                throw Database1.FormatError.corruptedField(fieldName: "Group/FieldID")
            }
            guard let _fieldSize = stream.readInt32() else {
                throw Database1.FormatError.prematureDataEnd
            }
            guard _fieldSize >= 0 else {
                throw Database1.FormatError.corruptedField(fieldName: "Group/FieldSize")
            }
            let fieldSize = Int(_fieldSize)
            
            switch fieldID {
            case .reserved:
                _ = stream.read(count: fieldSize) 
            case .groupID:
                guard let _groupID: Group1ID = stream.readInt32() else {
                    throw Database1.FormatError.prematureDataEnd
                }
                self.id = _groupID
            case .name:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/Name")
                }
                self.name = string
            case .creationTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/CreationTime")
                }
                self.creationTime = date
            case .lastModifiedTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/LastModifiedTime")
                }
                self.lastModificationTime = date
            case .lastAccessTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/LastAccessTime")
                }
                self.lastAccessTime = date
            case .expirationTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/ExpirationTime")
                }
                self.expiryTime = date
            case .iconID:
                guard let iconIDraw = stream.readUInt32(),
                    let _iconID = IconID(rawValue: iconIDraw) else {
                        throw Database1.FormatError.corruptedField(fieldName: "Group/IconID")
                }
                self.iconID = _iconID
            case .groupLevel:
                guard let _level = stream.readUInt16() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/Level")
                }
                self.level = Int16(_level)
            case .groupFlags:
                guard let _flags = stream.readInt32() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Group/Flags")
                }
                self.flags = _flags
            case .end:
                guard let _ = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                if (level == 0) && (name == Group1.backupGroupName) { //TODO: also check for translated "Backup"
                    self.isDeleted = true
                }
                return
            } 
        } 
        
        Diag.warning("Group data missing the .end field")
        throw Database1.FormatError.prematureDataEnd
    }
    
    func write(to stream: ByteArray.OutputStream) {
        func writeField(fieldID: FieldID, data: ByteArray, addTrailingZero: Bool = false) {
            stream.write(value: fieldID.rawValue)
            if addTrailingZero {
                stream.write(value: UInt32(data.count + 1))
                stream.write(data: data)
                stream.write(value: UInt8(0))
            } else {
                stream.write(value: UInt32(data.count))
                stream.write(data: data)
            }
        }

        writeField(fieldID: .groupID, data: self.id.data)
        writeField(fieldID: .name, data: ByteArray(utf8String: self.name), addTrailingZero: true)
        writeField(fieldID: .creationTime, data: self.creationTime.asKP1Bytes())
        writeField(fieldID: .lastModifiedTime, data: self.lastModificationTime.asKP1Bytes())
        writeField(fieldID: .lastAccessTime, data: self.lastAccessTime.asKP1Bytes())
        writeField(fieldID: .expirationTime, data: self.expiryTime.asKP1Bytes())
        writeField(fieldID: .iconID, data: self.iconID.rawValue.data)
        writeField(fieldID: .groupLevel, data: UInt16(self.level).data)
        writeField(fieldID: .groupFlags, data: self.flags.data)
        writeField(fieldID: .end, data: ByteArray())
    }
}
