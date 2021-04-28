//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class CustomIcon2: Eraseable {
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
    
    func load(xml: AEXMLElement, timeParser: Database2XMLTimeParser) throws {
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
                xmlLastModificationTime = timeParser.xmlStringToDate(tag.value)
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
        timeFormatter: Database2XMLTimeFormatter
    ) -> AEXMLElement {
        Diag.verbose("Generating XML: custom icon")
        let xmlIcon = AEXMLElement(name: Xml2.icon)
        xmlIcon.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xmlIcon.addChild(name: Xml2.data, value: data.base64EncodedString())
        
        guard formatVersion >= .v4_1 else {
            return xmlIcon
        }
        
        if let name = name {
            xmlIcon.addChild(name: Xml2.name, value: name)
        }
        if let lastModificationTime = lastModificationTime {
            xmlIcon.addChild(
                name: Xml2.lastModificationTime,
                value: timeFormatter.dateToXMLString(lastModificationTime)
            )
        }

        return xmlIcon
    }
}
