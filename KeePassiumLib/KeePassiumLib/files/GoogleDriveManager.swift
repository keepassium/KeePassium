//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices
import Foundation

final public class GoogleDriveManager: NSObject, RemoteDataSourceManager {
    public typealias ItemType = GoogleDriveItem
    public typealias TokenUpdateCallback = (OAuthToken) -> Void

    public struct UploadResponse {
        var name: String
        var file: GoogleDriveItem
    }

    private enum TokenOperation: CustomStringConvertible {
        case authorization(code: String)
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

    public static let shared = GoogleDriveManager()
    public var maxUploadSize: Int {
        return GoogleDriveAPI.maxUploadSize
    }

    private var presentationAnchors = [ObjectIdentifier: Weak<ASPresentationAnchor>]()
    private let urlSession: URLSession

    private static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.GoogleDriveManager"
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
                delegateQueue: GoogleDriveManager.backgroundQueue
            )
        }()
        super.init()
    }
}

extension GoogleDriveManager {
    public func authenticate(
        presenter: UIViewController,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        Diag.info("Authenticating with Google Drive")
        let webAuthSession = ASWebAuthenticationSession(
            url: getAuthURL(),
            callbackURLScheme: GoogleDriveAPI.callbackURLScheme,
            completionHandler: { [self] (callbackURL: URL?, error: Error?) in
                handleAuthResponse(
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

    private func getAuthURL() -> URL {
        var urlComponents = URLComponents()
        urlComponents.scheme = "https"
        urlComponents.host = "accounts.google.com"
        urlComponents.path = "/o/oauth2/v2/auth"
        urlComponents.queryItems = [
            URLQueryItem(name: GoogleDriveAPI.Keys.clientID, value: GoogleDriveAPI.clientID),
            URLQueryItem(name: GoogleDriveAPI.Keys.responseType, value: "code"),
            URLQueryItem(name: GoogleDriveAPI.Keys.scope, value: GoogleDriveAPI.authScope.joined(separator: " ")),
            URLQueryItem(name: GoogleDriveAPI.Keys.redirectURI, value: GoogleDriveAPI.authRedirectURI),
        ]
        return urlComponents.url!
    }

    private func handleAuthResponse(
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

        let error = queryItems.getValue(name: GoogleDriveAPI.Keys.error)
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

        guard let codeItem = queryItems[GoogleDriveAPI.Keys.code],
              let authCodeString = codeItem.value
        else {
            completionQueue.addOperation {
                Diag.error("Authentication failed: OAuth token not found in response")
                completion(.failure(.misformattedResponse))
            }
            return
        }
        getToken(
            operation: .authorization(code: authCodeString),
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion)
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

    private func getToken(
        operation: TokenOperation,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        Diag.debug("Acquiring OAuth token [operation: \(operation)]")
        var urlRequest: URLRequest
        switch operation {
        case .authorization:
            urlRequest = URLRequest(url: GoogleDriveAPI.tokenRequestURL)
        case .refresh:
            urlRequest = URLRequest(url: GoogleDriveAPI.tokenRefreshURL)
        }
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=UTF-8",
            forHTTPHeaderField: GoogleDriveAPI.Keys.contentType)
        urlRequest.timeoutInterval = timeout.duration

        var postParams = [
            "client_id=\(GoogleDriveAPI.clientID.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"
        ]

        let refreshToken: String?
        let accountId: String?
        switch operation {
        case let .authorization(authCode):
            refreshToken = nil
            accountId = nil
            postParams.append(
                "redirect_uri=" +
                GoogleDriveAPI.authRedirectURI.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
            postParams.append(
                "code=" +
                authCode.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
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
        urlRequest.setValue(String(postData.count), forHTTPHeaderField: GoogleDriveAPI.Keys.contentLength)
        urlRequest.httpBody = postData

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = GoogleDriveAPI.ResponseParser
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
        guard let accessToken = json[GoogleDriveAPI.Keys.accessToken] as? String else {
            Diag.error("Failed to parse token response: access_token missing")
            return nil
        }
        guard let expires_in = json[GoogleDriveAPI.Keys.expiresIn] as? Int else {
            Diag.error("Failed to parse token response: expires_in missing")
            return nil
        }
        let newRefreshToken = json[GoogleDriveAPI.Keys.refreshToken] as? String
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

extension GoogleDriveManager {
    public func getAccountInfo(
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<GoogleDriveAccountInfo, RemoteError>) -> Void
    ) {
        var urlRequest = URLRequest(url: GoogleDriveAPI.accountInfoURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: GoogleDriveAPI.Keys.authorization)

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = GoogleDriveAPI.ResponseParser
                .parseJSONResponse(operation: "accountInfo", data: data, error: error)
            switch result {
            case .success(let json):
                if let info = parseAccountInfo(json) {
                    Diag.debug("Account info acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(info))
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

    private func parseAccountInfo(_ infoDict: [String: Any]) -> GoogleDriveAccountInfo? {
        let canCreateDrives = infoDict[GoogleDriveAPI.Keys.canCreateDrives] as? Bool ?? false
        guard let userDict = infoDict[GoogleDriveAPI.Keys.user] as? [String: Any] else {
            Diag.debug("Failed to parse account info, user field missing")
            return nil
        }
        guard let email = userDict[GoogleDriveAPI.Keys.emailAddress] as? String else {
            Diag.debug("Failed to parse user info, email field missing")
            return nil
        }
        return GoogleDriveAccountInfo(email: email, canCreateDrives: canCreateDrives)
    }
}

extension GoogleDriveManager {
    public func getItems(
        in folder: GoogleDriveItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[GoogleDriveItem], RemoteError>) -> Void
    ) {
        getItems(
            in: folder,
            nextPageToken: nil,
            itemsSoFar: [],
            freshToken: token,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }

    private func getItems(
        in folder: GoogleDriveItem,
        nextPageToken: String?,
        itemsSoFar: [GoogleDriveItem],
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[GoogleDriveItem], RemoteError>) -> Void
    ) {
        let url = folder.getRequestURL(.children(nextPageToken: nextPageToken))
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: GoogleDriveAPI.Keys.authorization)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) {
            [self] data,
            response,
            error in
            let result = GoogleDriveAPI.ResponseParser
                .parseJSONResponse(operation: "listFiles", data: data, error: error)
            switch result {
            case .success(let json):
                if let fileItems = parseFileListResponse(json, folder: folder) {
                    Diag.debug("File list acquired successfully")
                    if let nextPageToken = json[GoogleDriveAPI.Keys.nextPageToken] as? String {
                        self.getItems(
                            in: folder,
                            nextPageToken: nextPageToken,
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

    private func parseFileListResponse(
        _ json: [String: Any],
        folder: GoogleDriveItem
    ) -> [GoogleDriveItem]? {
        guard let items = json[GoogleDriveAPI.Keys.files] as? [[String: Any]] else {
            Diag.error("Failed to parse file list response: value field missing")
            return nil
        }

        let result = items.compactMap { infoDict -> GoogleDriveItem? in
            return parseItem(infoDict, accountInfo: folder.accountInfo)
        }
        return result
    }
}

extension GoogleDriveManager {
    public func getFileContents(
        _ item: GoogleDriveItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<Data, RemoteError>) -> Void
    ) {
        var urlRequest = URLRequest(url: item.getRequestURL(.content))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: GoogleDriveAPI.Keys.authorization)

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completionQueue.addOperation {
                    Diag.error("Failed to download file [message: \(error.localizedDescription)]")
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
}

extension GoogleDriveManager {
    public func getItemInfo(
        _ item: GoogleDriveItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<GoogleDriveItem, RemoteError>) -> Void
    ) {
        var urlRequest = URLRequest(url: item.getRequestURL(.itemInfo))
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: GoogleDriveAPI.Keys.authorization)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = GoogleDriveAPI.ResponseParser
                .parseJSONResponse(operation: "itemInfo", data: data, error: error)
            switch result {
            case .success(let json):
                if let file = parseItem(json, accountInfo: item.accountInfo) {
                    Diag.debug("File metadata acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(file))
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

    private func parseItem(_ infoDict: [String: Any], accountInfo: GoogleDriveAccountInfo) -> GoogleDriveItem? {
        guard let name = infoDict[GoogleDriveAPI.Keys.name] as? String,
              var itemID = infoDict[GoogleDriveAPI.Keys.id] as? String,
              var itemMimeType = infoDict[GoogleDriveAPI.Keys.mimeType] as? String
        else {
            Diag.debug("Failed to parse file item: id, name or mimeType field missing; skipping the file")
            return nil
        }

        var isShortcut = false
        if let shortcutInfo = infoDict[GoogleDriveAPI.Keys.shortcutDetails] as? [String: Any] {
            guard let targetID = shortcutInfo[GoogleDriveAPI.Keys.targetID] as? String else {
                Diag.error("Failed to resolve shortcut: target ID missing")
                return nil
            }
            guard let targetMimeType = shortcutInfo[GoogleDriveAPI.Keys.targetMimeType] as? String else {
                Diag.error("Failed to resolve shortcut: target MIME type missing")
                return nil
            }
            isShortcut = true
            itemID = targetID
            itemMimeType = targetMimeType
        }

        let isFolder = itemMimeType == GoogleDriveAPI.Keys.folderMimeType
        let fileInfo = { () -> FileInfo? in
            guard !isFolder else {
                return nil
            }

            let isTrashed = infoDict[GoogleDriveAPI.Keys.trashed] as? Bool ?? false
            return FileInfo(
                fileName: name,
                fileSize: (infoDict[GoogleDriveAPI.Keys.size] as? String).flatMap({ Int64($0) }),
                creationDate: Date(
                    iso8601string: infoDict[GoogleDriveAPI.Keys.createdTime] as? String),
                modificationDate: Date(
                    iso8601string: infoDict[GoogleDriveAPI.Keys.modifiedTime] as? String),
                isInTrash: isTrashed,
                hash: infoDict[GoogleDriveAPI.Keys.md5Checksum] as? String
            )
        }()

        let driveID = infoDict[GoogleDriveAPI.Keys.driveID] as? String
        return GoogleDriveItem(
            name: name,
            id: itemID,
            isFolder: isFolder,
            isShortcut: isShortcut,
            fileInfo: fileInfo,
            accountInfo: accountInfo,
            sharedDriveID: driveID
        )
    }
}

extension GoogleDriveManager {
    public func updateFile(
        _ item: GoogleDriveItem,
        contents: ByteArray,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {
        Diag.debug("Uploading file")

        var urlRequest = URLRequest(url: item.getRequestURL(.update))
        urlRequest.httpMethod = "PATCH"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: GoogleDriveAPI.Keys.authorization)
        urlRequest.setValue("application/octet-stream", forHTTPHeaderField: GoogleDriveAPI.Keys.contentType)
        urlRequest.httpBody = contents.asData

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = GoogleDriveAPI.ResponseParser
                .parseJSONResponse(operation: "updateFile", data: data, error: error)
            switch result {
            case .success(let json):
                if let file = parseItem(json, accountInfo: item.accountInfo) {
                    Diag.debug("Upload finished successfully")
                    completionQueue.addOperation {
                        completion(.success(UploadResponse(name: file.name, file: file)))
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
}

extension GoogleDriveManager {
    public func createFile(
        in folder: GoogleDriveItem,
        contents: ByteArray,
        fileName: String,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping CreateCompletionHandler<GoogleDriveItem>
    ) {
        Diag.debug("Creating new file")

        var urlRequest = URLRequest(url: folder.getRequestURL(.create))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: GoogleDriveAPI.Keys.authorization)
        urlRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: GoogleDriveAPI.Keys.contentType)
        urlRequest.timeoutInterval = timeout.duration

        var params: [String: Any] = [
            GoogleDriveAPI.Keys.name: fileName,
            GoogleDriveAPI.Keys.parents: [folder.id],
        ]
        if let driveID = folder.sharedDriveID {
            params[GoogleDriveAPI.Keys.driveID] = driveID
        }
        let postData = try! JSONSerialization.data(withJSONObject: params)
        urlRequest.httpBody = postData
        urlRequest.setValue(String(postData.count), forHTTPHeaderField: GoogleDriveAPI.Keys.contentLength)

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = GoogleDriveAPI.ResponseParser
                .parseJSONResponse(operation: "createFile", data: data, error: error)
            switch result {
            case .success(let json):
                if let newFile = parseItem(json, accountInfo: folder.accountInfo) {
                    Diag.debug("File created successfully, uploading content")
                    self.updateFile(
                        newFile,
                        contents: contents,
                        freshToken: token,
                        timeout: timeout,
                        completionQueue: completionQueue,
                        completion: adaptCreateCompletionAsUploadCompletion(completion)
                    )
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

    private func adaptCreateCompletionAsUploadCompletion(
        _ createCompletion: @escaping CreateCompletionHandler<GoogleDriveItem>
    ) -> UploadCompletionHandler {
        let uploadCompletion: UploadCompletionHandler = { result in
            switch result {
            case .success(let uploadResponse):
                createCompletion(.success(uploadResponse.file))
            case .failure(let remoteError):
                createCompletion(.failure(remoteError))
            }
        }
        return uploadCompletion
    }
}

extension GoogleDriveManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let sessionObjectID = ObjectIdentifier(session)
        return presentationAnchors[sessionObjectID]!.value!
    }
}
