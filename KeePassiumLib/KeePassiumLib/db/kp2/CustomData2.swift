//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class CustomData2: Collection, Eraseable {
    public typealias Dict = Dictionary<String, String>
    
    public var startIndex: Dict.Index { return dict.startIndex }
    public var endIndex: Dict.Index { return dict.endIndex }
    public subscript(position: Dict.Index) -> Dict.Iterator.Element { return dict[position] }
    public subscript(bounds: Range<Dict.Index>) -> Dict.SubSequence { return dict[bounds] }
    public var indices: Dict.Indices { return dict.indices }
    public subscript(key: String) -> String? {
        get { return dict[key] }
        set { dict[key] = newValue }
    }
    public func index(after i: Dict.Index) -> Dict.Index {
        return dict.index(after: i)
    }
    public func makeIterator() -> Dict.Iterator {
        return dict.makeIterator()
    }
    
    private var dict: Dict
    init() {
        dict = [:]
    }
    deinit {
        erase()
    }
    public func erase() {
        dict.removeAll() 
    }
    internal func clone() -> CustomData2 {
        let copy = CustomData2()
        copy.dict = self.dict 
        return copy
    }
    
    func load(xml: AEXMLElement, streamCipher: StreamCipher, xmlParentName: String) throws {
        assert(xml.name == Xml2.customData)
        Diag.verbose("Loading XML: custom data")
        erase()
        for tag in xml.children {
            switch tag.name {
            case Xml2.item:
                try loadItem(xml: tag, streamCipher: streamCipher)
                Diag.verbose("Item loaded OK")
            default:
                Diag.error("Unexpected XML tag in CustomData: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: xmlParentName + "/CustomData/*")
            }
        }
    }
    
    private func loadItem(xml: AEXMLElement, streamCipher: StreamCipher,
                          xmlParentName: String = "?") throws {
        assert(xml.name == Xml2.item)
        var key: String?
        var value: String?
        for tag in xml.children {
            switch tag.name {
            case Xml2.key:
                key = tag.value ?? ""
            case Xml2.value:
                value = tag.value ?? "" 
            default:
                Diag.error("Unexpected XML tag in CustomData/Item: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: xmlParentName + "/CustomData/Item/*")
            }
        }
        guard let _key = key else {
            Diag.error("Missing /CustomData/Item/Key")
            throw Xml2.ParsingError.malformedValue(
                tag: xmlParentName + "/CustomData/Item/Key",
                value: nil)
        }
        guard let _value = value else {
            Diag.error("Missing /CustomData/Item/Value")
            throw Xml2.ParsingError.malformedValue(
                tag: xmlParentName + "/CustomData/Item/Value",
                value: nil)
        }
        dict[_key] = _value
    }
    
    
    func toXml() -> AEXMLElement {
        Diag.verbose("Generating XML: custom data")
        let xml = AEXMLElement(name: Xml2.customData)
        if dict.isEmpty {
            return xml
        }
        
        for dictItem in dict {
            let xmlItem = xml.addChild(name: Xml2.item)
            xmlItem.addChild(name: Xml2.key, value: dictItem.key)
            xmlItem.addChild(name: Xml2.value, value: dictItem.value)
        }
        return xml
    }
}
