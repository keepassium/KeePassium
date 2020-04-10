//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Group2: Group {
    public var isExpanded: Bool
    public var customIconUUID: UUID
    public var defaultAutoTypeSequence: String
    public var isAutoTypeEnabled: Bool? 
    public var isSearchingEnabled: Bool? 
    public var lastTopVisibleEntryUUID: UUID
    public var usageCount: UInt32
    public var locationChangedTime: Date
    public var customData: CustomData2 
    
    override init(database: Database?) {
        isExpanded = true
        customIconUUID = UUID.ZERO
        defaultAutoTypeSequence = ""
        isAutoTypeEnabled = nil
        isSearchingEnabled = nil
        lastTopVisibleEntryUUID = UUID.ZERO
        usageCount = 0
        locationChangedTime = Date.now
        customData = CustomData2()
        super.init(database: database)
    }
    deinit {
        erase()
    }
    
    override public func erase() {
        super.erase()
        isExpanded = true
        customIconUUID.erase()
        defaultAutoTypeSequence.erase()
        isAutoTypeEnabled = nil
        isSearchingEnabled = nil
        lastTopVisibleEntryUUID.erase()
        usageCount = 0
        locationChangedTime = Date.now
        customData.erase()
    }
    
    override public func clone(makeNewUUID: Bool) -> Group {
        let copy = Group2(database: database)
        apply(to: copy, makeNewUUID: makeNewUUID)
        return copy
    }
    
    func apply(to target: Group2, makeNewUUID: Bool) {
        super.apply(to: target, makeNewUUID: makeNewUUID)
        
        target.isExpanded = isExpanded
        target.customIconUUID = customIconUUID
        target.defaultAutoTypeSequence = defaultAutoTypeSequence
        target.isAutoTypeEnabled = isAutoTypeEnabled
        target.isSearchingEnabled = isSearchingEnabled
        target.lastTopVisibleEntryUUID = lastTopVisibleEntryUUID
        target.usageCount = usageCount
        target.locationChangedTime = locationChangedTime
        target.customData = customData.clone()
    }
    
    override public func createEntry() -> Entry {
        let newEntry = Entry2(database: database)
        newEntry.uuid = UUID()
        newEntry.isDeleted = self.isDeleted
        
        if iconID != Group.defaultIconID && iconID != Group.defaultOpenIconID {
            newEntry.iconID = self.iconID
        }
        
        self.add(entry: newEntry)
        return newEntry
    }
    
    override public func createGroup() -> Group {
        let newGroup = Group2(database: database)
        newGroup.uuid = UUID()
        newGroup.iconID = self.iconID
        newGroup.customIconUUID = self.customIconUUID
        newGroup.isDeleted = self.isDeleted
        
        self.add(group: newGroup)
        
        return newGroup
    }
    
    override public func touch(_ mode: DatabaseItem.TouchMode, updateParents: Bool = true) {
        usageCount += 1
        super.touch(mode, updateParents: updateParents)
    }

    override public func move(to newGroup: Group) {
        super.move(to: newGroup)
        self.locationChangedTime = Date.now
    }
    
    func load(
        xml: AEXMLElement,
        streamCipher: StreamCipher,
        warnings: DatabaseLoadingWarnings
        ) throws
    {
        assert(xml.name == Xml2.group)
        Diag.verbose("Loading XML: group")
        
        let parent = self.parent
        erase()
        self.parent = parent
        
        let db2: Database2 = database as! Database2
        let meta: Meta2 = db2.meta
        var isRecycleBin = false
        
        for tag in xml.children {
            switch tag.name {
            case Xml2.uuid:
                self.uuid = UUID(base64Encoded: tag.value) ?? UUID.ZERO
                if uuid == meta.recycleBinGroupUUID && meta.isRecycleBinEnabled {
                    Diag.verbose("Is a backup group")
                    isRecycleBin = true
                }
            case Xml2.name:
                self.name = tag.value ?? ""
            case Xml2.notes:
                self.notes = tag.value ?? ""
            case Xml2.iconID:
                if let iconID = IconID(tag.value) {
                    self.iconID = iconID
                } else {
                    self.iconID = isExpanded ? Group.defaultOpenIconID : Group.defaultIconID
                }
            case Xml2.customIconUUID:
                self.customIconUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.times:
                try loadTimes(xml: tag)
                Diag.verbose("Group times loaded OK")
            case Xml2.isExpanded:
                self.isExpanded = Bool(string: tag.value)
            case Xml2.defaultAutoTypeSequence:
                self.defaultAutoTypeSequence = tag.value ?? ""
            case Xml2.enableAutoType:
                self.isAutoTypeEnabled = Bool(optString: tag.value) // value can be "True"/"False"/"null"
            case Xml2.enableSearching:
                self.isSearchingEnabled = Bool(optString: tag.value) // value can be "True"/"False"/"null"
            case Xml2.lastTopVisibleEntry:
                self.lastTopVisibleEntryUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.customData:
                assert(db2.header.formatVersion == .v4)
                try customData.load(xml: tag, streamCipher: streamCipher, xmlParentName: "Group")
                Diag.verbose("Custom data loaded OK")
            case Xml2.group:
                let subGroup = Group2(database: database)
                try subGroup.load(xml: tag, streamCipher: streamCipher, warnings: warnings)
                self.add(group: subGroup)
                Diag.verbose("Subgroup loaded OK")
            case Xml2.entry:
                let entry = Entry2(database: database)
                try entry.load(xml: tag, streamCipher: streamCipher, warnings: warnings)
                self.add(entry: entry)
                Diag.verbose("Entry loaded OK")
            default:
                Diag.error("Unexpected XML tag in Group: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Group/*")
            }
        }
        if isRecycleBin {
            deepSetDeleted(true)
        }
    }
    
    private func parseTimestamp(value: String?, tag: String, fallbackToEpoch: Bool) throws -> Date {
        if (value == nil || value!.isEmpty) && fallbackToEpoch {
            Diag.warning("\(tag) is empty, will use 1970-01-01 instead")
            return Date(timeIntervalSince1970: 0.0)
        }
        let db = database as! Database2
        guard let time = db.xmlStringToDate(value) else {
            Diag.error("Cannot parse \(tag) as Date")
            throw Xml2.ParsingError.malformedValue(
                tag: tag,
                value: value)
        }
        return time
    }
    
    func loadTimes(xml: AEXMLElement) throws {
        assert(xml.name == Xml2.times)
        Diag.verbose("Loading XML: group times")
        
        for tag in xml.children {
            switch tag.name {
            case Xml2.lastModificationTime:
                lastModificationTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/LastModificationTime",
                    fallbackToEpoch: true)
            case Xml2.creationTime:
                creationTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/CreationTime",
                    fallbackToEpoch: true)
            case Xml2.lastAccessTime:
                lastAccessTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/LastAccessTime",
                    fallbackToEpoch: true)
            case Xml2.expiryTime:
                expiryTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/ExpiryTime",
                    fallbackToEpoch: true)
            case Xml2.expires:
                canExpire = Bool(string: tag.value)
            case Xml2.usageCount:
                usageCount = UInt32(tag.value) ?? 0
            case Xml2.locationChanged:
                locationChangedTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/LocationChanged",
                    fallbackToEpoch: true)
            default:
                Diag.error("Unexpected XML tag in Group/Times: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Group/Times/*")
            }
        }
    }
    
    func toXml(streamCipher: StreamCipher) throws -> AEXMLElement {
        Diag.verbose("Generating XML: group")
        let xmlGroup = AEXMLElement(name: Xml2.group)
        xmlGroup.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xmlGroup.addChild(name: Xml2.name, value: name)
        xmlGroup.addChild(name: Xml2.notes, value: notes)
        xmlGroup.addChild(name: Xml2.iconID, value: String(iconID.rawValue))
        if customIconUUID != UUID.ZERO {
            xmlGroup.addChild(
                name: Xml2.customIconUUID,
                value: customIconUUID.base64EncodedString())
        }
        
        let db2 = database as! Database2
        let xmlTimes = AEXMLElement(name: Xml2.times)
        xmlTimes.addChild(
            name: Xml2.creationTime,
            value: db2.xmlDateToString(creationTime))
        xmlTimes.addChild(
            name: Xml2.lastModificationTime,
            value: db2.xmlDateToString(lastModificationTime))
        xmlTimes.addChild(
            name: Xml2.lastAccessTime,
            value: db2.xmlDateToString(lastAccessTime))
        xmlTimes.addChild(
            name: Xml2.expiryTime,
            value: db2.xmlDateToString(expiryTime))
        xmlTimes.addChild(
            name: Xml2.expires,
            value: canExpire ? Xml2._true : Xml2._false)
        xmlTimes.addChild(
            name: Xml2.usageCount,
            value: String(usageCount))
        xmlTimes.addChild(
            name: Xml2.locationChanged,
            value: db2.xmlDateToString(locationChangedTime))
        xmlGroup.addChild(xmlTimes)
        xmlGroup.addChild(
            name: Xml2.isExpanded,
            value: isExpanded ? Xml2._true : Xml2._false)
        xmlGroup.addChild(
            name: Xml2.defaultAutoTypeSequence,
            value: defaultAutoTypeSequence)
        
        if let isAutoTypeEnabled = self.isAutoTypeEnabled {
            xmlGroup.addChild(
                name: Xml2.enableAutoType,
                value: isAutoTypeEnabled ? Xml2._true : Xml2._false)
        } else {
            xmlGroup.addChild(name: Xml2.enableAutoType, value: Xml2.null)
        }
        
        if let isSearchingEnabled = self.isSearchingEnabled {
            xmlGroup.addChild(
                name: Xml2.enableSearching,
                value: isSearchingEnabled ? Xml2._true : Xml2._false)
        } else {
            xmlGroup.addChild(name: Xml2.enableSearching, value: Xml2.null)
        }

        xmlGroup.addChild(
            name: Xml2.lastTopVisibleEntry,
            value: lastTopVisibleEntryUUID.base64EncodedString())

        if db2.header.formatVersion == .v4 && !customData.isEmpty{
            xmlGroup.addChild(customData.toXml())
        }
        
        for entry in entries {
            let entry2 = entry as! Entry2
            xmlGroup.addChild(try entry2.toXml(streamCipher: streamCipher))
        }

        for group in groups {
            let group2 = group as! Group2
            let groupXML = try group2.toXml(streamCipher: streamCipher)
            xmlGroup.addChild(groupXML)
        }
        return xmlGroup
    }
}
