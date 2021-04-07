//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Entry1: Entry {
    private enum FieldID: UInt16 {
        case reserved  = 0x0000
        case uuid      = 0x0001
        case groupID   = 0x0002
        case iconID    = 0x0003
        case title     = 0x0004
        case url       = 0x0005
        case username  = 0x0006
        case password  = 0x0007
        case notes      = 0x0008
        case creationTime      = 0x0009
        case lastModifiedTime  = 0x000A
        case lastAccessTime    = 0x000B
        case expirationTime    = 0x000C
        case binaryDesc        = 0x000D
        case binaryData        = 0x000E
        case end               = 0xFFFF
    }
    
    private enum MetaStreamID {
        public static let iconID   = IconID.withZeroID
        public static let title    = "Meta-Info"
        public static let userName = "SYSTEM"
        public static let url      = "$"
        public static let attName  = "bin-stream"
    }
    
    
    override public var isSupportsMultipleAttachments: Bool { return false }
    
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
    internal var groupID: Group1ID
    
    override public var isSupportsExtraFields: Bool { get { return false } }
    
    var isMetaStream: Bool {
        guard let att = getAttachment() else { return false }
        if rawNotes.isEmpty { return false }
        
        return (iconID == MetaStreamID.iconID) &&
            (att.name == MetaStreamID.attName) &&
            (rawUserName == MetaStreamID.userName) &&
            (rawURL == MetaStreamID.url) &&
            (rawTitle == MetaStreamID.title)
    }

    override init(database: Database?) {
        groupID = 0
        super.init(database: database)
        
        canExpire = false
    }
    
    deinit {
        erase()
    }
    
    override public func erase() {
        groupID = 0
        super.erase()
        
        canExpire = false
    }
    
    override public func clone(makeNewUUID: Bool) -> Entry {
        let newEntry = Entry1(database: self.database)
        apply(to: newEntry, makeNewUUID: makeNewUUID)

        return newEntry
    }

    override public func apply(to target: Entry, makeNewUUID: Bool) {
        super.apply(to: target, makeNewUUID: makeNewUUID) 
        guard target is Entry1 else {
            Diag.warning("Tried to apply entry state to unexpected entry class")
            assertionFailure()
            return
        }
    }
    
    func load(from stream: ByteArray.InputStream) throws {
        Diag.verbose("Loading entry")
        erase()
        
        var binaryDesc = ""
        var binaryData = ByteArray()
        
        while stream.hasBytesAvailable {
            guard let fieldIDraw = stream.readUInt16() else {
                throw Database1.FormatError.prematureDataEnd
            }
            guard let fieldID = FieldID(rawValue: fieldIDraw) else {
                throw Database1.FormatError.corruptedField(fieldName: "Entry/FieldID")
            }
            guard let _fieldSize = stream.readInt32() else {
                throw Database1.FormatError.prematureDataEnd
            }
            guard _fieldSize >= 0 else {
                throw Database1.FormatError.corruptedField(fieldName: "Entry/FieldSize")
            }

            let fieldSize = Int(_fieldSize)
            
            switch fieldID {
            case .reserved:
                guard let _ = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
            case .uuid:
                guard let uuid = UUID(data: stream.read(count: fieldSize)) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                self.uuid = uuid
            case .groupID:
                guard let groupID: Group1ID = stream.readInt32() else {
                    throw Database1.FormatError.prematureDataEnd
                }
                self.groupID = groupID
            case .iconID:
                guard let iconIDraw = stream.readUInt32() else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let iconID = IconID(rawValue: iconIDraw) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/IconID")
                }
                self.iconID = iconID
            case .title:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/Title")
                }
                setField(name: EntryField.title, value: string)
            case .url:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/URL")
                }
                setField(name: EntryField.url, value: string)
            case .username:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/UserName")
                }
                setField(name: EntryField.userName, value: string)
            case .password:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/Password")
                }
                setField(name: EntryField.password, value: string)
            case .notes:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/Notes")
                }
                setField(name: EntryField.notes, value: string)
            case .creationTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/CreationTime")
                }
                self.creationTime = date
            case .lastModifiedTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/LastModifiedTime")
                }
                self.lastModificationTime = date
            case .lastAccessTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/LastAccessTime")
                }
                self.lastAccessTime = date
            case .expirationTime:
                guard let rawTimeData = stream.read(count: Date.kp1TimestampSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                guard let date = Date(kp1Bytes: rawTimeData) else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/ExpirationTime")
                }
                self.expiryTime = date
            case .binaryDesc:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                data.trim(toCount: data.count - 1) 
                guard let string = data.toString() else {
                    throw Database1.FormatError.corruptedField(fieldName: "Entry/BinaryDesc")
                }
                binaryDesc = string
            case .binaryData:
                guard let data = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                binaryData = data
            case .end:
                guard let _ = stream.read(count: fieldSize) else {
                    throw Database1.FormatError.prematureDataEnd
                }
                if binaryDesc.isNotEmpty {
                    let att = Attachment(
                        name: binaryDesc,
                        isCompressed: false,
                        data: binaryData)
                    attachments.append(att)
                }
                return
            } 
        } 
        
        Diag.warning("Entry data missing the .end field")
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
        writeField(fieldID: .uuid, data: uuid.data)
        writeField(fieldID: .groupID, data: groupID.data)
        writeField(fieldID: .iconID, data: iconID.rawValue.data)
        writeField(fieldID: .title, data: ByteArray(utf8String: rawTitle), addTrailingZero: true)
        writeField(fieldID: .url, data: ByteArray(utf8String: rawURL), addTrailingZero: true)
        writeField(fieldID: .username, data: ByteArray(utf8String: rawUserName), addTrailingZero: true)
        writeField(fieldID: .password, data: ByteArray(utf8String: rawPassword), addTrailingZero: true)
        writeField(fieldID: .notes, data: ByteArray(utf8String: rawNotes), addTrailingZero: true)
        writeField(fieldID: .creationTime, data: creationTime.asKP1Bytes())
        writeField(fieldID: .lastModifiedTime, data: lastModificationTime.asKP1Bytes())
        writeField(fieldID: .lastAccessTime, data: lastAccessTime.asKP1Bytes())
        writeField(fieldID: .expirationTime, data: expiryTime.asKP1Bytes())
        
        if let att = getAttachment() {
            let binaryDesc = ByteArray(utf8String: att.name)
            writeField(fieldID: .binaryDesc, data: binaryDesc, addTrailingZero: true)
            writeField(fieldID: .binaryData, data: att.data)
        } else {
            let emptyData = ByteArray()
            writeField(fieldID: .binaryDesc, data: emptyData, addTrailingZero: true)
            writeField(fieldID: .binaryData, data: emptyData)
        }
        writeField(fieldID: .end, data: ByteArray())
    }
    
    override public func backupState() {
        let copy = self.clone(makeNewUUID: true)

        database?.delete(entry: copy) 
    }
    
    internal func getAttachment() -> Attachment? {
        return attachments.first
    }    
}
