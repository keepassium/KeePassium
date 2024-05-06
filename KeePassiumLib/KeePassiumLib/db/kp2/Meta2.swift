//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class Meta2: Eraseable {
    public static let generatorName = "KeePassium" 
    public static let defaultMaintenanceHistoryDays: UInt32 = 365
    public static let defaultHistoryMaxItems: Int32 = 10 
    public static let defaultHistoryMaxSize: Int64 = 6 * 1024 * 1024 

    private unowned let database: Database2
    private(set) var generator: String
    internal var headerHash: ByteArray? 
    private(set) var settingsChangedTime: Date
    private(set) var databaseName: String
    private(set) var databaseNameChangedTime: Date
    private(set) var databaseDescription: String
    private(set) var databaseDescriptionChangedTime: Date
    private(set) var defaultUserName: String
    private(set) var defaultUserNameChangedTime: Date
    private(set) var maintenanceHistoryDays: UInt32
    private(set) var colorString: String
    internal var masterKeyChangedTime: Date 
    private(set) var masterKeyChangeRec: Int64 
    private(set) var masterKeyChangeForce: Int64 
    internal var masterKeyChangeForceOnce: Bool 
    private(set) var memoryProtection: MemoryProtection
    private(set) var isRecycleBinEnabled: Bool
    private(set) var recycleBinGroupUUID: UUID
    internal var recycleBinChangedTime: Date
    private(set) var entryTemplatesGroupUUID: UUID
    private(set) var entryTemplatesGroupChangedTime: Date
    private(set) var historyMaxItems: Int32
    private(set) var historyMaxSize: Int64
    private(set) var lastSelectedGroupUUID: UUID
    private(set) var lastTopVisibleGroupUUID: UUID
    private(set) var customData: CustomData2
    private(set) var customIcons: [CustomIcon2]

    init(database: Database2) {
        self.database = database
        generator = ""
        headerHash = nil
        settingsChangedTime = Date.now
        databaseName = ""
        databaseNameChangedTime = Date.now
        databaseDescription = ""
        databaseDescriptionChangedTime = Date.now
        defaultUserName = ""
        defaultUserNameChangedTime = Date.now
        maintenanceHistoryDays = Meta2.defaultMaintenanceHistoryDays
        colorString = ""
        masterKeyChangedTime = Date.now
        masterKeyChangeRec = Int64(-1)
        masterKeyChangeForce = Int64(-1)
        masterKeyChangeForceOnce = false
        memoryProtection = MemoryProtection()
        isRecycleBinEnabled = true
        recycleBinGroupUUID = UUID.ZERO
        recycleBinChangedTime = Date.now
        entryTemplatesGroupUUID = UUID.ZERO
        entryTemplatesGroupChangedTime = Date.now
        historyMaxItems = Meta2.defaultHistoryMaxItems
        historyMaxSize = Meta2.defaultHistoryMaxSize
        lastSelectedGroupUUID = UUID.ZERO
        lastTopVisibleGroupUUID = UUID.ZERO
        customData = CustomData2(database: database)
        customIcons = []
    }
    deinit {
        erase()
    }

    func erase() {
        generator.erase()
        headerHash?.erase()
        settingsChangedTime = Date.now
        databaseName.erase()
        databaseNameChangedTime = Date.now
        databaseDescription.erase()
        databaseDescriptionChangedTime = Date.now
        defaultUserName.erase()
        defaultUserNameChangedTime = Date.now
        maintenanceHistoryDays = Meta2.defaultMaintenanceHistoryDays
        colorString.erase()
        masterKeyChangedTime = Date.now
        masterKeyChangeRec = Int64(-1)
        masterKeyChangeForce = Int64(-1)
        masterKeyChangeForceOnce = false
        memoryProtection.erase()
        isRecycleBinEnabled = true
        recycleBinGroupUUID.erase()
        recycleBinChangedTime = Date.now
        entryTemplatesGroupUUID.erase()
        entryTemplatesGroupChangedTime = Date.now
        historyMaxItems = Meta2.defaultHistoryMaxItems
        historyMaxSize = Meta2.defaultHistoryMaxSize
        lastSelectedGroupUUID.erase()
        lastTopVisibleGroupUUID.erase()
        customData.erase()
        customIcons.erase()
    }

    func loadDefaultValuesV4() {
        erase()
        generator = Meta2.generatorName
    }

    func createRecycleBinGroup() -> Group2 {
        assert(recycleBinGroupUUID == UUID.ZERO)

        let backupGroup = Group2(database: database)
        backupGroup.uuid = UUID()
        backupGroup.name = NSLocalizedString(
            "[Database2/backupGroupName] Recycle Bin",
            bundle: Bundle.framework,
            value: "Recycle Bin",
            comment: "Name of a group which contains deleted entries")
        backupGroup.iconID = IconID.trashBin
        backupGroup.isDeleted = true
        backupGroup.isAutoTypeEnabled = false
        backupGroup.isSearchingEnabled = false

        self.recycleBinGroupUUID = backupGroup.uuid
        self.recycleBinChangedTime = Date.now

        return backupGroup
    }

    func resetRecycleBinGroupUUID() {
        recycleBinGroupUUID = UUID.ZERO
        self.recycleBinChangedTime = Date.now
    }

    func toXml(
        streamCipher: StreamCipher,
        formatVersion: Database2.FormatVersion,
        timeFormatter: Database2.XMLTimeFormatter
    ) throws -> AEXMLElement {
        Diag.verbose("Generating XML: meta")
        let xmlMeta = AEXMLElement(name: Xml2.meta)
        xmlMeta.addChild(name: Xml2.generator, value: Meta2.generatorName)

        switch formatVersion {
        case .v3:
            if let headerHash = headerHash {
                xmlMeta.addChild(name: Xml2.headerHash, value: headerHash.base64EncodedString())
            }
        case .v4, .v4_1:
            xmlMeta.addChild(
                name: Xml2.settingsChanged,
                value: settingsChangedTime.base64EncodedString())
        }
        xmlMeta.addChild(
            name: Xml2.databaseName,
            value: databaseName)
        xmlMeta.addChild(
            name: Xml2.databaseNameChanged,
            value: timeFormatter(databaseNameChangedTime))
        xmlMeta.addChild(
            name: Xml2.databaseDescription,
            value: databaseDescription)
        xmlMeta.addChild(
            name: Xml2.databaseDescriptionChanged,
            value: timeFormatter(databaseDescriptionChangedTime))
        xmlMeta.addChild(
            name: Xml2.defaultUserName,
            value: defaultUserName)
        xmlMeta.addChild(
            name: Xml2.defaultUserNameChanged,
            value: timeFormatter(defaultUserNameChangedTime))
        xmlMeta.addChild(
            name: Xml2.maintenanceHistoryDays,
            value: String(maintenanceHistoryDays))
        xmlMeta.addChild(
            name: Xml2.color,
            value: colorString)
        xmlMeta.addChild(
            name: Xml2.masterKeyChanged,
            value: timeFormatter(masterKeyChangedTime))
        xmlMeta.addChild(
            name: Xml2.masterKeyChangeRec,
            value: String(masterKeyChangeRec))
        xmlMeta.addChild(
            name: Xml2.masterKeyChangeForce,
            value: String(masterKeyChangeForce))
        if masterKeyChangeForceOnce {
            xmlMeta.addChild(
                name: Xml2.masterKeyChangeForceOnce,
                value: masterKeyChangeForceOnce ? Xml2._true : Xml2._false)
        }
        xmlMeta.addChild(memoryProtection.toXml())
        xmlMeta.addChild(
            name: Xml2.recycleBinEnabled,
            value: isRecycleBinEnabled ? Xml2._true : Xml2._false)
        xmlMeta.addChild(
            name: Xml2.recycleBinUUID,
            value: recycleBinGroupUUID.base64EncodedString())
        xmlMeta.addChild(
            name: Xml2.recycleBinChanged,
            value: timeFormatter(recycleBinChangedTime))
        xmlMeta.addChild(
            name: Xml2.entryTemplatesGroup,
            value: entryTemplatesGroupUUID.base64EncodedString())
        xmlMeta.addChild(
            name: Xml2.entryTemplatesGroupChanged,
            value: timeFormatter(entryTemplatesGroupChangedTime))
        xmlMeta.addChild(
            name: Xml2.historyMaxItems,
            value: String(historyMaxItems))
        xmlMeta.addChild(
            name: Xml2.historyMaxSize,
            value: String(historyMaxSize))
        xmlMeta.addChild(
            name: Xml2.lastSelectedGroup,
            value: lastSelectedGroupUUID.base64EncodedString())
        xmlMeta.addChild(
            name: Xml2.lastTopVisibleGroup,
            value: lastTopVisibleGroupUUID.base64EncodedString())

        if let xmlCustomIcons = customIconsToXml(
            formatVersion: formatVersion,
            timeFormatter: timeFormatter)
        {
            xmlMeta.addChild(xmlCustomIcons)
        }

        if formatVersion == .v3 {
            if let xmlBinaries = try binariesToXml(streamCipher: streamCipher)
            {
                xmlMeta.addChild(xmlBinaries)
            }
            Diag.verbose("Binaries XML generated OK")
        }
        xmlMeta.addChild(customData.toXml(timeFormatter: timeFormatter))
        return xmlMeta
    }

    internal func customIconsToXml(
        formatVersion: Database2.FormatVersion,
        timeFormatter: Database2.XMLTimeFormatter
    ) -> AEXMLElement? {
        if customIcons.isEmpty {
            return nil
        } else {
            let xmlCustomIcons = AEXMLElement(name: Xml2.customIcons)
            for customIcon in customIcons {
                xmlCustomIcons.addChild(
                    customIcon.toXml(formatVersion: formatVersion, timeFormatter: timeFormatter)
                )
            }
            return xmlCustomIcons
        }
    }

    internal func binariesToXml(streamCipher: StreamCipher) throws -> AEXMLElement? {
        if database.binaries.isEmpty {
            Diag.verbose("No binaries in Meta")
            return nil
        } else {
            Diag.verbose("Generating XML: meta binaries")
            let xmlBinaries = AEXMLElement(name: Xml2.binaries)
            for binaryID in database.binaries.keys.sorted() {
                let binary = database.binaries[binaryID]!
                xmlBinaries.addChild(try binary.toXml(streamCipher: streamCipher))
            }
            return xmlBinaries
        }
    }

    func setAllTimestamps(to time: Date) {
        settingsChangedTime = time
        databaseNameChangedTime = time
        databaseDescriptionChangedTime = time
        defaultUserNameChangedTime = time
        masterKeyChangedTime = time
        recycleBinChangedTime = time
        entryTemplatesGroupChangedTime = time
    }

    func addCustomIcon(_ icon: CustomIcon2) {
        customIcons.append(icon)
    }

    func deleteCustomIcon(uuid: UUID) {
        customIcons.removeAll(where: { $0.uuid == uuid })
    }
}

extension Meta2 {

    func load(
        xml: AEXMLElement,
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher,
        timeParser: Database2.XMLTimeParser,
        warnings: DatabaseLoadingWarnings
    ) throws {
        assert(xml.name == Xml2.meta)
        Diag.verbose("Loading XML: meta")
        erase()

        for tag in xml.children {
            switch tag.name {
            case Xml2.generator:
                self.generator = tag.value ?? ""
                warnings.databaseGenerator = tag.value 
                Diag.info("Database was last edited by: \(generator)")
            case Xml2.settingsChanged: 
                guard formatVersion >= .v4 else {
                    Diag.error("Found \(tag.name) tag in non-V4 database")
                    throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: nil)
                }
                self.settingsChangedTime = timeParser(tag.value) ?? Date.now
            case Xml2.headerHash:
                guard formatVersion == .v3 else {
                    Diag.warning("Found \(tag.name) tag in non-V3 database. Ignoring")
                    continue
                }
                self.headerHash = ByteArray(base64Encoded: tag.value) 
            case Xml2.databaseName:
                self.databaseName = tag.value ?? ""
            case Xml2.databaseNameChanged:
                self.databaseNameChangedTime = timeParser(tag.value) ?? Date.now
            case Xml2.databaseDescription:
                self.databaseDescription = tag.value ?? ""
            case Xml2.databaseDescriptionChanged:
                self.databaseDescriptionChangedTime =
                    timeParser(tag.value) ?? Date.now
            case Xml2.defaultUserName:
                self.defaultUserName = tag.value ?? ""
            case Xml2.defaultUserNameChanged:
                self.defaultUserNameChangedTime = timeParser(tag.value) ?? Date.now
            case Xml2.maintenanceHistoryDays:
                self.maintenanceHistoryDays =
                    UInt32(tag.value) ?? Meta2.defaultMaintenanceHistoryDays
            case Xml2.color:
                self.colorString = tag.value ?? ""
            case Xml2.masterKeyChanged:
                self.masterKeyChangedTime = timeParser(tag.value) ?? Date.now
            case Xml2.masterKeyChangeRec:
                self.masterKeyChangeRec = Int64(tag.value) ?? -1
            case Xml2.masterKeyChangeForce:
                self.masterKeyChangeForce = Int64(tag.value) ?? -1
            case Xml2.masterKeyChangeForceOnce:
                self.masterKeyChangeForceOnce = Bool(string: tag.value)
            case Xml2.memoryProtection:
                try memoryProtection.load(xml: tag)
                Diag.verbose("Memory protection loaded OK")
            case Xml2.customIcons:
                try loadCustomIcons(xml: tag, timeParser: timeParser)
                Diag.verbose("Custom icons loaded OK [count: \(customIcons.count)]")
            case Xml2.recycleBinEnabled:
                self.isRecycleBinEnabled = Bool(string: tag.value)
            case Xml2.recycleBinUUID:
                self.recycleBinGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.recycleBinChanged:
                self.recycleBinChangedTime = timeParser(tag.value) ?? Date.now
            case Xml2.entryTemplatesGroup:
                self.entryTemplatesGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.entryTemplatesGroupChanged:
                self.entryTemplatesGroupChangedTime =
                    timeParser(tag.value) ?? Date.now
            case Xml2.historyMaxItems:
                self.historyMaxItems = Int32(tag.value) ?? -1
            case Xml2.historyMaxSize:
                self.historyMaxSize = Int64(tag.value) ?? -1
            case Xml2.lastSelectedGroup:
                self.lastSelectedGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.lastTopVisibleGroup:
                self.lastTopVisibleGroupUUID = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.binaries:
                try loadBinaries(xml: tag, formatVersion: formatVersion, streamCipher: streamCipher)
                Diag.verbose("Binaries loaded OK [count: \(database.binaries.count)]")
            case Xml2.customData:
                try customData.load(
                    xml: tag,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    xmlParentName: "Meta"
                ) 
                Diag.verbose("Custom data loaded OK [count: \(customData.count)]")
            default:
                Diag.error("Unexpected XML tag in Meta: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Meta/*")
            }
        }
    }

    func loadCustomIcons(xml: AEXMLElement, timeParser: Database2.XMLTimeParser) throws {
        assert(xml.name == Xml2.customIcons)
        Diag.verbose("Loading XML: custom icons")
        for tag in xml.children {
            switch tag.name {
            case Xml2.icon:
                let icon = CustomIcon2()
                try icon.load(xml: tag, timeParser: timeParser) 
                customIcons.append(icon)
                Diag.verbose("Custom icon loaded OK")
            default:
                Diag.error("Unexpected XML tag in Meta/CustomIcons: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: "Meta/CustomIcons/*")
            }
        }
    }

    func loadBinaries(
        xml: AEXMLElement,
        formatVersion: Database2.FormatVersion,
        streamCipher: StreamCipher
    ) throws {
        assert(xml.name == Xml2.binaries)
        Diag.verbose("Loading XML: meta binaries")
        guard formatVersion == .v3 else {
            if let tag = xml.children.first {
                Diag.error("Unexpected XML content in V4 Meta/Binaries: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: nil)
            } else {
                Diag.warning("Found empty Meta/Binaries in a V4 database, ignoring.")
            }
            return
        }

        database.binaries.removeAll()
        for tag in xml.children {
            switch tag.name {
            case Xml2.binary:
                let binary = try Binary2.load(xml: tag, streamCipher: streamCipher)

                if let conflictingBinary = database.binaries[binary.id] {
                    Diag.error("Multiple Meta/Binary items with the same ID: \(conflictingBinary.id)")
                    throw Xml2.ParsingError.malformedValue(
                        tag: tag.name,
                        value: String(conflictingBinary.id))
                }
                database.binaries[binary.id] = binary
                Diag.verbose("Binary loaded OK")
            default:
                Diag.error("Unexpected XML tag in Meta/Binaries: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Meta/Binaries/*")
            }
        }
    }
}

extension Meta2 {
    func loadFromXML(_ xml: DatabaseXMLParserStream) throws {
        try xml.pushReader(parseMetaElement, context: nil)
    }

    private func parseMetaElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.meta, .start):
            Diag.verbose("Loading XML: meta")
        case (Xml2.memoryProtection, .start):
            try memoryProtection.loadFromXML(xml)
        case (Xml2.customIcons, .start):
            try xml.pushReader(parseCustomIconsElement, context: nil)
        case (Xml2.binaries, .start):
            try xml.pushReader(parseBinariesElement, context: nil)
        case (Xml2.customData, .start):
            try customData.loadFromXML(xml, xmlParentName: "Meta")
        case (Xml2.generator, .end):
            self.generator = xml.value ?? ""
            xml.documentContext.warnings.databaseGenerator = xml.value
            Diag.info("Database was last edited by: \(generator)")
        case (Xml2.settingsChanged, .end):
            guard xml.documentContext.formatVersion >= .v4 else {
                Diag.error("Found \(xml.name) tag in non-V4 database")
                throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: nil)
            }
            let timeParser = xml.documentContext.timeParser
            self.settingsChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.headerHash, .end):
            guard xml.documentContext.formatVersion == .v3 else {
                Diag.warning("Found \(xml.name) tag in non-V3 database. Ignoring")
                return
            }
            self.headerHash = ByteArray(base64Encoded: xml.value)
        case (Xml2.databaseName, .end):
            self.databaseName = xml.value ?? ""
        case (Xml2.databaseNameChanged, .end):
            let timeParser = xml.documentContext.timeParser
            self.databaseNameChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.databaseDescription, .end):
            self.databaseDescription = xml.value ?? ""
        case (Xml2.databaseDescriptionChanged, .end):
            let timeParser = xml.documentContext.timeParser
            self.databaseDescriptionChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.defaultUserName, .end):
            self.defaultUserName = xml.value ?? ""
        case (Xml2.defaultUserNameChanged, .end):
            let timeParser = xml.documentContext.timeParser
            self.defaultUserNameChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.maintenanceHistoryDays, .end):
            self.maintenanceHistoryDays = UInt32(xml.value) ?? Meta2.defaultMaintenanceHistoryDays
        case (Xml2.color, .end):
            self.colorString = xml.value ?? ""
        case (Xml2.masterKeyChanged, .end):
            let timeParser = xml.documentContext.timeParser
            self.masterKeyChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.masterKeyChangeRec, .end):
            self.masterKeyChangeRec = Int64(xml.value) ?? -1
        case (Xml2.masterKeyChangeForce, .end):
            self.masterKeyChangeForce = Int64(xml.value) ?? -1
        case (Xml2.masterKeyChangeForceOnce, .end):
            self.masterKeyChangeForceOnce = Bool(string: xml.value)
        case (Xml2.recycleBinEnabled, .end):
            self.isRecycleBinEnabled = Bool(string: xml.value)
        case (Xml2.recycleBinUUID, .end):
            self.recycleBinGroupUUID = UUID(base64Encoded: xml.value) ?? UUID.ZERO
        case (Xml2.recycleBinChanged, .end):
            let timeParser = xml.documentContext.timeParser
            self.recycleBinChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.entryTemplatesGroup, .end):
            self.entryTemplatesGroupUUID = UUID(base64Encoded: xml.value) ?? UUID.ZERO
        case (Xml2.entryTemplatesGroupChanged, .end):
            let timeParser = xml.documentContext.timeParser
            self.entryTemplatesGroupChangedTime = timeParser(xml.value) ?? Date.now
        case (Xml2.historyMaxItems, .end):
            self.historyMaxItems = Int32(xml.value) ?? -1
        case (Xml2.historyMaxSize, .end):
            self.historyMaxSize = Int64(xml.value) ?? -1
        case (Xml2.lastSelectedGroup, .end):
            self.lastSelectedGroupUUID = UUID(base64Encoded: xml.value) ?? UUID.ZERO
        case (Xml2.lastTopVisibleGroup, .end):
            self.lastTopVisibleGroupUUID = UUID(base64Encoded: xml.value) ?? UUID.ZERO

        case (Xml2.meta, .end):
            Diag.verbose("Meta loaded OK")
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Meta: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Meta/*")
        }
    }

    private func parseCustomIconsElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.customIcons, .start):
            Diag.verbose("Loading XML: custom icons")
        case (Xml2.icon, .start):
            try CustomIcon2.readFromXML(xml) { [unowned self] icon in
                customIcons.append(icon)
            }
        case (Xml2.customIcons, .end):
            Diag.verbose("Custom icons loaded OK [count: \(customIcons.count)]")
            xml.popReader()
        default:
            Diag.error("Unexpected XML tag in Meta/CustomIcons: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(
                actual: xml.name,
                expected: "Meta/CustomIcons/*")
        }
    }

    private func parseBinariesElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.binaries, .start):
            Diag.verbose("Loading XML: meta binaries")
            database.binaries.erase()
        case (Xml2.binary, .start):
            try Binary2.readFromXML(xml) { [unowned self] binary in
                if let conflictingBinary = database.binaries[binary.id] {
                    Diag.error("Multiple Meta/Binary items with the same ID: \(conflictingBinary.id)")
                    throw Xml2.ParsingError.malformedValue(
                        tag: Xml2.binary,
                        value: String(conflictingBinary.id))
                }
                database.binaries[binary.id] = binary
            }
        case (Xml2.binaries, .end):
            switch xml.documentContext.formatVersion {
            case .v3: break
            case .v4, .v4_1:
                if database.binaries.isEmpty {
                    Diag.warning("Found empty Meta/Binaries in a V4 database, ignoring.")
                } else {
                    Diag.error("Unexpected XML content in V4 Meta/Binaries")
                    throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: nil)
                }
            }
            Diag.verbose("Binaries loaded OK [count: \(database.binaries.count)]")
            xml.popReader()
        default:
            Diag.error("Unexpected XML tag in Meta/Binaries: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Meta/Binaries/*")
        }
    }

    private func verifyAndAddBinary(_ binary: Binary2) throws {
    }
}
