//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

final class WebDAVFolderCheckRequest: WebDAVRequestBase {
    typealias Completion = (Result<RemoteItemKind, FileAccessError>) -> Void

    let completionQueue: OperationQueue
    let completion: Completion

    init(
        url: URL,
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping Completion
    ) {
        self.completionQueue = completionQueue
        self.completion = completion
        super.init(
            url: url,
            credential: credential,
            allowUntrustedCertificate: allowUntrustedCertificate,
            timeout: timeout
        )
    }

    override func makeURLRequest() -> URLRequest {
        var request = URLRequest(
            url: url,
            cachePolicy: .forMetaInfo,
            timeout: timeout
        )
        request.httpMethod = "PROPFIND"
        request.addValue("0", forHTTPHeaderField: "Depth")
        let body =
        """
        <?xml version="1.0"?>
        <d:propfind xmlns:d="DAV:">
            <d:prop>
                <d:resourcetype />
                <d:getcontenttype />
                <d:getcontentlength />
            </d:prop>
        </d:propfind>
        """
        request.httpBody = body.data(using: .utf8)
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
            let parser = FolderCheckResponseParser(baseURL: url)
            let itemKind = try parser.parse(data: data)
            completionQueue.addOperation {
                self.completion(.success(itemKind))
            }
        } catch {
            let nsError = error as NSError
            Diag.error("Failed to parse server response [message: \(nsError.description)]")
            completionQueue.addOperation { [self] in
                let fileAccessError = FileAccessError.make(
                    from: error,
                    fileName: url.lastPathComponent,
                    fileProvider: .keepassiumWebDAV)
                self.completion(.failure(fileAccessError))
            }
        }
    }

    override func handleResponse(_ httpResponse: HTTPURLResponse) {
        let statusCode = httpResponse.statusCode
        if (200...299).contains(statusCode) {
            finishWith(success: httpResponse, data: receivedData)
            return
        }

        if statusCode == 405 || statusCode == 404 {
            completionQueue.addOperation {
                self.completion(.success(.file))
            }
            return
        }

        super.handleResponse(httpResponse)
    }
}

private final class FolderCheckResponseParser {
    private let baseURL: URL
    private var davPrefix = "d:"

    typealias ResponseParserStream = XMLParserStream<PropFindParserContext>
    final class PropFindParserContext: XMLDocumentContext { }
    final class ResponseReaderContext: XMLReaderContext {
        var isCollection = false
        var contentType: String?
        var contentLength: Int64?
    }

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    func parse(data: Data) throws -> RemoteItemKind {
        let context = ResponseReaderContext()
        let xmlReader = XMLDocumentReader(xmlData: data, documentContext: PropFindParserContext())
        xmlReader.pushReader(parseDocumentRoot, context: context)
        try xmlReader.parse()
        if looksLikeFolder(context) {
            return .folder
        } else {
            return .file
        }
    }

    private func looksLikeFolder(_ context: ResponseReaderContext) -> Bool {
        if context.isCollection {
            return true
        }

        if let contentType = context.contentType {
            if contentType.contains("directory") || contentType.contains("folder") {
                return true
            }
        }

        if context.contentLength == 0 && context.contentType == nil {
            return true
        }

        return false
    }

    private func parseDocumentRoot(_ xml: ResponseParserStream) throws {
        let elementName = xml.name.lowercased()
        switch (elementName, xml.event) {
        case ("\(davPrefix)response", .start):
            try xml.pushReader(parseResponseElement, context: xml.readerContext)
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
        case ("\(davPrefix)collection", .end):
            context.isCollection = true
        case ("\(davPrefix)getcontenttype", .end):
            context.contentType = xml.value
        case ("\(davPrefix)getcontentlength", .end):
            if let value = xml.value {
                context.contentLength = Int64(value)
            }
        case ("\(davPrefix)response", .end):
            xml.popReader()
        default:
            break
        }
    }
}
