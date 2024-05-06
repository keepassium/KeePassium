//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

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
}

extension EntryField2 {
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
                            if Diag.isDeepDebugMode() {
                                Diag.debug("Encrypted field value: `\(encData.asHexString)`")
                                Diag.debug("Decrypted field value: `\(plainData.asHexString)`")
                            }
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

extension EntryField2 {
    typealias ParsingCompletion = (EntryField2) -> Void
    final private class ParsingContext: XMLReaderContext {
        var key: String?
        var value: String?
        var completion: ParsingCompletion
        init(completion: @escaping ParsingCompletion) {
            self.completion = completion
        }
    }

    static func readFromXML(_ xml: DatabaseXMLParserStream, completion: @escaping ParsingCompletion) throws {
        assert(xml.name == Xml2.string)
        Diag.verbose("Loading XML: entry field")
        let field = EntryField2(name: "", value: "", isProtected: false)
        try xml.pushReader(
            field.parseStringElement,
            context: ParsingContext(completion: completion)
        )
    }

    private func parseStringElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParsingContext
        switch (xml.name, xml.event) {
        case (Xml2.string, .start): break
        case (Xml2.key, .end):
            context.key = xml.value ?? ""
        case (Xml2.value, .end):
            isProtected = Bool(string: xml.attributes[Xml2.protected])
            if isProtected {
                let streamCipher = xml.documentContext.streamCipher
                context.value = try decryptFieldValue(xml.value, streamCipher: streamCipher)
            } else {
                context.value = xml.value ?? ""
            }
        case (Xml2.string, .end):
            guard let key = context.key else {
                Diag.error("Missing Entry/String/Key")
                throw Xml2.ParsingError.malformedValue(tag: "Entry/String/Key", value: nil)
            }
            guard let value = context.value else {
                Diag.error("Missing Entry/String/Value")
                throw Xml2.ParsingError.malformedValue(tag: "Entry/String/Value", value: nil)
            }
            if key.isEmpty && value.isNotEmpty {
                Diag.error("Missing Entry/String/Key with present Value")
            }
            self.name = key
            self.value = value
            Diag.verbose("Entry field loaded OK")
            context.completion(self)
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Entry/String: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Entry/String/*")
        }
    }

    private func decryptFieldValue(_ encryptedValue: String?, streamCipher: StreamCipher) throws -> String? {
        guard let encData = ByteArray(base64Encoded: encryptedValue ?? "") else {
            Diag.debug("Encrypted field value is not Base64-encoded")
            return nil
        }
        Diag.verbose("Decrypting field value")
        let plainData = try streamCipher.decrypt(data: encData, progress: nil)
        let result = plainData.toString(using: .utf8)
        if result == nil {
            Diag.warning("Failed to decrypt field value")
            if Diag.isDeepDebugMode() {
                Diag.debug("Encrypted field value: `\(encData.asHexString)`")
                Diag.debug("Decrypted field value: `\(plainData.asHexString)`")
            }
        }
        return result
    }
}
