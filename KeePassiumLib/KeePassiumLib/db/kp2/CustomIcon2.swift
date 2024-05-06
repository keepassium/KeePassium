//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class CustomIcon2: Eraseable {
    public static let maxSidePixels = CGFloat(120)

    public private(set) var uuid: UUID
    public private(set) var data: ByteArray
    public private(set) var name: String?
    public private(set) var lastModificationTime: Date?
    public var description: String {
        return "CustomIcon(UUID: \(uuid.uuidString), Data: \(data.count) bytes"
    }

    init() {
        uuid = UUID.ZERO
        data = ByteArray()
        name = nil
        lastModificationTime = nil

    }
    public init(uuid: UUID, data: ByteArray) {
        self.uuid = uuid
        self.data = data
        self.name = nil
        self.lastModificationTime = nil
    }

    deinit {
        erase()
    }

    public func erase() {
        uuid.erase()
        data.erase()
        name?.erase()
        lastModificationTime = nil
    }

    public func clone() -> CustomIcon2 {
        let newIcon = CustomIcon2()
        self.apply(to: newIcon)
        return newIcon
    }

    public func apply(to target: CustomIcon2) {
        target.uuid = uuid
        target.data = data.clone()
        target.name = name
        target.lastModificationTime = lastModificationTime
    }

    public func setName(_ newName: String) {
        name = newName
        lastModificationTime = Date.now
    }
}

extension CustomIcon2 {
    func load(xml: AEXMLElement, timeParser: Database2.XMLTimeParser) throws {
        assert(xml.name == Xml2.icon)
        Diag.verbose("Loading XML: custom icon")

        erase()
        var xmlUUID: UUID?
        var xmlData: ByteArray?
        var xmlName: String?
        var xmlLastModificationTime: Date?
        for tag in xml.children {
            switch tag.name {
            case Xml2.uuid:
                xmlUUID = UUID(base64Encoded: tag.value)
            case Xml2.data:
                xmlData = ByteArray(base64Encoded: tag.value ?? "")
            case Xml2.name:
                xmlName = tag.value
            case Xml2.lastModificationTime:
                xmlLastModificationTime = timeParser(tag.value)
            default:
                Diag.error("Unexpected XML tag in CustomIcon: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "CustomIcon/*")
            }
        }
        if xmlUUID == nil {
            Diag.warning("Missing CustomIcon/UUID. Will generate a new one.")
        }
        let _uuid = xmlUUID ?? UUID()
        guard let _data = xmlData else {
            Diag.error("Missing CustomIcon/Data")
            throw Xml2.ParsingError.malformedValue(tag: "CustomIcon/Data", value: nil)
        }
        self.uuid = _uuid
        self.data = _data
        self.name = xmlName
        self.lastModificationTime = xmlLastModificationTime
    }

    func toXml(
        formatVersion: Database2.FormatVersion,
        timeFormatter: Database2.XMLTimeFormatter
    ) -> AEXMLElement {
        Diag.verbose("Generating XML: custom icon")
        let xmlIcon = AEXMLElement(name: Xml2.icon)
        xmlIcon.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xmlIcon.addChild(name: Xml2.data, value: data.base64EncodedString())

        if formatVersion.supports(.customIconName),
           let name = name
        {
            xmlIcon.addChild(name: Xml2.name, value: name)
        }

        if formatVersion.supports(.customIconModificationTime),
           let lastModificationTime = lastModificationTime
        {
            xmlIcon.addChild(
                name: Xml2.lastModificationTime,
                value: timeFormatter(lastModificationTime)
            )
        }

        return xmlIcon
    }
}

extension CustomIcon2 {
    typealias ParsingCompletionHandler = (CustomIcon2) -> Void
    private class ParsingContext: XMLReaderContext {
        var uuid: UUID?
        var data: ByteArray?
        var name: String?
        var lastModificationTime: Date?
        var completion: ParsingCompletionHandler
        init(completion: @escaping ParsingCompletionHandler) {
            self.completion = completion
        }
    }

    static func readFromXML(_ xml: DatabaseXMLParserStream, completion: @escaping (CustomIcon2) -> Void) throws {
        assert(xml.name == Xml2.icon)
        let icon = CustomIcon2()
        try xml.pushReader(
            icon.parseIconElement,
            context: ParsingContext(completion: completion)
        )
    }

    private func parseIconElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParsingContext

        switch (xml.name, xml.event) {
        case (Xml2.icon, .start):
            Diag.verbose("Loading XML: custom icon")
        case (Xml2.uuid, .end):
            context.uuid = UUID(base64Encoded: xml.value)
        case (Xml2.data, .end):
            context.data = ByteArray(base64Encoded: xml.value ?? "")
        case (Xml2.name, .end):
            context.name = xml.value
        case (Xml2.lastModificationTime, .end):
            let timeParser = xml.documentContext.timeParser
            context.lastModificationTime = timeParser(xml.value)
        case (Xml2.icon, .end):
            guard let data = context.data else {
                Diag.error("Missing CustomIcon/Data")
                throw Xml2.ParsingError.malformedValue(tag: "CustomIcon/Data", value: nil)
            }
            if context.uuid == nil {
                Diag.warning("Missing CustomIcon/UUID. Will generate a new one.")
            }
            self.uuid = context.uuid ?? UUID()
            self.data = data
            self.name = context.name
            self.lastModificationTime = context.lastModificationTime
            context.completion(self)
            Diag.verbose("Custom icon loaded OK")
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in CustomIcon: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "CustomIcon/*")
        }
    }
}
