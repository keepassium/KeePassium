//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class WebDAVManager: NSObject {
    public static let shared = WebDAVManager()

    private struct RequestIdentifier: Hashable {
        let taskID: Int
        let sessionID: String

        init(for task: URLSessionTask, in session: URLSession) {
            guard let sessionID = session.sessionDescription else {
                fatalError("URL session does not refer to its URL, something is very wrong")
            }
            self.taskID = task.taskIdentifier
            self.sessionID = sessionID
        }
    }

    private var webdavRequests = [RequestIdentifier: WebDAVRequest]()

    private let urlSessionConfiguration: URLSessionConfiguration = {
        var config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCredentialStorage = nil
        config.allowsCellularAccess = true
        config.multipathServiceType = .none
        config.waitsForConnectivity = false
        return config
    }()
    private var urlSessionPool = [URL: URLSession]()

    override private init() {
        super.init()
    }

    public func getFileInfo(
        url: URL,
        credential: NetworkCredential,
        timeout: Timeout,
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
        let urlSession = getURLSession(for: url)
        let dataTask = urlSession.dataTask(with: webdavRequest.makeURLRequest())

        let requestID = RequestIdentifier(for: dataTask, in: urlSession)
        webdavRequests[requestID] = webdavRequest
        objc_sync_exit(self)

        dataTask.resume()
    }

    public func downloadFile(
        url: URL,
        credential: NetworkCredential,
        timeout: Timeout,
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
        let urlSession = getURLSession(for: url)
        let downloadTask = urlSession.dataTask(with: downloadRequest.makeURLRequest())

        let requestID = RequestIdentifier(for: downloadTask, in: urlSession)
        webdavRequests[requestID] = downloadRequest
        objc_sync_exit(self)

        downloadTask.resume()
    }

    public func uploadFile(
        data: ByteArray,
        url: URL,
        credential: NetworkCredential,
        timeout: Timeout,
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
        let urlSession = getURLSession(for: url)
        let uploadTask = urlSession.dataTask(with: uploadRequest.makeURLRequest())

        let requestID = RequestIdentifier(for: uploadTask, in: urlSession)
        webdavRequests[requestID] = uploadRequest
        objc_sync_exit(self)

        uploadTask.resume()
    }

    public func getItems(
        in folder: WebDAVItem,
        credential: NetworkCredential,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[WebDAVItem], Error>) -> Void
    ) {
        let listRequest = WebDAVListRequest(
            credential: credential.toURLCredential(),
            allowUntrustedCertificate: credential.allowUntrustedCertificate,
            folder: folder,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )

        objc_sync_enter(self)
        let urlSession = getURLSession(for: folder.root)
        let listTask = urlSession.dataTask(with: listRequest.makeURLRequest())

        let requestID = RequestIdentifier(for: listTask, in: urlSession)
        webdavRequests[requestID] = listRequest
        objc_sync_exit(self)

        listTask.resume()
    }

    public func checkIsFolder(
        url: URL,
        credential: NetworkCredential,
        timeout: Timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<Bool, FileAccessError>) -> Void
    ) {
        let folderCheckRequest = WebDAVFolderCheckRequest(
            url: url,
            credential: credential.toURLCredential(),
            allowUntrustedCertificate: credential.allowUntrustedCertificate,
            timeout: timeout,
            completionQueue: completionQueue ?? .main,
            completion: completion
        )

        objc_sync_enter(self)
        let urlSession = getURLSession(for: url)
        let checkTask = urlSession.dataTask(with: folderCheckRequest.makeURLRequest())

        let requestID = RequestIdentifier(for: checkTask, in: urlSession)
        webdavRequests[requestID] = folderCheckRequest
        objc_sync_exit(self)

        checkTask.resume()
    }
}

extension WebDAVManager {

    private func getURLSession(for url: URL) -> URLSession {
        if let existingSession = urlSessionPool[url] {
            return existingSession
        }
        let newSession = URLSession(
            configuration: urlSessionConfiguration,
            delegate: self,
            delegateQueue: nil
        )
        newSession.sessionDescription = url.absoluteString
        urlSessionPool[url] = newSession
        return newSession
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

        let requestID = RequestIdentifier(for: task, in: session)
        guard var webdavRequest = webdavRequests[requestID] else {
            Diag.warning("Invalid request identifier")
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
        if Diag.isDeepDebugMode() {
            let details = [
                "method: \(authMethod)",
                "url: \(session.sessionDescription ?? "")",
                "user: \(webdavRequest.credential.user ?? "")",
            ]
            Diag.debug("Authenticating on WebDAV server [\(details.joined(separator: ", "))]")
        } else {
            Diag.debug("Authenticating on WebDAV server [method: \(authMethod)]")
        }
        switch authMethod {
        case NSURLAuthenticationMethodDefault,
             NSURLAuthenticationMethodHTTPBasic:
            completionHandler(.useCredential, webdavRequest.credential)
        case NSURLAuthenticationMethodHTTPDigest:
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
        _ = SecTrustEvaluateWithError(serverTrust, &cfError) 
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
        objc_sync_enter(self)
        defer {
            objc_sync_exit(self)
        }
        let requestID = RequestIdentifier(for: dataTask, in: session)
        guard let webdavRequest = webdavRequests[requestID] else {
            Diag.warning("Invalid request identifier")
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

        let requestID = RequestIdentifier(for: task, in: session)
        guard let webdavRequest = webdavRequests.removeValue(forKey: requestID) else {
            Diag.error("Invalid request identifier")
            preconditionFailure()
        }

        if let error {
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
