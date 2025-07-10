//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Binary2: Eraseable {
    public typealias ID = Int 

    private(set) var id: Binary2.ID

    private(set) var data: ByteArray

    private(set) var isCompressed: Bool

    private(set) var isProtected: Bool

    public var flags: UInt8 {
        return isProtected ? 1 : 0
    }

    init(id: Binary2.ID, data: ByteArray, isCompressed: Bool, isProtected: Bool) {
        self.id = id
        self.data = data.clone()
        self.isCompressed = isCompressed
        self.isProtected = isProtected
    }

    deinit {
        erase()
    }

    public func erase() {
        id = -1
        isCompressed = false
        isProtected = false
        data.erase()
    }
}

extension Binary2 {

    static func load(xml: AEXMLElement, streamCipher: StreamCipher) throws -> Binary2 {
        assert(xml.name == Xml2.binary)
        Diag.verbose("Loading XML: binary")

        let idString = xml.attributes[Xml2.id]
        guard let id = Int(idString) else {
            Diag.error("Cannot parse Meta/Binary/ID as Int")
            throw Xml2.ParsingError.malformedValue(tag: "Meta/Binary/ID", value: idString)
        }
        let isCompressedString = xml.attributes[Xml2.compressed]
        let isProtectedString = xml.attributes[Xml2.protected]
        let isCompressed: Bool = Bool(string: isCompressedString ?? "")
        let isProtected: Bool = Bool(string: isProtectedString ?? "")
        let base64 = xml.value ?? ""
        guard var data = ByteArray(base64Encoded: base64) else {
            Diag.error("Cannot parse Meta/Binary/Value as Base64 string")
            throw Xml2.ParsingError.malformedValue(tag: "Meta/Binary/ValueBase64", value: String(base64.prefix(16)))
        }

        if isProtected {
            Diag.verbose("Decrypting binary")
            data = try streamCipher.decrypt(data: data, progress: nil) 
        }

        return Binary2(id: id, data: data, isCompressed: isCompressed, isProtected: isProtected)
    }

    func toXml(streamCipher: StreamCipher) throws -> AEXMLElement {
        Diag.verbose("Generating XML: binary")
        var attributes = [
            Xml2.id: String(id),
            Xml2.compressed: isCompressed ? Xml2._true : Xml2._false
        ]

        let value: ByteArray
        if isProtected {
            Diag.verbose("Encrypting binary")
            value = try streamCipher.encrypt(data: data, progress: nil) 
            attributes[Xml2.protected] = Xml2._true
        } else {
            value = data
        }
        return AEXMLElement(
            name: Xml2.binary,
            value: value.base64EncodedString(),
            attributes: attributes)
    }
}

extension Binary2 {
    typealias BinaryLoadedCallback = (Binary2) throws -> Void

    private class ParserContext: XMLReaderContext {
        let onLoadCallback: BinaryLoadedCallback
        init(onLoad: @escaping BinaryLoadedCallback) {
            self.onLoadCallback = onLoad
        }
    }

    convenience private init() {
        self.init(id: 0, data: ByteArray(), isCompressed: false, isProtected: false)
    }

    static func readFromXML(_ xml: DatabaseXMLParserStream, completion: @escaping BinaryLoadedCallback) throws {
        let context = ParserContext(onLoad: completion)
        let binary = Binary2()
        try xml.pushReader(binary.parseBinaryElement, context: context)
    }

    private func parseBinaryElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! ParserContext
        switch (xml.name, xml.event) {
        case (Xml2.binary, .start):
            guard !xml.documentContext.progress.isCancelled else {
                Diag.info("Cancelled by user request")
                throw ProgressInterruption.cancelled(reason: .userRequest)
            }
            Diag.verbose("Loading XML: binary")
        case (Xml2.binary, .end):
            let idString = xml.attributes[Xml2.id]
            guard let id = Int(idString) else {
                Diag.error("Cannot parse Meta/Binary/ID as Int")
                throw Xml2.ParsingError.malformedValue(tag: "Meta/Binary/ID", value: idString)
            }
            self.id = id
            self.isCompressed = Bool(string: xml.attributes[Xml2.compressed] ?? "")
            self.isProtected = Bool(string: xml.attributes[Xml2.protected] ?? "")

            let base64 = xml.value ?? ""
            guard let data = ByteArray(base64Encoded: base64) else {
                Diag.error("Cannot parse Meta/Binary/Value as Base64 string")
                throw Xml2.ParsingError.malformedValue(tag: "Meta/Binary/ValueBase64", value: String(base64.prefix(16)))
            }
            if isProtected {
                Diag.verbose("Decrypting binary")
                let streamCipher = xml.documentContext.streamCipher
                self.data = try streamCipher.decrypt(data: data, progress: nil)
            }
            try context.onLoadCallback(self)

            Diag.verbose("Binary loaded OK")
            xml.popReader()
        default:
            Diag.error("Unexpected XML tag in Meta/Binaries/Binary: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Meta/Binaries/Binary/*")
        }
    }

}
