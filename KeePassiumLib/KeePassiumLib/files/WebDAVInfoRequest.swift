//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

final class WebDAVInfoRequest: WebDAVRequestBase {
    typealias Completion = (Result<FileInfo, FileAccessError>) -> Void

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
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: timeout.remainingTimeInterval
        )
        request.httpMethod = "HEAD"
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

        let contentLengthString = response.value(forHTTPHeaderField: "content-length")
        let lastModifiedString = response.value(forHTTPHeaderField: "last-modified")
        Diag.debug("""
  content-length: \(contentLengthString ?? "nil")
  last-modified: \(lastModifiedString ?? "nil")
""")
        let contentLength = Int(contentLengthString) ?? -1
        let lastModifiedDate = Date.parse(httpHeaderValue: lastModifiedString)
        let eTag = response.value(forHTTPHeaderField: "Etag")

        let fileInfo = FileInfo(
            fileName: url.lastPathComponent,
            fileSize: Int64(contentLength),
            creationDate: nil,
            modificationDate: lastModifiedDate,
            attributes: [:],
            isInTrash: false,
            hash: eTag
        )
        completionQueue.addOperation {
            self.completion(.success(fileInfo))
        }
    }
}
