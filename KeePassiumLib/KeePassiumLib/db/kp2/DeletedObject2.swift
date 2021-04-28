//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class DeletedObject2: Eraseable {
    private weak var database: Database2?
    private(set) var uuid: UUID
    private(set) var deletionTime: Date
    
    init(database: Database2, uuid: UUID) {
        self.database = database
        self.uuid = uuid
        self.deletionTime = Date.now
    }
    convenience init(database: Database2) {
        self.init(database: database, uuid: UUID.ZERO)
    }
    deinit {
        erase()
    }
    
    public func erase() {
        uuid.erase()
        deletionTime = Date.now
    }
    
    func load(xml: AEXMLElement, timeParser: Database2XMLTimeParser) throws {
        assert(xml.name == Xml2.deletedObject)
        Diag.verbose("Loading XML: deleted object")
        erase()
        for tag in xml.children {
            switch tag.name {
            case Xml2.uuid:
                self.uuid = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.deletionTime:
                guard let deletionTime = timeParser.xmlStringToDate(tag.value) else {
                    Diag.error("Cannot parse DeletedObject/DeletionTime as Date")
                    throw Xml2.ParsingError.malformedValue(
                        tag: "DeletedObject/DeletionTime",
                        value: tag.value)
                }
                self.deletionTime = deletionTime
            default:
                Diag.error("Unexpected XML tag in DeletedObject: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: "DeletedObject/*")
            }
        }
    }
    
    func toXml(timeFormatter: Database2XMLTimeFormatter) -> AEXMLElement {
        Diag.verbose("Generating XML: deleted object")
        let xml = AEXMLElement(name: Xml2.deletedObject)
        xml.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xml.addChild(name: Xml2.deletionTime, value: timeFormatter.dateToXMLString(deletionTime))
        return xml
    }
}

