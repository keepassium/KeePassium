//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class DeletedObject2: Eraseable {
    private(set) var uuid: UUID
    private(set) var deletionTime: Date

    init(uuid: UUID) {
        self.uuid = uuid
        self.deletionTime = Date.now
    }
    convenience init() {
        self.init(uuid: UUID.ZERO)
    }
    deinit {
        erase()
    }

    public func erase() {
        uuid.erase()
        deletionTime = Date.now
    }
}

extension DeletedObject2 {
    func load(xml: AEXMLElement, timeParser: Database2.XMLTimeParser) throws {
        assert(xml.name == Xml2.deletedObject)
        Diag.verbose("Loading XML: deleted object")
        erase()
        for tag in xml.children {
            switch tag.name {
            case Xml2.uuid:
                self.uuid = UUID(base64Encoded: tag.value) ?? UUID.ZERO
            case Xml2.deletionTime:
                guard let deletionTime = timeParser(tag.value) else {
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

    func toXml(timeFormatter: Database2.XMLTimeFormatter) -> AEXMLElement {
        Diag.verbose("Generating XML: deleted object")
        let xml = AEXMLElement(name: Xml2.deletedObject)
        xml.addChild(name: Xml2.uuid, value: uuid.base64EncodedString())
        xml.addChild(name: Xml2.deletionTime, value: timeFormatter(deletionTime))
        return xml
    }
}

extension DeletedObject2 {
    typealias ParsingCompletion = (DeletedObject2) -> Void
    private final class ParsingContext: XMLReaderContext {
        var uuid: UUID?
        var deletionTime: Date?
        var completion: ParsingCompletion
        init(completion: @escaping ParsingCompletion) {
            self.completion = completion
        }
    }

    static func readFromXML(_ xml: DatabaseXMLParserStream, completion: @escaping ParsingCompletion) throws {
        let object = DeletedObject2()
        try xml.pushReader(
            object.parseDeletedObjectElement,
            context: ParsingContext(completion: completion)
        )
    }

    private func parseDeletedObjectElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParsingContext
        switch (xml.name, xml.event) {
        case (Xml2.deletedObject, .start):
            Diag.verbose("Loading XML: deleted object")
        case (Xml2.uuid, .start): break
        case (Xml2.uuid, .end):
            context.uuid = UUID(base64Encoded: xml.value)
        case (Xml2.deletionTime, .start): break
        case (Xml2.deletionTime, .end):
            let timeParser = xml.documentContext.timeParser
            guard let deletionTime = timeParser(xml.value) else {
                Diag.error("Cannot parse DeletedObject/DeletionTime as Date")
                throw Xml2.ParsingError.malformedValue(tag: "DeletedObject/DeletionTime", value: xml.value)
            }
            context.deletionTime = deletionTime
        case (Xml2.deletedObject, .end):
            if context.uuid == nil {
                Diag.warning("UUID is missing, ignoring")
            }
            if context.deletionTime == nil {
                Diag.warning("Deletion time is missing, ignoring")
            }
            self.uuid = context.uuid ?? UUID.ZERO
            self.deletionTime = context.deletionTime ?? .now
            context.completion(self)
            xml.popReader()
        default:
            Diag.error("Unexpected XML tag in DeletedObject: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "DeletedObject/*")
        }
    }
}
