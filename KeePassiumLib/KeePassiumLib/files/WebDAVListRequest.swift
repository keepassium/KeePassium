//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

final class WebDAVListRequest: WebDAVRequestBase {
    typealias Completion = (Result<[WebDAVItem], Error>) -> Void

    let completionQueue: OperationQueue
    let completion: Completion
    let folder: WebDAVItem

    init(
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        folder: WebDAVItem,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping Completion
    ) {
        self.completionQueue = completionQueue
        self.completion = completion
        self.folder = folder
        super.init(
            url: folder.url,
            credential: credential,
            allowUntrustedCertificate: allowUntrustedCertificate,
            timeout: timeout
        )
    }

    override func makeURLRequest() -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout.remainingTimeInterval
        )
        request.httpMethod = "PROPFIND"
        request.addValue("1", forHTTPHeaderField: "Depth")
        let body =
        """
        <?xml version="1.0"?>
        <d:propfind xmlns:d="DAV:">
          <d:prop>
            <d:resourcetype />
          </d:prop>
        </d:propfind>
        """
        request.httpBody = body.data(using: .utf8)
        request.attribution = .developer
        return request
    }

    override func finishWith(error: FileAccessError) {
        completionQueue.addOperation {
            self.completion(.failure(error))
        }
    }

    override func finishWith(success response: HTTPURLResponse, data: Data) {
        assert((200...299).contains(response.statusCode))

        do {
            let parser = PropFindResponseParser(baseURL: folder.root)
            let allItems = try parser.parse(data: data)
            let itemsToShow = allItems
                .dropFirst()
                .filter {
                    !$0.name.hasPrefix(".")
                }
            completionQueue.addOperation {
                self.completion(.success(itemsToShow))
            }
        } catch {
            let nsError = error as NSError
            Diag.error("Failed to parse server response [message: \(nsError.description)]")
            completionQueue.addOperation {
                self.completion(.failure(error))
            }
        }
    }
}

final internal class PropFindResponseParser {
    private let baseURL: URL
    private var items = [WebDAVItem]()
    private var davPrefix = "d:"

    typealias ResponseParserStream = XMLParserStream<PropFindParserContext>
    final class PropFindParserContext: XMLDocumentContext { }
    final class ResponseReaderContext: XMLReaderContext {
        var href: String?
        var isCollection = false
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func parse(data: Data) throws -> [WebDAVItem] {
        items.removeAll()

        let xmlReader = XMLDocumentReader(xmlData: data, documentContext: PropFindParserContext())
        xmlReader.pushReader(parseDocumentRoot, context: nil)
        try xmlReader.parse()
        return items
    }

    private func parseDocumentRoot(_ xml: ResponseParserStream) throws {
        let elementName = xml.name.lowercased()
        switch (elementName, xml.event) {
        case ("\(davPrefix)response", .start):
            try xml.pushReader(parseResponseElement, context: ResponseReaderContext())
        case ("\(davPrefix)multistatus", .end):
            xml.popReader()
        case (_, .start):
            guard elementName.hasSuffix("multistatus") else { break }
            if elementName == "multistatus" {
                davPrefix = ""
            } else if let davNamespace = elementName.split(separator: ":", maxSplits: 1).first {
                davPrefix = String(davNamespace) + ":"
            } else {
                Diag.warning("No custom DAV namespace found, assuming default")
            }
        default:
            break
        }
    }

    private func parseResponseElement(_ xml: ResponseParserStream) throws {
        let context = xml.readerContext as! ResponseReaderContext
        switch (xml.name.lowercased(), xml.event) {
        case ("\(davPrefix)response", .start):
            break
        case ("\(davPrefix)href", .end):
            context.href = xml.value
        case ("\(davPrefix)collection", .end):
            context.isCollection = true
        case ("\(davPrefix)response", .end):
            defer { xml.popReader() }
            guard let href = context.href else {
                Diag.error("Response element without href element, ignoring")
                return
            }
            guard let url = URL(string: href, relativeTo: baseURL)?.absoluteURL else {
                Diag.error("Failed to parse href as URL, ignoring")
                return
            }
            let item = WebDAVItem(
                name: url.lastPathComponent,
                isFolder: context.isCollection,
                root: baseURL,
                url: url
            )
            items.append(item)
        default:
            break
        }
    }
}
