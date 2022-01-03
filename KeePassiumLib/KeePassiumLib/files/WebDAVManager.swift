//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class WebDAVManager: NSObject {
    public static let shared = WebDAVManager()
    
    private var webdavRequests = [Int: WebDAVRequest]()
    
    private lazy var urlSession: URLSession = {
        var config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.multipathServiceType = .none
        config.waitsForConnectivity = false
        return URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: WebDAVManager.backgroundQueue
        )
    }()
    
    private static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.WebDAVManager"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    
    override private init() {
        super.init()
    }
    
    public func getFileInfo(
        url: URL,
        credential: NetworkCredential,
        timeout: TimeInterval,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<FileInfo, FileAccessError>) -> Void
    ) {
        let webdavRequest = WebDAVInfoRequest(
            url: url,
            credential: credential.toURLCredential(),
            allowUntrustedCertificate: credential.allowUntrustedCertificate,
            timeout: timeout,
            completionQueue: completionQueue ?? .main,
            completion: completion
        )
        
        objc_sync_enter(self)
        let dataTask = urlSession.dataTask(with: webdavRequest.makeURLRequest())
        webdavRequests[dataTask.taskIdentifier] = webdavRequest
        objc_sync_exit(self)

        dataTask.resume()
    }
    
    public func downloadFile(
        url: URL,
        credential: NetworkCredential,
        timeout: TimeInterval,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<ByteArray, FileAccessError>) -> Void
    ) {
        let downloadRequest = WebDAVDownloadRequest(
            url: url,
            credential: credential.toURLCredential(),
            allowUntrustedCertificate: credential.allowUntrustedCertificate,
            timeout: timeout,
            completionQueue: completionQueue ?? .main,
            completion: completion
        )
        
        objc_sync_enter(self)
        let downloadTask = urlSession.dataTask(with: downloadRequest.makeURLRequest())
        webdavRequests[downloadTask.taskIdentifier] = downloadRequest
        objc_sync_exit(self)

        downloadTask.resume()
    }
    
    public func uploadFile(
        data: ByteArray,
        url: URL,
        credential: NetworkCredential,
        timeout: TimeInterval,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<Void, FileAccessError>) -> Void
    ) {
        let uploadRequest = WebDAVUploadRequest(
            url: url,
            credential: credential.toURLCredential(),
            allowUntrustedCertificate: credential.allowUntrustedCertificate,
            data: data,
            timeout: timeout,
            completionQueue: completionQueue ?? .main,
            completion: completion
        )
        
        objc_sync_enter(self)
        let uploadTask = urlSession.dataTask(with: uploadRequest.makeURLRequest())
        webdavRequests[uploadTask.taskIdentifier] = uploadRequest
        objc_sync_exit(self)

        uploadTask.resume()
    }
}


extension WebDAVManager: URLSessionDataDelegate, URLSessionTaskDelegate {
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        guard var webdavRequest = webdavRequests[task.taskIdentifier] else {
            Diag.warning("Invalid task identifier")
            assertionFailure()
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        if challenge.previousFailureCount > 0 {
            let message = task.error?.localizedDescription ?? LString.errorAuthenticationFailed
            Diag.error("Authentication failed, aborting [message: \(message)]")
            webdavRequest.cancelReason = .authFailed(message: message)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let authMethod = challenge.protectionSpace.authenticationMethod
        Diag.debug("Authenticating on WebDAV server [method: \(authMethod)]")
        switch authMethod {
        case NSURLAuthenticationMethodDefault,
             NSURLAuthenticationMethodHTTPBasic:
            completionHandler(.useCredential, webdavRequest.credential)
        case NSURLAuthenticationMethodServerTrust:
            guard let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            do {
                try validateServer(
                    serverTrust,
                    allowUntrusted: webdavRequest.allowUntrustedCertificate)
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } catch {
                Diag.warning("Server is untrusted, cancelling [message: \(error.localizedDescription)]")
                webdavRequest.cancelReason = .untrustedServerCertificate(message: error.localizedDescription)
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
    
    
    private func validateServer(_ serverTrust: SecTrust, allowUntrusted: Bool) throws {
        assert(!Thread.isMainThread, "Must run in background")
        if allowUntrusted {
            return
        }
        var cfError: CFError?
        let _ = SecTrustEvaluateWithError(serverTrust, &cfError) 
        if let err = cfError as Error? {
            let nsError = err as NSError
            Diag.warning("Server certificate is not valid [details: \(nsError.description)]")
            throw err
        }
    }
    
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive data: Data
    ) {
        guard let webdavRequest = webdavRequests[dataTask.taskIdentifier] else {
            Diag.warning("Invalid task identifier")
            preconditionFailure()
        }
        webdavRequest.appendReceivedData(data)
    }
    
    public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        
        guard let webdavRequest = webdavRequests.removeValue(forKey: task.taskIdentifier) else {
            Diag.error("Invalid task identifier")
            preconditionFailure()
        }
        
        if let error = error {
            webdavRequest.handleClientError(error)
            return
        }
        guard let response = task.response,
              let httpResponse = response as? HTTPURLResponse
        else {
            Diag.error("Unexpected response type")
            preconditionFailure()
        }
        webdavRequest.handleResponse(httpResponse)
    }
}
