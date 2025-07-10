//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension Entry2 {
    public class AutoType: Eraseable {
        public struct Association {
            var window: String
            var keystrokeSequence: String
        }
        public var isEnabled: Bool
        var obfuscationType: UInt32
        var defaultSequence: String
        var associations: [Association]

        init(from original: AutoType) {
            isEnabled = original.isEnabled
            obfuscationType = original.obfuscationType
            defaultSequence = original.defaultSequence
            associations = original.associations
        }
        init() {
            isEnabled = true
            obfuscationType = 0
            defaultSequence = ""
            associations = []
        }
        deinit {
            erase()
        }

        public func erase() {
            isEnabled = true
            obfuscationType = 0
            defaultSequence.erase()
            associations.removeAll()
        }

        func clone() -> AutoType {
            return AutoType(from: self)
        }
    }
}

extension Entry2.AutoType {
    func load(xml: AEXMLElement, streamCipher: StreamCipher) throws {
        assert(xml.name == Xml2.autoType)
        Diag.verbose("Loading XML: entry autotype")
        erase()

        for tag in xml.children {
            switch tag.name {
            case Xml2.enabled:
                isEnabled = Bool(string: tag.value)
            case Xml2.dataTransferObfuscation:
                obfuscationType = UInt32(tag.value) ?? 0
            case Xml2.defaultSequence:
                defaultSequence = tag.value ?? ""
            case Xml2.association:
                try loadAssociation(xml: tag)
            default:
                Diag.error("Unexpected XML tag in Entry/AutoType: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(actual: tag.name, expected: "Entry/AutoType/*")
            }
        }
    }

    func loadAssociation(xml: AEXMLElement) throws {
        assert(xml.name == Xml2.association)

        var window: String?
        var sequence: String?
        for tag in xml.children {
            switch tag.name {
            case Xml2.window:
                window = tag.value ?? ""
            case Xml2.keystrokeSequence:
                sequence = tag.value ?? ""
            default:
                Diag.error("Unexpected XML tag in Entry/AutoType/Association: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: "Entry/AutoType/Association/*")
            }
        }
        guard window != nil else {
            Diag.error("Missing Entry/AutoType/Association/Window")
            throw Xml2.ParsingError.malformedValue(
                tag: "Entry/AutoType/Association/Window",
                value: window)
        }
        guard sequence != nil else {
            Diag.error("Missing Entry/AutoType/Association/Sequence")
            throw Xml2.ParsingError.malformedValue(
                tag: "Entry/AutoType/Association/Sequence",
                value: sequence)
        }
        associations.append(Association(window: window!, keystrokeSequence: sequence!))
    }

    internal func toXml() -> AEXMLElement {
        Diag.verbose("Generating XML: entry autotype")
        let xmlAutoType = AEXMLElement(name: Xml2.autoType)
        xmlAutoType.addChild(
            name: Xml2.enabled,
            value: isEnabled ? Xml2._true : Xml2._false)
        xmlAutoType.addChild(
            name: Xml2.dataTransferObfuscation,
            value: String(obfuscationType))

        if !defaultSequence.isEmpty {
            xmlAutoType.addChild(
                name: Xml2.defaultSequence,
                value: defaultSequence)
        }
        for association in associations {
            let xmlAssoc = xmlAutoType.addChild(name: Xml2.association)
            xmlAssoc.addChild(
                name: Xml2.window,
                value: association.window)
            xmlAssoc.addChild(
                name: Xml2.keystrokeSequence,
                value: association.keystrokeSequence)
        }
        return xmlAutoType
    }
}

extension Entry2.AutoType {
    private final class AssociationParsingContext: XMLReaderContext {
        var window: String?
        var sequence: String?
    }

    func loadFromXML(_ xml: DatabaseXMLParserStream) throws {
        assert(xml.name == Xml2.autoType)
        erase()
        Diag.verbose("Loading XML: entry autotype")
        try xml.pushReader(parseAutoTypeElement, context: nil)
    }

    private func parseAutoTypeElement(_ xml: DatabaseXMLParserStream) throws {
        switch (xml.name, xml.event) {
        case (Xml2.autoType, .start): break
        case (Xml2.enabled, .end):
            self.isEnabled = Bool(string: xml.value)
        case (Xml2.dataTransferObfuscation, .end):
            self.obfuscationType = UInt32(xml.value) ?? 0
        case (Xml2.defaultSequence, .end):
            self.defaultSequence = xml.value ?? ""
        case (Xml2.association, .start):
            try xml.pushReader(parseAssociationElement, context: AssociationParsingContext())
        case (Xml2.autoType, .end):
            Diag.verbose("Entry autotype loaded OK")
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Entry/AutoType: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Entry/AutoType/*")
        }
    }

    private func parseAssociationElement(_ xml: DatabaseXMLParserStream) throws {
        let context = xml.readerContext as! AssociationParsingContext
        switch (xml.name, xml.event) {
        case (Xml2.association, .start): break
        case (Xml2.window, .end):
            context.window = xml.value ?? ""
        case (Xml2.keystrokeSequence, .end):
            context.sequence = xml.value ?? ""
        case (Xml2.association, .end):
            guard let window = context.window else {
                Diag.error("Missing Entry/AutoType/Association/Window")
                throw Xml2.ParsingError.malformedValue(
                    tag: "Entry/AutoType/Association/Window",
                    value: context.window)
            }
            guard let sequence = context.sequence else {
                Diag.error("Missing Entry/AutoType/Association/Sequence")
                throw Xml2.ParsingError.malformedValue(
                    tag: "Entry/AutoType/Association/Sequence",
                    value: context.sequence)
            }
            associations.append(Association(window: window, keystrokeSequence: sequence))
            xml.popReader()
        case (_, .start): break
        default:
            Diag.error("Unexpected XML tag in Entry/AutoType/Association: \(xml.name)")
            throw Xml2.ParsingError.unexpectedTag(actual: xml.name, expected: "Entry/AutoType/Association/*")
        }
    }
}
