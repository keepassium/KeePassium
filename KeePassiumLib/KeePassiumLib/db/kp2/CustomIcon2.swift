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
    
    public var description: String {
        return "CustomIcon(UUID: \(uuid.uuidString), Data: \(data.count) bytes"
    }
    init() {
        uuid = UUID.ZERO
        data = ByteArray()
    }
    deinit {
        erase()
    }
    
    public func erase() {
        uuid.erase()
        data.erase()
    }
    
    func load(xml: AEXMLElement) throws {
        assert(xml.name == Xml2.icon)
        Diag.verbose("Loading XML: custom icon")
        
        erase()
        var xmlUUID: UUID?
        var xmlData: ByteArray?
        for tag in xml.children {
            switch tag.name {
            case Xml2.uuid:
                xmlUUID = UUID(base64Encoded: tag.value)
            case Xml2.data:
                xmlData = ByteArray(base64Encoded: tag.value ?? "")
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
    }
    
    func toXml() -> AEXMLElement {
        Diag.verbose("Generating XML: custom icon")
        let xmlIcon = AEXMLElement(name: Xml2.icon)
        xmlIcon.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xmlIcon.addChild(name: Xml2.data, value: data.base64EncodedString())
        return xmlIcon
    }
}
