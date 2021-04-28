//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class EntryField2: EntryField {
    
    public var isEmpty: Bool {
        return name.isEmpty && value.isEmpty
    }
    
    override public func clone() -> EntryField {
        let clone = EntryField2(
            name: name,
            value: value,
            isProtected: isProtected,
            resolvedValue: resolvedValueInternal,
            resolveStatus: resolveStatus
        )
        return clone
    }
    
    func applyProtectionFlag(from meta: Meta2) {
        let mp = meta.memoryProtection
        switch name {
        case EntryField.title:
            isProtected = mp.isProtectTitle
        case EntryField.userName:
            isProtected = mp.isProtectUserName
        case EntryField.password:
            isProtected = mp.isProtectPassword
        case EntryField.url:
            isProtected = mp.isProtectURL
        case EntryField.notes:
            isProtected = mp.isProtectNotes
        default:
            break
        }
    }
    
    func load(xml: AEXMLElement, streamCipher: StreamCipher) throws {
        assert(xml.name == Xml2.string)
        Diag.verbose("Loading XML: entry field")
        erase()
        
        
        var key: String?
        var value: String? = ""
        var isProtected: Bool = false
        for tag in xml.children {
            switch tag.name {
            case Xml2.key:
                key = tag.value ?? ""
            case Xml2.value:
                isProtected = Bool(string: tag.attributes[Xml2.protected])
                if isProtected {
                    if let encData = ByteArray(base64Encoded: tag.value ?? "") {
                        Diag.verbose("Decrypting field value")
                        let plainData = try streamCipher.decrypt(data: encData, progress: nil)
                        value = plainData.toString(using: .utf8) 
                        if value == nil {
                            Diag.warning("Failed to decrypt field value")
                        }
                    }
                } else {
                    value = tag.value ?? ""
                }
            default:
                Diag.error("Unexpected XML tag in Entry/String: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/String/*")
            }
        }
        guard let _key = key else {
            Diag.error("Missing Entry/String/Key")
            throw Xml2.ParsingError.malformedValue(tag: "Entry/String/Key", value: nil)
        }
        guard let _value = value else {
            Diag.error("Missing Entry/String/Value")
            throw Xml2.ParsingError.malformedValue(tag: "Entry/String/Value", value: nil)
        }
        if _key.isEmpty && _value.isNotEmpty {
            Diag.error("Missing Entry/String/Key with present Value")
        }
        self.name = _key
        self.value = _value
        self.isProtected = isProtected
    }
    
    
    func toXml(streamCipher: StreamCipher) throws -> AEXMLElement {
        Diag.verbose("Generating XML: entry string")
        let xmlField = AEXMLElement(name: Xml2.string)
        xmlField.addChild(name: Xml2.key, value: name)
        if isProtected {
            let openData = ByteArray(utf8String: value)
            Diag.verbose("Encrypting field value")
            let encData = try streamCipher.encrypt(data: openData, progress: nil)
            xmlField.addChild(
                name: Xml2.value,
                value: encData.base64EncodedString(),
                attributes: [Xml2.protected: Xml2._true])
        } else {
            xmlField.addChild(name: Xml2.value, value: value)
        }
        return xmlField
    }
} 

public class Entry2: Entry {

    public class AutoType: Eraseable {
        public struct Association {
            var window: String
            var keystrokeSequence: String
        }
        var isEnabled: Bool
        var obfuscationType: UInt32
        var defaultSequence: String
        var associations: [Association]
        
        init(from original: AutoType) {
            isEnabled = original.isEnabled
            obfuscationType = original.obfuscationType
            defaultSequence = original.defaultSequence
            associations = original.associations
        }
        init() {
            isEnabled = true
            obfuscationType = 0
            defaultSequence = ""
            associations = []
        }
        deinit {
            erase()
        }
        
        public func erase() {
            isEnabled = true
            obfuscationType = 0
            defaultSequence.erase()
            associations.removeAll() 
        }

        func clone() -> AutoType {
            return AutoType(from: self)
        }

        func load(xml: AEXMLElement, streamCipher: StreamCipher) throws {
            assert(xml.name == Xml2.autoType)
            Diag.verbose("Loading XML: entry autotype")
            erase()
            
            for tag in xml.children {
                switch tag.name {
                case Xml2.enabled:
                    isEnabled = Bool(string: tag.value)
                case Xml2.dataTransferObfuscation:
                    obfuscationType = UInt32(tag.value) ?? 0
                case Xml2.defaultSequence:
                    defaultSequence = tag.value ?? ""
                case Xml2.association:
                    try loadAssociation(xml: tag)
                default:
                    Diag.error("Unexpected XML tag in Entry/AutoType: \(tag.name)")
                    throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/*")
                }
            }
        }
        
        func loadAssociation(xml: AEXMLElement) throws {
            assert(xml.name == Xml2.association)
            
            var window: String?
            var sequence: String?
            for tag in xml.children {
                switch tag.name {
                case Xml2.window:
                    window = tag.value ?? ""
                case Xml2.keystrokeSequence:
                    sequence = tag.value ?? ""
                default:
                    Diag.error("Unexpected XML tag in Entry/AutoType/Association: \(tag.name)")
                    throw Xml2.ParsingError.unexpectedTag(
                        actual: tag.name,
                        expected: "Entry/AutoType/Association/*")
                }
            }
            guard window != nil else {
                Diag.error("Missing Entry/AutoType/Association/Window")
                throw Xml2.ParsingError.malformedValue(
                    tag: "Entry/AutoType/Association/Window",
                    value: window)
            }
            guard sequence != nil else {
                Diag.error("Missing Entry/AutoType/Association/Sequence")
                throw Xml2.ParsingError.malformedValue(
                    tag: "Entry/AutoType/Association/Sequence",
                    value: sequence)
            }
            associations.append(Association(window: window!, keystrokeSequence: sequence!))
        }
        
        internal func toXml() -> AEXMLElement {
            Diag.verbose("Generating XML: entry autotype")
            let xmlAutoType = AEXMLElement(name: Xml2.autoType)
            xmlAutoType.addChild(
                name: Xml2.enabled,
                value: isEnabled ? Xml2._true : Xml2._false)
            xmlAutoType.addChild(
                name: Xml2.dataTransferObfuscation,
                value: String(obfuscationType))
            
            if !defaultSequence.isEmpty {
                xmlAutoType.addChild(
                    name: Xml2.defaultSequence,
                    value: defaultSequence)
            }
            for association in associations {
                let xmlAssoc = xmlAutoType.addChild(name: Xml2.association)
                xmlAssoc.addChild(
                    name: Xml2.window,
                    value: association.window)
                xmlAssoc.addChild(
                    name: Xml2.keystrokeSequence,
                    value: association.keystrokeSequence)
            }
            return xmlAutoType
        }
    } 
    
    private var _canExpire: Bool
    override public var canExpire: Bool {
        get { return _canExpire }
        set { _canExpire = newValue }
    }
    
    override public var isSupportsExtraFields: Bool { return true }
    
    override public var isSupportsMultipleAttachments: Bool { return true }
    
    
    public var customIconUUID: UUID
    public var autoType: AutoType
    public var history: Array<Entry2>
    public var usageCount: UInt32
    public var locationChangedTime: Date
    public var foregroundColor: String
    public var backgroundColor: String
    public var overrideURL: String
    public var tags: String
    public var previousParentGroupUUID: UUID 
    public var qualityCheck: Bool 
    public var customData: CustomData2 
    
    override init(database: Database?) {
        _canExpire = false
        customIconUUID = UUID.ZERO
        autoType = AutoType()
        history = []
        usageCount = 0
        locationChangedTime = Date.now
        foregroundColor = ""
        backgroundColor = ""
        overrideURL = ""
        tags = ""
        previousParentGroupUUID = UUID.ZERO
        qualityCheck = true
        customData = CustomData2(database: database)
        super.init(database: database)
    }
    deinit {
        erase()
    }
    
    override public func erase() {
        _canExpire = false
        customIconUUID.erase()
        autoType.erase()
        history.erase()
        usageCount = 0
        locationChangedTime = Date.now
        foregroundColor.erase()
        backgroundColor.erase()
        overrideURL.erase()
        tags.erase()
        previousParentGroupUUID.erase()
        qualityCheck = true
        customData.erase()
        super.erase()
    }
    
    override public func clone(makeNewUUID: Bool) -> Entry {
        let newEntry = Entry2(database: self.database)
        self.apply(to: newEntry, makeNewUUID: makeNewUUID)
        
        
        return newEntry
    }

    override public func apply(to target: Entry, makeNewUUID: Bool) {
        super.apply(to: target, makeNewUUID: makeNewUUID)
        guard let targetEntry2 = target as? Entry2 else {
            Diag.warning("Tried to apply entry state to unexpected entry class")
            assertionFailure()
            return
        }
        targetEntry2.customIconUUID = self.customIconUUID
        targetEntry2.foregroundColor = self.foregroundColor
        targetEntry2.backgroundColor = self.backgroundColor
        targetEntry2.overrideURL = self.overrideURL
        targetEntry2.tags = self.tags
        
        targetEntry2.autoType = self.autoType.clone()
        
        targetEntry2.canExpire = self.canExpire
        targetEntry2.usageCount = self.usageCount
        targetEntry2.locationChangedTime = self.locationChangedTime
        targetEntry2.previousParentGroupUUID = self.previousParentGroupUUID
        targetEntry2.qualityCheck = self.qualityCheck
        targetEntry2.customData = self.customData.clone()

        targetEntry2.history.removeAll()
        for histEntry in history {
            let histEntryClone = histEntry.clone(makeNewUUID: makeNewUUID) as! Entry2
            targetEntry2.history.append(histEntryClone)
        }
    }
    
    override public func makeEntryField(
        name: String,
        value: String,
        isProtected: Bool
        ) -> EntryField
    {
        return EntryField2(name: name, value: value, isProtected: isProtected)
    }
    
    public func addToHistory(entry: Entry) {
        history.insert(entry as! Entry2, at: 0)
    }
    
    func clearHistory() {
        history.erase()
    }
    
    func maintainHistorySize() {
        let meta: Meta2 = (self.database as! Database2).meta
        if meta.historyMaxItems >= 0 {
            
            history.sort(by: { return $0.lastModificationTime < $1.lastModificationTime })
            let oldEntryCount = history.count - Int(meta.historyMaxItems)
            guard oldEntryCount > 0 else { return }
            for oldEntry in history.prefix(oldEntryCount) {
                oldEntry.erase()
            }
            history = Array(history.dropFirst(oldEntryCount))
        }
    }
    
    
    override public func backupState() {
        let entryClone = self.clone(makeNewUUID: false) as! Entry2
        entryClone.clearHistory()
        addToHistory(entry: entryClone)
        maintainHistorySize()
    }

    override public func touch(_ mode: DatabaseItem.TouchMode, updateParents: Bool = true) {
        usageCount += 1
        super.touch(mode, updateParents: updateParents)
    }
    
    override public func move(to newGroup: Group) {
        previousParentGroupUUID = parent?.uuid ?? UUID.ZERO
        super.move(to: newGroup)
        locationChangedTime = Date.now
    }
    
    func load(
        xml: AEXMLElement,
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeParser: Database2XMLTimeParser,
        warnings: DatabaseLoadingWarnings
    ) throws {
        assert(xml.name == Xml2.entry)
        Diag.verbose("Loading XML: entry")
        
        let parent = self.parent
        erase()
        self.parent = parent
        
        for tag in xml.children {
            switch tag.name {
            case Xml2.uuid:
                self.uuid = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.iconID:
                self.iconID = IconID(tag.value) ?? IconID.key
            case Xml2.customIconUUID:
                self.customIconUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.foregroundColor:
                self.foregroundColor = tag.value ?? ""
            case Xml2.backgroundColor:
                self.backgroundColor = tag.value ?? ""
            case Xml2.overrideURL:
                self.overrideURL = tag.value ?? ""
            case Xml2.tags:
                self.tags = tag.value ?? ""
            case Xml2.string:
                let field = makeEntryField(name: "", value: "", isProtected: true) as! EntryField2
                try field.load(xml: tag, streamCipher: streamCipher)
                if field.isEmpty {
                    Diag.debug("Loaded empty entry field, ignoring.")
                } else if field.name.isEmpty {
                    Diag.warning("Loaded entry field with an empty name, will show a warning.")
                    setField(name: field.name, value: field.value, isProtected: field.isProtected)
                } else {
                    Diag.verbose("Entry field loaded OK")
                    setField(name: field.name, value: field.value, isProtected: field.isProtected)
                }
            case Xml2.binary:
                guard !tag.children.isEmpty else {
                    Diag.warning("Skipping an empty Binary tag")
                    continue
                }
                let att = try Attachment2.load(
                    xml: tag,
                    database: database as! Database2,
                    streamCipher: streamCipher)
                attachments.append(att)
                Diag.verbose("Entry attachment loaded OK")
            case Xml2.times:
                try loadTimes(xml: tag, timeParser: timeParser)
                Diag.verbose("Entry times loaded OK")
            case Xml2.autoType:
                try autoType.load(xml: tag, streamCipher: streamCipher)
                Diag.verbose("Entry autotype loaded OK")
            case Xml2.previousParentGroup:
                assert(formatVersion >= .v4_1)
                previousParentGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.qualityCheck:
                assert(formatVersion >= .v4_1)
                qualityCheck = Bool(optString: tag.value) ?? true
            case Xml2.customData: 
                assert(formatVersion >= .v4)
                try customData.load(
                    xml: tag,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    xmlParentName: "Entry")
                Diag.verbose("Entry custom data loaded OK")
            case Xml2.history:
                try loadHistory(
                    xml: tag,
                    formatVersion: formatVersion,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    warnings: warnings
                ) 
                Diag.verbose("Entry history loaded OK")
            default:
                Diag.error("Unexpected XML tag in Entry: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/*")
            }
        }
    }
    
    func loadTimes(xml: AEXMLElement, timeParser: Database2XMLTimeParser) throws {
        assert(xml.name == Xml2.times)
        Diag.verbose("Loading XML: entry times")
        
        var optionalExpiryTime: Date?
        for tag in xml.children {
            switch tag.name {
            case Xml2.lastModificationTime:
                guard let time = timeParser.xmlStringToDate(tag.value) else {
                    Diag.error("Cannot parse Entry/Times/LastModificationTime as Date")
                     throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/LastModificationTime",
                        value: tag.value)
                }
                lastModificationTime = time
            case Xml2.creationTime:
                guard let time = timeParser.xmlStringToDate(tag.value) else {
                    Diag.error("Cannot parse Entry/Times/CreationTime as Date")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/CreationTime",
                        value: tag.value)
                }
                creationTime = time
            case Xml2.lastAccessTime:
                guard let time = timeParser.xmlStringToDate(tag.value) else {
                    Diag.error("Cannot parse Entry/Times/LastAccessTime as Date")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/LastAccessTime",
                        value: tag.value)
                }
                lastAccessTime = time
            case Xml2.expiryTime:
                guard let tagValue = tag.value else {
                    Diag.warning("Entry/Times/ExpiryTime is nil")
                    optionalExpiryTime = nil 
                    continue
                }
                guard let time = timeParser.xmlStringToDate(tagValue) else {
                    Diag.error("Cannot parse Entry/Times/ExpiryTime as Date")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/ExpiryTime",
                        value: tagValue)
                }
                optionalExpiryTime = time
            case Xml2.expires:
                self.canExpire = Bool(string: tag.value)
            case Xml2.usageCount:
                usageCount = UInt32(tag.value) ?? 0
            case Xml2.locationChanged:
                guard let time = timeParser.xmlStringToDate(tag.value) else {
                    Diag.error("Cannot parse Entry/Times/LocationChanged as Date")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/LocationChanged",
                        value: tag.value)
                }
                locationChangedTime = time
            default:
                Diag.error("Unexpected XML tag in Entry/Times: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/Times/*")
            }
        }
        
        if let expiryTime = optionalExpiryTime  {
            self.expiryTime = expiryTime
        } else {
            if canExpire {
                Diag.error("Parsed an entry that can expire, but Entry/Times/ExpiryTime is nil")
                throw Xml2.ParsingError.malformedValue(
                    tag: "Entry/Times/ExpiryTime",
                    value: nil)
            } else {
                self.expiryTime = Date.distantFuture
            }
        }
    }

    func loadHistory(
        xml: AEXMLElement,
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeParser: Database2XMLTimeParser,
        warnings: DatabaseLoadingWarnings
        ) throws
    {
        assert(xml.name == Xml2.history)
        Diag.verbose("Loading XML: entry history")
        for tag in xml.children {
            switch tag.name {
            case Xml2.entry:
                let histEntry = Entry2(database: database)
                try histEntry.load(
                    xml: tag,
                    formatVersion: formatVersion,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    warnings: warnings
                ) 
                history.append(histEntry)
                Diag.verbose("Entry history item loaded OK")
            default:
                Diag.error("Unexpected XML tag in Entry/History: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/History/*")
            }
        }
    }
    
    func toXml(
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeFormatter: Database2XMLTimeFormatter
    ) throws -> AEXMLElement {
        Diag.verbose("Generating XML: entry")
        let meta: Meta2 = (database as! Database2).meta
        
        let xmlEntry = AEXMLElement(name: Xml2.entry)
        xmlEntry.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xmlEntry.addChild(name: Xml2.iconID, value: String(iconID.rawValue))
        if customIconUUID != UUID.ZERO {
            xmlEntry.addChild(
                name: Xml2.customIconUUID,
                value: customIconUUID.base64EncodedString())
        }
        xmlEntry.addChild(name: Xml2.foregroundColor, value: foregroundColor)
        xmlEntry.addChild(name: Xml2.backgroundColor, value: backgroundColor)
        xmlEntry.addChild(name: Xml2.overrideURL, value: overrideURL)
        xmlEntry.addChild(name: Xml2.tags, value: tags)
        
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
        xmlEntry.addChild(xmlTimes)
        
        for field in fields {
            let field2 = field as! EntryField2
            field2.applyProtectionFlag(from: meta)
            xmlEntry.addChild(try field2.toXml(streamCipher: streamCipher))
        }
        for att in attachments {
            xmlEntry.addChild((att as! Attachment2).toXml())
        }
        xmlEntry.addChild(autoType.toXml())
        
        if formatVersion >= .v4_1 {
            if previousParentGroupUUID != UUID.ZERO {
                xmlEntry.addChild(
                    name: Xml2.previousParentGroup,
                    value: previousParentGroupUUID.base64EncodedString()
                )
            }
            if !qualityCheck {
                xmlEntry.addChild(name: Xml2.qualityCheck, value: Xml2._false)
            }
        }
        
        if formatVersion >= .v4 && !customData.isEmpty{
            xmlEntry.addChild(customData.toXml(timeFormatter: timeFormatter))
        }
        
        if !history.isEmpty {
            let xmlHistory = xmlEntry.addChild(name: Xml2.history)
            for histEntry in history {
                xmlHistory.addChild(
                    try histEntry.toXml(
                        formatVersion: formatVersion,
                        streamCipher: streamCipher,
                        timeFormatter: timeFormatter
                    )
                )
            }
        }
        return xmlEntry
    }
}
