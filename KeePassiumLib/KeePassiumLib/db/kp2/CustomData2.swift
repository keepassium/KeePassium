//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class CustomData2: Eraseable {
    
    public typealias Dict = Dictionary<Key, Item>
    
    public typealias Key = String
    
    public class Item: Eraseable {
        public var value: String
        public var lastModificationTime: Date? 
        
        init(value: String, lastModificationTime: Date?) {
            self.value = value
            self.lastModificationTime = lastModificationTime
        }
        
        deinit {
            erase()
        }
        
        public func erase() {
            value.erase()
            lastModificationTime = nil
        }
    }
    
    private var dict: Dict
    private weak var database: Database?
    
    init(database: Database?) {
        dict = [:]
        self.database = database
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        dict.removeAll() 
    }
    
    internal func clone() -> CustomData2 {
        let copy = CustomData2(database: database)
        copy.dict.reserveCapacity(self.dict.capacity)
        self.dict.forEach { (key, value) in
            copy.dict.updateValue(value, forKey: key)
        }
        return copy
    }
    
    func load(
        xml: AEXMLElement,
        streamCipher: StreamCipher,
        timeParser: Database2XMLTimeParser,
        xmlParentName: String
    ) throws {
        assert(xml.name == Xml2.customData)
        Diag.verbose("Loading XML: custom data")
        erase()
        for tag in xml.children {
            switch tag.name {
            case Xml2.item:
                try loadItem(
                    xml: tag,
                    streamCipher: streamCipher,
                    timeParser: timeParser,
                    xmlParentName: xmlParentName
                )
                Diag.verbose("Item loaded OK")
            default:
                Diag.error("Unexpected XML tag in CustomData: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: xmlParentName + "/CustomData/*")
            }
        }
    }
    
    private func loadItem(
        xml: AEXMLElement,
        streamCipher: StreamCipher,
        timeParser: Database2XMLTimeParser,
        xmlParentName: String = "?") throws
    {
        assert(xml.name == Xml2.item)
        var key: String?
        var value: String?
        var optionalTimestamp: Date? 
        for tag in xml.children {
            switch tag.name {
            case Xml2.key:
                key = tag.value ?? ""
            case Xml2.value:
                value = tag.value ?? ""
            case Xml2.lastModificationTime:
                optionalTimestamp = timeParser.xmlStringToDate(tag.value)
            default:
                Diag.error("Unexpected XML tag in CustomData/Item: \(tag.name)")
                throw Xml2.ParsingError.unexpectedTag(
                    actual: tag.name,
                    expected: xmlParentName + "/CustomData/Item/*")
            }
        }
        guard let _key = key else {
            Diag.error("Missing \(xmlParentName)/CustomData/Item/Key")
            throw Xml2.ParsingError.malformedValue(
                tag: xmlParentName + "/CustomData/Item/Key",
                value: nil)
        }
        guard let _value = value else {
            Diag.error("Missing \(xmlParentName)/CustomData/Item/Value")
            throw Xml2.ParsingError.malformedValue(
                tag: xmlParentName + "/CustomData/Item/Value",
                value: nil)
        }
        dict[_key] = Item(value: _value, lastModificationTime: optionalTimestamp)
    }
    
    
    func toXml(timeFormatter: Database2XMLTimeFormatter) -> AEXMLElement {
        Diag.verbose("Generating XML: custom data")
        let xml = AEXMLElement(name: Xml2.customData)
        if dict.isEmpty {
            return xml
        }
        
        for keyValuePair in dict {
            let xmlItem = xml.addChild(name: Xml2.item)
            xmlItem.addChild(name: Xml2.key, value: keyValuePair.key)
            let item = keyValuePair.value
            xmlItem.addChild(name: Xml2.value, value: item.value)
            if let timestamp = item.lastModificationTime {
                let timestampString = timeFormatter.dateToXMLString(timestamp)
                xmlItem.addChild(name: Xml2.lastModificationTime, value: timestampString)
            }
        }
        return xml
    }
}

extension CustomData2: Collection {
    public var startIndex: Dict.Index { return dict.startIndex }
    public var endIndex: Dict.Index { return dict.endIndex }
    public subscript(position: Dict.Index) -> Dict.Iterator.Element { return dict[position] }
    public subscript(bounds: Range<Dict.Index>) -> Dict.SubSequence { return dict[bounds] }
    public var indices: Dict.Indices { return dict.indices }
    public subscript(key: Key) -> Item? {
        get { return dict[key] }
        set { dict[key] = newValue }
    }
    public func index(after i: Dict.Index) -> Dict.Index {
        return dict.index(after: i)
    }
    public func makeIterator() -> Dict.Iterator {
        return dict.makeIterator()
    }
}
