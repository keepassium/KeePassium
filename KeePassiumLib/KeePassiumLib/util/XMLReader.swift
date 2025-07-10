//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

typealias XMLReader<DocumentContext: XMLDocumentContext> = (_ xml: XMLParserStream<DocumentContext>) throws -> Void

protocol XMLReaderContext {
}

protocol XMLDocumentContext {
}

class XMLParserStream<DocumentContext: XMLDocumentContext>: CustomStringConvertible {
    public enum EventType {
        case start
        case end
    }

    public fileprivate(set) var event: EventType
    public fileprivate(set) var name: String
    public fileprivate(set) var attributes = [String: String]()
    public fileprivate(set) var value: String?

    public fileprivate(set) var readerContext: XMLReaderContext?
    public fileprivate(set) var documentContext: DocumentContext

    unowned private var docReader: XMLDocumentReader<DocumentContext>

    var description: String {
        let padding = String(repeating: "  ", count: parentElements.count)
        let type = (event == .end) ? "/" : ""
        return "\(padding)\(type)\(name) \(attributes)\t\(value ?? "")"
    }

    private var parentElements = [String]()
    public var path: String {
        var elements = parentElements
        elements.append(name)
        return elements.joined(separator: "/")
    }

    fileprivate init(_ docReader: XMLDocumentReader<DocumentContext>, documentContext: DocumentContext) {
        self.event = .end
        self.name = ""
        self.value = nil
        self.docReader = docReader
        self.documentContext = documentContext
    }

    func pushReader(
        _ reader: @escaping XMLReader<DocumentContext>,
        context: XMLReaderContext?,
        repeatEvent: Bool = true
    ) throws {
        parentElements.append(name)
        docReader.pushReader(reader, context: context)
        if repeatEvent {
            try reader(self)
        }
    }

    func popReader() {
        docReader.popReader()
        _ = parentElements.popLast()
    }
}

class XMLDocumentReader<DocumentContext: XMLDocumentContext>: NSObject, XMLParserDelegate {
    public private(set) var error: Error?

    private let parser: XMLParser
    private var startedElement: String?
    private var currentAttributes: [String: String]
    private var accumulatedString: String?
    private var readerStack: [XMLReader<DocumentContext>]
    private var readerContextStack: [XMLReaderContext?]
    private var currentStreamState: XMLParserStream<DocumentContext>!

    init(xmlData: Data, documentContext: DocumentContext) {
        parser = XMLParser(data: xmlData)
        readerStack = []
        readerContextStack = []
        currentAttributes = [:]
        super.init()
        parser.delegate = self
        currentStreamState = XMLParserStream<DocumentContext>(self, documentContext: documentContext)
    }
    deinit {
        if error == nil {
            assert(readerStack.isEmpty, "Some XML readers left in the stack: imbalanced pushReader/popReader calls?")
        }
        readerStack.removeAll()
        readerContextStack.removeAll()
    }

    public func parse() throws {
        assert(!readerStack.isEmpty, "Push at least one reader before parsing.")
        parser.parse()
        if let error {
            throw error
        }
    }

    public func pushReader(_ reader: @escaping XMLReader<DocumentContext>, context: XMLReaderContext?) {
        readerStack.append(reader)
        readerContextStack.append(context)
        currentStreamState.readerContext = context
    }

    public func popReader() {
        _ = readerStack.popLast()
        _ = readerContextStack.popLast()
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        if let error {
            Diag.error("XML processing error: \(error)")
            parser.abortParsing()
            return
        }
        self.error = parseError
        let nsError = parseError as NSError
        Diag.error("XML parsing error: \(nsError)")
    }

    private func pushEvent(
        _ event: XMLParserStream<DocumentContext>.EventType,
        _ name: String,
        value: String?,
        attributes: [String: String],
        from parser: XMLParser
    ) {
        currentStreamState.event = event
        currentStreamState.name = name
        currentStreamState.value = value
        currentStreamState.attributes = attributes
        currentStreamState.readerContext = readerContextStack.last as? XMLReaderContext
        do {
            try readerStack.last?(currentStreamState)
        } catch {
            self.error = error
            parser.abortParsing()
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if let startedElement {
            pushEvent(.start, startedElement, value: nil, attributes: currentAttributes, from: parser)
        }
        accumulatedString = nil
        startedElement = elementName
        currentAttributes = attributeDict
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard startedElement != nil else {
            return
        }
        if accumulatedString != nil {
            accumulatedString = accumulatedString! + string
        } else {
            accumulatedString = string
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if startedElement != nil {
            pushEvent(.start, elementName, value: nil, attributes: currentAttributes, from: parser)
            guard error == nil else {
                return
            }
        }
        pushEvent(.end, elementName, value: accumulatedString, attributes: currentAttributes, from: parser)
        accumulatedString = nil
        startedElement = nil
        currentAttributes = [:]
    }
}
