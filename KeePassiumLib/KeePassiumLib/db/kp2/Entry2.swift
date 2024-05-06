//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Entry2: Entry {
    private var _canExpire: Bool
    override public var canExpire: Bool {
        get { return _canExpire }
        set { _canExpire = newValue }
    }

    override public var isSupportsExtraFields: Bool { return true }

    override public var isSupportsMultipleAttachments: Bool { return true }

    public var customIconUUID: UUID
    public var autoType: AutoType
    public var history: [Entry2]
    public var usageCount: UInt32
    public var locationChangedTime: Date
    public var foregroundColor: String
    public var backgroundColor: String
    public var overrideURL: String
    public var previousParentGroupUUID: UUID
    public var qualityCheck: Bool
    public var customData: CustomData2

    public var browserHideEntry: Bool? {
        get {
            customData[Xml2.ThirdParty.browserHideEntry].flatMap({ Bool(string: $0.value) })
        }
        set {
            let dataItem = CustomData2.Item(value: String(describing: newValue), lastModificationTime: .now)
            customData[Xml2.ThirdParty.browserHideEntry] = dataItem
        }
    }

    public override var isHiddenFromSearch: Bool {
        get {
            browserHideEntry ?? false
        }
        set {
            browserHideEntry = newValue
        }
    }

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
        previousParentGroupUUID = UUID.ZERO
        qualityCheck = true
        customData = CustomData2(database: database)
        super.init(database: database)
        tags = []
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
    ) -> EntryField {
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
}

extension Entry2 {
    func load(
        xml: AEXMLElement,
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeParser: Database2.XMLTimeParser,
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
                self.tags = parseItemTags(xml: tag)
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
                assert(formatVersion.supports(.previousParentGroup))
                previousParentGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.qualityCheck:
                assert(formatVersion.supports(.qualityCheckFlag))
                qualityCheck = Bool(optString: tag.value) ?? true
            case Xml2.customData: 
                assert(formatVersion.supports(.customData))
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

    func loadTimes(xml: AEXMLElement, timeParser: Database2.XMLTimeParser) throws {
        assert(xml.name == Xml2.times)
        Diag.verbose("Loading XML: entry times")

        var optionalExpiryTime: Date?
        for tag in xml.children {
            switch tag.name {
            case Xml2.lastModificationTime:
                guard let time = timeParser(tag.value) else {
                    Diag.error("Cannot parse Entry/Times/LastModificationTime as Date")
                     throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/LastModificationTime",
                        value: tag.value)
                }
                lastModificationTime = time
            case Xml2.creationTime:
                guard let time = timeParser(tag.value) else {
                    Diag.error("Cannot parse Entry/Times/CreationTime as Date")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "Entry/Times/CreationTime",
                        value: tag.value)
                }
                creationTime = time
            case Xml2.lastAccessTime:
                guard let time = timeParser(tag.value) else {
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
                guard let time = timeParser(tagValue) else {
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
                guard let time = timeParser(tag.value) else {
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

        if let expiryTime = optionalExpiryTime {
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
        timeParser: Database2.XMLTimeParser,
        warnings: DatabaseLoadingWarnings
    ) throws {
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
        timeFormatter: Database2.XMLTimeFormatter
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
        xmlEntry.addChild(name: Xml2.tags, value: itemTagsToString(tags))

        let xmlTimes = AEXMLElement(name: Xml2.times)
        xmlTimes.addChild(
            name: Xml2.creationTime,
            value: timeFormatter(creationTime))
        xmlTimes.addChild(
            name: Xml2.lastModificationTime,
            value: timeFormatter(lastModificationTime))
        xmlTimes.addChild(
            name: Xml2.lastAccessTime,
            value: timeFormatter(lastAccessTime))
        xmlTimes.addChild(
            name: Xml2.expiryTime,
            value: timeFormatter(expiryTime))
        xmlTimes.addChild(
            name: Xml2.expires,
            value: canExpire ? Xml2._true : Xml2._false)
        xmlTimes.addChild(
            name: Xml2.usageCount,
            value: String(usageCount))
        xmlTimes.addChild(
            name: Xml2.locationChanged,
            value: timeFormatter(locationChangedTime))
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

        if formatVersion.supports(.previousParentGroup),
           previousParentGroupUUID != UUID.ZERO
        {
            xmlEntry.addChild(
                name: Xml2.previousParentGroup,
                value: previousParentGroupUUID.base64EncodedString()
            )
        }
        if formatVersion.supports(.qualityCheckFlag),
           !qualityCheck
        {
            xmlEntry.addChild(name: Xml2.qualityCheck, value: Xml2._false)
        }

        if formatVersion.supports(.customData),
           !customData.isEmpty
        {
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

extension Entry2 {
    typealias ParsingCompletion = (Entry2) -> Void
    final private class ParsingContext: XMLReaderContext {
        var optionalExpiryTime: Date?
        var database: Database2
        var completion: ParsingCompletion
        init(database: Database2, completion: @escaping ParsingCompletion) {
            self.database = database
            self.completion = completion
        }
    }

    static func readFromXML(
        _ xml: DatabaseXMLParserStream,
        database: Database2,
        completion: @escaping ParsingCompletion
    ) throws {
        assert(xml.name == Xml2.entry)
        let entry = Entry2(database: database)
        let context = ParsingContext(database: database, completion: completion)
        try xml.pushReader(entry.parseEntryElement, context: context)
    }

    private func parseEntryElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParsingContext
        switch (xml.name, xml.event) {
        case (Xml2.entry, .start):
            Diag.verbose("Loading XML: entry")
        case (Xml2.string, .start):
            try EntryField2.readFromXML(xml) { [unowned self] field in
                guard !field.isEmpty else {
                    Diag.debug("Loaded empty entry field, ignoring.")
                    return
                }
                guard !field.name.isEmpty else {
                    Diag.warning("Loaded entry field with an empty name, will show a warning.")
                    setField(name: field.name, value: field.value, isProtected: field.isProtected)
                    return
                }
                setField(name: field.name, value: field.value, isProtected: field.isProtected)
            }
        case (Xml2.binary, .start):
            try Attachment2.readFromXML(xml, database: context.database) { [unowned self] attachment in
                self.attachments.append(attachment)
            }
        case (Xml2.times, .start):
            try xml.pushReader(parseTimesElement, context: context)
        case (Xml2.autoType, .start):
            try autoType.loadFromXML(xml)
        case (Xml2.customData, .start):
            let formatVersion = xml.documentContext.formatVersion
            assert(formatVersion.supports(.customData))
            try customData.loadFromXML(xml, xmlParentName: "Entry")
        case (Xml2.history, .start):
            try xml.pushReader(parseHistoryElement, context: context)
        case (Xml2.uuid, .end):
            self.uuid = UUID(base64Encoded: xml.value) ?? UUID.ZERO
        case (Xml2.iconID, .end):
            self.iconID = IconID(xml.value) ?? IconID.key
        case (Xml2.customIconUUID, .end):
            self.customIconUUID = UUID(base64Encoded: xml.value) ?? UUID.ZERO
        case (Xml2.foregroundColor, .end):
            self.foregroundColor = xml.value ?? ""
        case (Xml2.backgroundColor, .end):
            self.backgroundColor = xml.value ?? ""
        case (Xml2.overrideURL, .end):
            self.overrideURL = xml.value ?? ""
        case (Xml2.tags, .end):
            self.tags = TagHelper.stringToTags(xml.value)
        case (Xml2.previousParentGroup, .end):
            let formatVersion = xml.documentContext.formatVersion
            assert(formatVersion.supports(.previousParentGroup))
            self.previousParentGroupUUID = UUID(base64Encoded: xml.value) ?? UUID.ZERO
        case (Xml2.qualityCheck, .end):
            let formatVersion = xml.documentContext.formatVersion
            assert(formatVersion.supports(.qualityCheckFlag))
            self.qualityCheck = Bool(optString: xml.value) ?? true
        case (Xml2.entry, .end):
            context.completion(self)
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Entry: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Entry/*")
        }
    }

    private func parseTimesElement(_ xml: DatabaseXMLParserStream) throws {
        let timeParser = xml.documentContext.timeParser
        switch (xml.name, xml.event) {
        case (Xml2.times, .start):
            Diag.verbose("Loading XML: entry times")
        case (Xml2.lastModificationTime, .end):
            lastModificationTime = try parseTimeValue(xml.value, timeParser, name: "LastModificationTime")
        case (Xml2.creationTime, .end):
            creationTime = try parseTimeValue(xml.value, timeParser, name: "CreationTime")
        case (Xml2.lastAccessTime, .end):
            lastAccessTime = try parseTimeValue(xml.value, timeParser, name: "LastAccessTime")
        case (Xml2.expiryTime, .end):
            let context = xml.readerContext as! ParsingContext
            guard let value = xml.value else {
                Diag.warning("Entry/Times/ExpiryTime is nil")
                context.optionalExpiryTime = nil
                return
            }
            context.optionalExpiryTime = try parseTimeValue(value, timeParser, name: "ExpiryTime")
        case (Xml2.expires, .end):
            self.canExpire = Bool(string: xml.value)
        case (Xml2.usageCount, .end):
            usageCount = UInt32(xml.value) ?? 0
        case (Xml2.locationChanged, .end):
            locationChangedTime = try parseTimeValue(xml.value, timeParser, name: "LocationChanged")
        case (Xml2.times, .end):
            let context = xml.readerContext as! ParsingContext
            if let expiryTime = context.optionalExpiryTime {
                self.expiryTime = expiryTime
            } else {
                if canExpire {
                    Diag.error("Parsed an entry that can expire, but Entry/Times/ExpiryTime is nil")
                    throw Xml2.ParsingError.malformedValue(tag: "Entry/Times/ExpiryTime", value: nil)
                } else {
                    self.expiryTime = Date.distantFuture
                }
            }
            Diag.verbose("Entry times loaded OK")
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Entry/Times: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Entry/Times/*")
        }
    }

    private func parseTimeValue(
        _ value: String?,
        _ timeParser: Database2.XMLTimeParser,
        name: String
    ) throws -> Date {
        guard let time = timeParser(value) else {
            Diag.error("Cannot parse Entry/Times/\(name) as Date")
             throw Xml2.ParsingError.malformedValue(
                tag: "Entry/Times/\(name)",
                value: value
             )
        }
        return time
    }

    private func parseHistoryElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.history, .start):
            Diag.verbose("Loading XML: entry history")
        case (Xml2.entry, .start):
            let context = xml.readerContext as! ParsingContext
            try Entry2.readFromXML(xml, database: context.database) { [unowned self] historyEntry in
                history.append(historyEntry)
                Diag.verbose("Entry history item loaded OK")
            }
        case (Xml2.history, .end):
            Diag.verbose("Entry history loaded OK")
            xml.popReader()
        default:
            Diag.error("Unexpected XML tag in Entry/History: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Entry/History/*")
        }
    }
}
