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
    public var previousParentGroupUUID: UUID 
    public var tags: String 
    public var customData: CustomData2 
    
    override public var isIncludeEntriesInSearch: Bool {
        if let isSearchingEnabled = isSearchingEnabled {
            return isSearchingEnabled
        }
        guard let parent2 = parent as? Group2 else {
            return true
        }
        return parent2.isIncludeEntriesInSearch
    }
    
    override init(database: Database?) {
        isExpanded = true
        customIconUUID = UUID.ZERO
        defaultAutoTypeSequence = ""
        isAutoTypeEnabled = nil
        isSearchingEnabled = nil
        lastTopVisibleEntryUUID = UUID.ZERO
        usageCount = 0
        locationChangedTime = Date.now
        previousParentGroupUUID = UUID.ZERO
        tags = ""
        customData = CustomData2(database: database)
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
        previousParentGroupUUID.erase()
        tags = ""
        customData.erase()
    }
    
    override public func clone(makeNewUUID: Bool) -> Group {
        let copy = Group2(database: database)
        apply(to: copy, makeNewUUID: makeNewUUID)
        return copy
    }
    
    override public func apply(to target: Group, makeNewUUID: Bool) {
        super.apply(to: target, makeNewUUID: makeNewUUID)
        guard let targetGroup2 = target as? Group2 else {
            Diag.warning("Tried to apply group state to unexpected group class")
            assertionFailure()
            return
        }
        targetGroup2.isExpanded = isExpanded
        targetGroup2.customIconUUID = customIconUUID
        targetGroup2.defaultAutoTypeSequence = defaultAutoTypeSequence
        targetGroup2.isAutoTypeEnabled = isAutoTypeEnabled
        targetGroup2.isSearchingEnabled = isSearchingEnabled
        targetGroup2.lastTopVisibleEntryUUID = lastTopVisibleEntryUUID
        targetGroup2.usageCount = usageCount
        targetGroup2.locationChangedTime = locationChangedTime
        targetGroup2.previousParentGroupUUID = previousParentGroupUUID
        targetGroup2.tags = tags
        targetGroup2.customData = customData.clone()
    }
    
    override public func createEntry(detached: Bool = false) -> Entry {
        let newEntry = Entry2(database: database)
        newEntry.uuid = UUID()
        newEntry.isDeleted = self.isDeleted
        
        if iconID != Group.defaultIconID && iconID != Group.defaultOpenIconID {
            newEntry.iconID = self.iconID
        }
        newEntry.customIconUUID = self.customIconUUID
        
        if !detached {
            self.add(entry: newEntry)
        }
        return newEntry
    }
    
    override public func createGroup(detached: Bool = false) -> Group {
        let newGroup = Group2(database: database)
        newGroup.uuid = UUID()
        newGroup.iconID = self.iconID
        newGroup.customIconUUID = self.customIconUUID
        newGroup.isDeleted = self.isDeleted
        
        if !detached {
            self.add(group: newGroup)
        }
        return newGroup
    }
    
    override public func touch(_ mode: DatabaseItem.TouchMode, updateParents: Bool = true) {
        usageCount += 1
        super.touch(mode, updateParents: updateParents)
    }

    override public func move(to newGroup: Group) {
        previousParentGroupUUID = parent?.uuid ?? UUID.ZERO
        super.move(to: newGroup)
        self.locationChangedTime = Date.now
    }
    
    func load(
        xml: AEXMLElement,
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeParser: Database2XMLTimeParser,
        warnings: DatabaseLoadingWarnings
    ) throws {
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
                try loadTimes(xml: tag, timeParser: timeParser)
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
            case Xml2.previousParentGroup:
                assert(formatVersion >= .v4_1)
                self.previousParentGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.tags:
                assert(formatVersion >= .v4_1)
                self.tags = tag.value ?? ""
            case Xml2.customData:
                assert(formatVersion >= .v4)
                try customData.load(
                    xml: tag,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    xmlParentName: "Group"
                )
                Diag.verbose("Custom data loaded OK")
            case Xml2.group:
                let subGroup = Group2(database: database)
                try subGroup.load(
                    xml: tag,
                    formatVersion: formatVersion,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    warnings: warnings
                ) 
                self.add(group: subGroup)
                Diag.verbose("Subgroup loaded OK")
            case Xml2.entry:
                let entry = Entry2(database: database)
                try entry.load(
                    xml: tag,
                    formatVersion: formatVersion,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    warnings: warnings
                ) 
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
    
    private func parseTimestamp(
        value: String?,
        tag: String,
        fallbackToEpoch: Bool,
        timeParser: Database2XMLTimeParser
    ) throws -> Date {
        if (value == nil || value!.isEmpty) && fallbackToEpoch {
            Diag.warning("\(tag) is empty, will use 1970-01-01 instead")
            return Date(timeIntervalSince1970: 0.0)
        }
        guard let time = timeParser.xmlStringToDate(value) else {
            Diag.error("Cannot parse \(tag) as Date")
            throw Xml2.ParsingError.malformedValue(
                tag: tag,
                value: value)
        }
        return time
    }
    
    func loadTimes(xml: AEXMLElement, timeParser: Database2XMLTimeParser) throws {
        assert(xml.name == Xml2.times)
        Diag.verbose("Loading XML: group times")
        
        for tag in xml.children {
            switch tag.name {
            case Xml2.lastModificationTime:
                lastModificationTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/LastModificationTime",
                    fallbackToEpoch: true,
                    timeParser: timeParser)
            case Xml2.creationTime:
                creationTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/CreationTime",
                    fallbackToEpoch: true,
                    timeParser: timeParser)
            case Xml2.lastAccessTime:
                lastAccessTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/LastAccessTime",
                    fallbackToEpoch: true,
                    timeParser: timeParser)
            case Xml2.expiryTime:
                expiryTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/ExpiryTime",
                    fallbackToEpoch: true,
                    timeParser: timeParser)
            case Xml2.expires:
                canExpire = Bool(string: tag.value)
            case Xml2.usageCount:
                usageCount = UInt32(tag.value) ?? 0
            case Xml2.locationChanged:
                locationChangedTime = try parseTimestamp(
                    value: tag.value,
                    tag: "Group/Times/LocationChanged",
                    fallbackToEpoch: true,
                    timeParser: timeParser)
            default:
                Diag.error("Unexpected XML tag in Group/Times: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Group/Times/*")
            }
        }
    }
    
    func toXml(
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeFormatter: Database2XMLTimeFormatter
    ) throws -> AEXMLElement {
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
        
        let xmlTimes = AEXMLElement(name: Xml2.times)
        xmlTimes.addChild(
            name: Xml2.creationTime,
            value: timeFormatter.dateToXMLString(creationTime))
        xmlTimes.addChild(
            name: Xml2.lastModificationTime,
            value: timeFormatter.dateToXMLString(lastModificationTime))
        xmlTimes.addChild(
            name: Xml2.lastAccessTime,
            value: timeFormatter.dateToXMLString(lastAccessTime))
        xmlTimes.addChild(
            name: Xml2.expiryTime,
            value: timeFormatter.dateToXMLString(expiryTime))
        xmlTimes.addChild(
            name: Xml2.expires,
            value: canExpire ? Xml2._true : Xml2._false)
        xmlTimes.addChild(
            name: Xml2.usageCount,
            value: String(usageCount))
        xmlTimes.addChild(
            name: Xml2.locationChanged,
            value: timeFormatter.dateToXMLString(locationChangedTime))
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

        if formatVersion >= .v4_1 {
            if previousParentGroupUUID != UUID.ZERO {
                xmlGroup.addChild(
                    name: Xml2.previousParentGroup,
                    value: previousParentGroupUUID.base64EncodedString())
            }
            xmlGroup.addChild(name: Xml2.tags, value: tags)
        }
        
        if formatVersion >= .v4 && !customData.isEmpty{
            xmlGroup.addChild(customData.toXml(timeFormatter: timeFormatter))
        }
        
        for entry in entries {
            let entry2 = entry as! Entry2
            let entryXML = try entry2.toXml(
                formatVersion: formatVersion,
                streamCipher: streamCipher,
                timeFormatter: timeFormatter
            ) 
            xmlGroup.addChild(entryXML)
        }

        for group in groups {
            let group2 = group as! Group2
            let groupXML = try group2.toXml(
                formatVersion: formatVersion,
                streamCipher: streamCipher,
                timeFormatter: timeFormatter)
            xmlGroup.addChild(groupXML)
        }
        return xmlGroup
    }
}
