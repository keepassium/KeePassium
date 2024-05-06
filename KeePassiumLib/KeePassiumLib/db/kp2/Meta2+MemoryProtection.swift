//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension Meta2 {
    final class MemoryProtection {
        private(set) var isProtectTitle: Bool = false
        private(set) var isProtectUserName: Bool = false
        private(set) var isProtectPassword: Bool = false
        private(set) var isProtectURL: Bool = false
        private(set) var isProtectNotes: Bool = false

        func erase() {
            isProtectTitle = false
            isProtectUserName = false
            isProtectPassword = true
            isProtectURL = false
            isProtectNotes = false
        }
    }
}

extension Meta2.MemoryProtection {
    func load(xml: AEXMLElement) throws {
        assert(xml.name == Xml2.memoryProtection)
        Diag.verbose("Loading XML: memory protection")

        erase()
        for tag in xml.children {
            switch tag.name {
            case Xml2.protectTitle:
                isProtectTitle = Bool(string: tag.value)
            case Xml2.protectUserName:
                isProtectUserName = Bool(string: tag.value)
            case Xml2.protectPassword:
                isProtectPassword = Bool(string: tag.value)
            case Xml2.protectURL:
                isProtectURL = Bool(string: tag.value)
            case Xml2.protectNotes:
                isProtectNotes = Bool(string: tag.value)
            default:
                Diag.error("Unexpected XML tag in Meta/MemoryProtection: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: "Meta/MemoryProtection/*")
            }
        }
    }

    func toXml() -> AEXMLElement {
        Diag.verbose("Generating XML: memory protection")
        let xmlMP = AEXMLElement(name: Xml2.memoryProtection)
        xmlMP.addChild(
            name: Xml2.protectTitle,
            value: isProtectTitle ? Xml2._true : Xml2._false)
        xmlMP.addChild(
            name: Xml2.protectUserName,
            value: isProtectUserName ? Xml2._true : Xml2._false)
        xmlMP.addChild(
            name: Xml2.protectPassword,
            value: isProtectPassword ? Xml2._true : Xml2._false)
        xmlMP.addChild(
            name: Xml2.protectURL,
            value: isProtectURL ? Xml2._true : Xml2._false)
        xmlMP.addChild(
            name: Xml2.protectNotes,
            value: isProtectNotes ? Xml2._true : Xml2._false)
        return xmlMP
    }
}

extension Meta2.MemoryProtection {
    func loadFromXML(_ xml: DatabaseXMLParserStream) throws {
        erase()
        try xml.pushReader(parseMemoryProtectionElement, context: nil)
    }

    private func parseMemoryProtectionElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.memoryProtection, .start):
            Diag.verbose("Loading XML: memory protection")
        case (Xml2.protectTitle, .end):
            isProtectTitle = Bool(string: xml.value)
        case (Xml2.protectUserName, .end):
            isProtectUserName = Bool(string: xml.value)
        case (Xml2.protectPassword, .end):
            isProtectPassword = Bool(string: xml.value)
        case (Xml2.protectURL, .end):
            isProtectURL = Bool(string: xml.value)
        case (Xml2.protectNotes, .end):
            isProtectNotes = Bool(string: xml.value)
        case (Xml2.memoryProtection, .end):
            Diag.verbose("Memory protection loaded OK")
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Meta/MemoryProtection: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(
                actual: xml.name,
                expected: "Meta/MemoryProtection/*")
        }
    }
}
