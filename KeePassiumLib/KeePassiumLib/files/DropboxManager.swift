//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices
import CryptoKit
import Foundation

final public class DropboxManager: NSObject {
    public typealias TokenUpdateCallback = (OAuthToken) -> Void

    public struct UploadResponse {
        var name: String
        var file: DropboxItem
    }

    private enum TokenOperation: CustomStringConvertible {
        case authorization(code: String, codeVerifier: String)
        case refresh(token: OAuthToken)
        var description: String {
            switch self {
            case .authorization:
                return "tokenAuth"
            case .refresh:
                return "tokenRefresh"
            }
        }
    }

    public static let shared = DropboxManager()

    private var presentationAnchors = [ObjectIdentifier: Weak<ASPresentationAnchor>]()
    private let urlSession: URLSession

    private static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.DropboxManager"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()

    private override init() {
        urlSession = {
            let config = URLSessionConfiguration.ephemeral
            config.allowsCellularAccess = true
            config.multipathServiceType = .none
            config.waitsForConnectivity = false
            return URLSession(
                configuration: config,
                delegate: nil,
                delegateQueue: DropboxManager.backgroundQueue
            )
        }()
        super.init()
    }

    public func authenticate(
        presenter: UIViewController,
        timeout: Timeout,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        Diag.info("Authenticating with Dropbox")
        let codeVerifier = "\(UUID().uuidString)-\(UUID().uuidString)"
        let webAuthSession = ASWebAuthenticationSession(
            url: getAuthURL(codeVerifier: codeVerifier),
            callbackURLScheme: DropboxAPI.callbackURLScheme,
            completionHandler: { [self] (callbackURL: URL?, error: Error?) in
                handleAuthResponse(
                    codeVerifier: codeVerifier,
                    callbackURL: callbackURL,
                    error: error,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            }
        )
        presentationAnchors[ObjectIdentifier(webAuthSession)] = Weak(presenter.view.window!)
        webAuthSession.presentationContextProvider = self
        webAuthSession.prefersEphemeralWebBrowserSession = false

        webAuthSession.start()
    }

    private func parseFileListResponse(
        _ json: [String: Any],
        folder: DropboxItem
    ) -> [DropboxItem]? {
        guard let items = json[DropboxAPI.Keys.entries] as? [[String: Any]] else {
            Diag.error("Failed to parse file list response: value field missing")
            return nil
        }

        let result = items.compactMap { infoDict -> DropboxItem? in
            return parseItem(infoDict, info: folder.info)
        }
        return result
    }

    private func parseItem(_ infoDict: [String: Any], info: DropboxAccountInfo) -> DropboxItem? {
        guard let name = infoDict[DropboxAPI.Keys.name] as? String,
              let pathDisplay = infoDict[DropboxAPI.Keys.pathDisplay] as? String
        else {
            Diag.debug("Failed to parse file item: id or name or path field missing; skipping the file")
            return nil
        }

        let tag = infoDict[DropboxAPI.Keys.tag] as? String

        return DropboxItem(
            name: name,
            isFolder: tag == "folder",
            fileInfo: tag == "folder" ? nil : FileInfo(
                fileName: name,
                fileSize: infoDict[DropboxAPI.Keys.size] as? Int64,
                creationDate: Date(
                    iso8601string: infoDict[DropboxAPI.Keys.clientModified] as? String),
                modificationDate: Date(
                    iso8601string: infoDict[DropboxAPI.Keys.clientModified] as? String),
                isInTrash: false,
                hash: infoDict[DropboxAPI.Keys.contentHash] as? String
            ),
            pathDisplay: pathDisplay,
            info: info
        )
    }

    private func createCodeChallenge(codeVerifier: String) -> String {
        let ascii = codeVerifier.compactMap({ $0.asciiValue })
        let data = Data(ascii)
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        let base64 = Data(hash).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
            .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        return base64 ?? ""
    }

    private func getAuthURL(codeVerifier: String) -> URL {
       let codeChallenge = createCodeChallenge(codeVerifier: codeVerifier)

        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "www.dropbox.com"
        urlComponents.path = "/oauth2/authorize"
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: DropboxAPI.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: DropboxAPI.authRedirectURI),
            URLQueryItem(name: "disable_signup", value: "true"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "token_access_type", value: "offline")
        ]
        return urlComponents.url!
    }

    private func handleAuthResponse(
        codeVerifier: String,
        callbackURL: URL?,
        error: Error?,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        if let error = error as NSError? {
            let isCancelled =
            (error.domain == ASWebAuthenticationSessionErrorDomain) &&
            (error.code == ASWebAuthenticationSessionError.canceledLogin.rawValue)
            if isCancelled {
                completionQueue.addOperation {
                    Diag.info("Authentication cancelled by user")
                    completion(.failure(.cancelledByUser))
                }
            } else {
                completionQueue.addOperation {
                    Diag.error("Authentication failed [message: \(error.localizedDescription)]")
                    completion(.failure(.general(error: error)))
                }
            }
            return
        }

        guard let callbackURL = callbackURL,
              let urlComponents = URLComponents(url: callbackURL, resolvingAgainstBaseURL: true),
              let queryItems = urlComponents.queryItems
        else {
            completionQueue.addOperation {
                Diag.error("Authentication failed: empty or misformatted callback URL")
                completion(.failure(.emptyResponse))
            }
            return
        }

        let error = queryItems.getValue(name: DropboxAPI.Keys.error)
        switch error {
        case "access_denied":
            completionQueue.addOperation {
                Diag.error("Access denied, authentication cancelled")
                completion(.failure(.cancelledByUser))
            }
            return
        default:
            break
        }

        guard let codeItem = queryItems[DropboxAPI.Keys.code],
              let authCodeString = codeItem.value
        else {
            completionQueue.addOperation {
                Diag.error("Authentication failed: OAuth token not found in response")
                completion(.failure(.misformattedResponse))
            }
            return
        }
        getToken(
            operation: .authorization(code: authCodeString, codeVerifier: codeVerifier), timeout: timeout,
            completionQueue: completionQueue,
            completion: completion)
    }

    private func getToken(
        operation: TokenOperation,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        Diag.debug("Acquiring OAuth token [operation: \(operation)]")
        var urlRequest = URLRequest(url: DropboxAPI.tokenRequestURL)
        urlRequest.timeoutInterval = timeout.duration
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=UTF-8",
            forHTTPHeaderField: DropboxAPI.Keys.contentType)

        var postParams = [
            "client_id=\(DropboxAPI.clientID)"
        ]

        let refreshToken: String?
        let accountId: String?
        switch operation {
        case let .authorization(authCode, codeVerifier):
            refreshToken = nil
            accountId = nil
            postParams.append(
                "redirect_uri=" +
                DropboxAPI.authRedirectURI.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
            postParams.append(
                "code=" +
                authCode.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
            postParams.append(
                "code_verifier=" +
                codeVerifier.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
            postParams.append("grant_type=authorization_code")
        case .refresh(let token):
            refreshToken = token.refreshToken
            accountId = token.accountIdentifier
            postParams.append(
                "refresh_token=" +
                token.refreshToken.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
            postParams.append("grant_type=refresh_token")
        }

        let postData = postParams
            .joined(separator: "&")
            .data(using: .utf8, allowLossyConversion: false)!
        urlRequest.setValue(String(postData.count), forHTTPHeaderField: DropboxAPI.Keys.contentLength)
        urlRequest.httpBody = postData

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = DropboxAPI.ResponseParser
                    .parseJSONResponse(operation: operation.description, data: data, error: error)
            switch result {
            case .success(let json):
                if let token = self.parseTokenResponse(
                    json: json,
                    currentRefreshToken: refreshToken,
                    accountId: accountId
                ) {
                    Diag.debug("OAuth token acquired successfully [operation: \(operation)]")
                    completionQueue.addOperation {
                        completion(.success(token))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
            }
        }
        dataTask.resume()
    }

    private func parseTokenResponse(
        json: [String: Any],
        currentRefreshToken: String?,
        accountId: String?
    ) -> OAuthToken? {
        guard let accountId = (json[DropboxAPI.Keys.accountId] as? String) ?? accountId else {
            Diag.error("Failed to parse token response: account_id missing")
            return nil
        }
        guard let accessToken = json[DropboxAPI.Keys.accessToken] as? String else {
            Diag.error("Failed to parse token response: access_token missing")
            return nil
        }
        guard let expires_in = json[DropboxAPI.Keys.expiresIn] as? Int else {
            Diag.error("Failed to parse token response: expires_in missing")
            return nil
        }
        let newRefreshToken = json[DropboxAPI.Keys.refreshToken] as? String
        guard let refreshToken = (newRefreshToken ?? currentRefreshToken) else {
            Diag.error("Failed to parse token response: refresh_token missing")
            return nil
        }

        let token = OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            acquired: Date.now,
            lifespan: TimeInterval(expires_in),
            accountIdentifier: accountId
        )
        return token
    }
}

extension DropboxManager: RemoteDataSourceManager {
    public var maxUploadSize: Int {
        return DropboxAPI.maxUploadSize
    }

    public func getAccountInfo(
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<DropboxAccountInfo, RemoteError>) -> Void
    ) {
        var urlRequest = URLRequest(url: DropboxAPI.accountInfoURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: DropboxAPI.Keys.authorization)
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = DropboxAPI.ResponseParser
                .parseJSONResponse(operation: "accountInfo", data: data, error: error)
            switch result {
            case .success(let json):
                if let accountInfo = self.parseAccountInfoResponse(json) {
                    Diag.debug("Account info acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(accountInfo))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
            }
        }
        dataTask.resume()
    }

    private func parseAccountInfoResponse(_ json: [String: Any]) -> DropboxAccountInfo? {
        guard let accountId = json[DropboxAPI.Keys.accountId] as? String else {
            Diag.error("Failed to parse account info response: account_id missing")
            return nil
        }
        guard let email = json[DropboxAPI.Keys.email] as? String else {
            Diag.error("Failed to parse account info response: email missing")
            return nil
        }
        guard let accountTypeDict = (json[DropboxAPI.Keys.accountType] as? [String: Any]) else {
            Diag.error("Failed to parse account info response: account_type missing")
            return nil
        }
        let accountTypeTag = (accountTypeDict[DropboxAPI.Keys.tag] as? String)
        guard let accountType = DropboxAccountInfo.AccountType.from(accountTypeTag) else {
            Diag.error("Failed to parse account info response: unrecognized type [value: \(accountTypeTag ?? "nil")]")
            return nil
        }
        return DropboxAccountInfo(accountId: accountId, email: email, type: accountType)
    }

    public func getItems(
        in folder: DropboxItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[DropboxItem], RemoteError>) -> Void
    ) {
        getItems(
            in: folder,
            cursor: nil,
            itemsSoFar: [],
            freshToken: token,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }

    private func getItems(
        in folder: DropboxItem,
        cursor: String?,
        itemsSoFar: [DropboxItem],
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[DropboxItem], RemoteError>) -> Void
    ) {
        let url = cursor == nil ? DropboxAPI.folderListURL : DropboxAPI.folderListContinueURL
        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = timeout.duration
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: DropboxAPI.Keys.authorization)
        urlRequest.setValue("application/json", forHTTPHeaderField: DropboxAPI.Keys.contentType)

        let json: String
        if let cursor = cursor {
            json = """
            {
                "cursor": "\(cursor)"
            }
            """
        } else {
            json = """
            {
                "include_deleted": false,
                "include_has_explicit_shared_members": false,
                "include_media_info": false,
                "include_mounted_folders": true,
                "include_non_downloadable_files": false,
                "path": "\(folder.pathDisplay)",
                "recursive": false
            }
            """
        }
        urlRequest.httpBody = json.data(using: .utf8)

        let dataTask = urlSession.dataTask(with: urlRequest) {
            [self] data,
            response,
            error in
            let result = DropboxAPI.ResponseParser
                .parseJSONResponse(operation: "listFiles", data: data, error: error)
            switch result {
            case .success(let json):
                let cursor = json[DropboxAPI.Keys.cursor] as? String
                let hasMore = json[DropboxAPI.Keys.hasMore] as? Bool
                if let fileItems = parseFileListResponse(json, folder: folder) {
                    Diag.debug("File list acquired successfully")
                    if let hasMore = hasMore,
                       hasMore {
                        self.getItems(
                            in: folder,
                            cursor: cursor,
                            itemsSoFar: itemsSoFar + fileItems,
                            freshToken: token,
                            timeout: timeout,
                            completionQueue: completionQueue,
                            completion: completion
                        )
                    } else {
                        completionQueue.addOperation {
                            completion(.success(itemsSoFar + fileItems))
                        }
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
            }
        }
        dataTask.resume()
    }

    public func acquireTokenSilent(
        token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        if Date.now < (token.acquired + token.halflife) {
            completionQueue.addOperation {
                completion(.success(token))
            }
        } else if token.refreshToken.isEmpty {
            completionQueue.addOperation {
                Diag.error("OAuth token expired and there is no refresh token")
                completion(.failure(.cannotRefreshToken))
            }
        } else {
            getToken(
                operation: .refresh(token: token),
                timeout: timeout,
                completionQueue: completionQueue,
                completion: completion
            )
        }
    }

    public func getItemInfo(
        _ item: DropboxItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<DropboxItem, RemoteError>) -> Void
    ) {
        var urlRequest = URLRequest(url: DropboxAPI.itemMetadataURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: DropboxAPI.Keys.authorization)
        urlRequest.setValue("application/json", forHTTPHeaderField: DropboxAPI.Keys.contentType)
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.timeoutInterval = timeout.duration

        let json = """
        {
            "include_deleted": false,
            "include_has_explicit_shared_members": false,
            "include_media_info": false,
            "path": "\(item.pathDisplay)"
        }
        """
        urlRequest.httpBody = json.data(using: .utf8)

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = DropboxAPI.ResponseParser
                .parseJSONResponse(operation: "itemInfo", item: item, data: data, error: error)
            switch result {
            case .success(let json):
                if let fileItem = parseItem(json, info: item.info) {
                    Diag.debug("File info acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(fileItem))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
            }
        }
        dataTask.resume()
    }

    public func getFileContents(
        _ item: DropboxItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<Data, RemoteError>) -> Void
    ) {
        var urlRequest = URLRequest(url: DropboxAPI.fileDownloadURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: DropboxAPI.Keys.authorization)
        urlRequest.setValue("{\"path\": \"\(item.escapedPath)\"}", forHTTPHeaderField: DropboxAPI.Keys.apiArg)
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completionQueue.addOperation {
                    let nsError = error as NSError
                    Diag.error("Failed to download file [message: \(nsError.debugDescription)]")
                    completion(.failure(.general(error: error)))
                }
                return
            }

            guard let data = data else {
                completionQueue.addOperation {
                    Diag.error("Failed to download file: no data returned")
                    completion(.failure(.emptyResponse))
                }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode

            guard let statusCode, (200..<300).contains(statusCode) else {
                completionQueue.addOperation {
                    if let message = String(data: data, encoding: .utf8) {
                        Diag.error("Failed to download file, server returned error [message: \(message)]")
                        completion(.failure(.serverSideError(message: message)))
                    } else {
                        completion(.failure(.misformattedResponse))
                    }
                }
                return
            }

            completionQueue.addOperation {
                Diag.debug("File downloaded successfully [size: \(data.count)]")
                completion(.success(data))
            }
        }
        dataTask.resume()
    }

    public func updateFile(
        _ item: DropboxItem,
        contents: ByteArray,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {
        var urlRequest = URLRequest(url: DropboxAPI.fileUploadURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: DropboxAPI.Keys.authorization)
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: DropboxAPI.Keys.contentType)
        urlRequest.setValue(
            "{\"mode\":\"overwrite\",\"path\":\"\(item.escapedPath)\"}",
            forHTTPHeaderField: DropboxAPI.Keys.apiArg)
        urlRequest.timeoutInterval = timeout.duration

        urlRequest.httpBody = contents.asData

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = DropboxAPI.ResponseParser
                .parseJSONResponse(operation: "uploadSession", item: item, data: data, error: error)
            switch result {
            case .success(let json):
                if let name = json[DropboxAPI.Keys.name] as? String,
                   let file = self.parseItem(json, info: item.info) {
                    Diag.debug("Upload finished successfully")
                    completionQueue.addOperation {
                        completion(.success(UploadResponse(name: name, file: file)))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
            }
        }
        dataTask.resume()
    }

    public func createFile(
        in folder: DropboxItem,
        contents: ByteArray,
        fileName: String,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping CreateCompletionHandler<ItemType>
    ) {
        let item = DropboxItem(
            name: fileName,
            isFolder: false,
            pathDisplay: "\(folder.pathDisplay)/\(fileName)",
            info: folder.info
        )
        updateFile(
            item,
            contents: contents,
            freshToken: token,
            timeout: timeout,
            completionQueue: completionQueue
        ) { result in
            switch result {
            case let .success(data):
                completion(.success(data.file))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }
}

extension DropboxManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let sessionObjectID = ObjectIdentifier(session)
        return presentationAnchors[sessionObjectID]!.value!
    }
}
