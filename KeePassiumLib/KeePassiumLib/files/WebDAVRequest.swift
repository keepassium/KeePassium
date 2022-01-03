//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

internal enum WebDAVCancelReason {
    case authFailed(message: String)
    case untrustedServerCertificate(message: String)
}

internal protocol WebDAVRequest {
    var url: URL { get }
    var credential: URLCredential { get }
    var allowUntrustedCertificate: Bool { get }
    var timeout: TimeInterval { get }
    var cancelReason: WebDAVCancelReason? { get set }
    
    func makeURLRequest() -> URLRequest
    func appendReceivedData(_ chunk: Data)
    
    func handleClientError(_ error: Error)
    func handleResponse(_ httpResponse: HTTPURLResponse)
}

internal class WebDAVRequestBase: WebDAVRequest {
    let url: URL
    let credential: URLCredential
    let allowUntrustedCertificate: Bool
    let timeout: TimeInterval
    var cancelReason: WebDAVCancelReason?
    private(set) var receivedData: Data
    
    init(
        url: URL,
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        timeout: TimeInterval
    ) {
        self.url = url
        self.credential = credential
        self.allowUntrustedCertificate = allowUntrustedCertificate
        self.timeout = timeout
        receivedData = Data()
    }
    
    func makeURLRequest() -> URLRequest {
        fatalError("Pure abstract method")
    }
    
    func appendReceivedData(_ chunk: Data) {
        receivedData.append(chunk)
    }
    
    func handleClientError(_ error: Error) {
        Diag.error("WebDAV client error [message: \(error.localizedDescription)]")
        guard let urlError = error as? URLError else {
            finishWith(error: .systemError(error))
            return
        }
        
        switch urlError.errorCode {
        case NSURLErrorCancelled:
            switch cancelReason {
            case .authFailed(let message):
                finishWith(error: .serverSideError(message: message))
            case .untrustedServerCertificate(let message):
                finishWith(error: .networkError(message: message))
            case .none:
                finishWith(error: .noInfoAvailable)
            }
        case NSURLErrorTimedOut:
            finishWith(error: .timeout(fileProvider: .keepassiumWebDAV))
        default:
            finishWith(error: .systemError(urlError))
        }
    }

    private func handleServerError(httpResponse: HTTPURLResponse, data: Data) {
        let codeDescription = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        let statusMessage = "\(httpResponse.statusCode): \(codeDescription)"
        Diag.error("WebDAV server error: \(statusMessage)")
        if let httpBody = String(data: data, encoding: .utf8) {
            Diag.error("WebDAV error response: \(httpBody.prefix(500))")
        }
        finishWith(error: .serverSideError(message: statusMessage))
    }
    
    func handleResponse(_ httpResponse: HTTPURLResponse) {
        if (200...299).contains(httpResponse.statusCode) {
            finishWith(success: httpResponse, data: receivedData)
        } else {
            handleServerError(httpResponse: httpResponse, data: receivedData)
        }
    }
    
    func finishWith(error: FileAccessError) {
        preconditionFailure("Pure virtual method")
    }
    func finishWith(success response: HTTPURLResponse, data: Data) {
        preconditionFailure("Pure virtual method")
    }
}

final class WebDAVInfoRequest: WebDAVRequestBase {
    typealias Completion = (Result<FileInfo, FileAccessError>) -> Void
    
    let completionQueue: OperationQueue
    let completion: Completion
    
    init(
        url: URL,
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        timeout: TimeInterval,
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
            timeoutInterval: timeout
        )
        request.httpMethod = "HEAD"
        if #available(iOS 15, *) {
            request.attribution = .developer
        }
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
        let contentLength = Int.init(contentLengthString) ?? -1
        let lastModifiedDate = Date.parse(httpHeaderValue: lastModifiedString)

        let fileInfo = FileInfo(
            fileName: url.lastPathComponent,
            fileSize: Int64(contentLength),
            creationDate: nil,
            modificationDate: lastModifiedDate,
            isExcludedFromBackup: nil,
            isInTrash: false
        )
        completionQueue.addOperation {
            self.completion(.success(fileInfo))
        }
    }
}

final class WebDAVDownloadRequest: WebDAVRequestBase {
    typealias Completion = (Result<ByteArray, FileAccessError>) -> Void
    
    let completionQueue: OperationQueue
    let completion: Completion
    
    init(
        url: URL,
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        timeout: TimeInterval,
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
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        if #available(iOS 15, *) {
            request.attribution = .developer
        }
        return request
    }
    
    override func finishWith(error: FileAccessError) {
        completionQueue.addOperation {
            self.completion(.failure(error))
        }
    }
    
    override func finishWith(success response: HTTPURLResponse, data: Data) {
        assert((200...299).contains(response.statusCode))

        let fileData = ByteArray(data: data)
        completionQueue.addOperation {
            self.completion(.success(fileData))
        }
    }
}

final class WebDAVUploadRequest: WebDAVRequestBase {
    typealias Completion = (Result<Void, FileAccessError>) -> Void
    
    let completionQueue: OperationQueue
    let completion: Completion
    let dataToUpload: ByteArray
    
    init(
        url: URL,
        credential: URLCredential,
        allowUntrustedCertificate: Bool,
        data: ByteArray,
        timeout: TimeInterval,
        completionQueue: OperationQueue,
        completion: @escaping Completion
    ) {
        self.completionQueue = completionQueue
        self.completion = completion
        self.dataToUpload = data
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
            timeoutInterval: timeout
        )
        request.httpMethod = "PUT"
        request.httpBody = dataToUpload.asData
        if #available(iOS 15, *) {
            request.attribution = .developer
        }
        return request
    }
    
    override func finishWith(error: FileAccessError) {
        completionQueue.addOperation {
            self.completion(.failure(error))
        }
    }
    
    override func finishWith(success response: HTTPURLResponse, data: Data) {
        assert((200...299).contains(response.statusCode))
        completionQueue.addOperation {
            self.completion(.success)
        }
    }
}
