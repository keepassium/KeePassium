//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices

public enum OneDriveError: LocalizedError {
    case cancelledByUser
    case emptyResponse
    case misformattedResponse
    case cannotRefreshToken
    case authorizationRequired
    case serverSideError(message: String)
    case general(error: Error)
    
    public var errorDescription: String? {
        switch self {
        case .cancelledByUser:
            return "Cancelled by user." 
        case .emptyResponse:
            return "Server response is empty."
        case .misformattedResponse:
            return "Unexpected server response format."
        case .cannotRefreshToken:
            return "Cannot renew access token."
        case .authorizationRequired:
            return LString.titleOneDriveRequiresSignIn
        case .serverSideError(let message):
            return message
        case .general(let error):
            return error.localizedDescription
        }
    }
}

public struct OneDriveDriveInfo {
    public enum DriveType: String, CustomStringConvertible {
        case personal = "personal"
        case business = "business"
        case sharepoint = "documentLibrary"
        public var description: String {
            switch self {
            case .personal:
                return LString.connectionTypeOneDrive
            case .business:
                return LString.connectionTypeOneDriveForBusiness
            case .sharepoint:
                return LString.connectionTypeSharePoint
            }
        }
    }
    
    public var id: String
    public var name: String
    public var type: DriveType
    public var ownerName: String? // e.g. "AdeleV@contoso.com" or "Adele Vance" or nil
}


internal enum OneDriveAPI {
    static var clientID: String {
        if BusinessModel.isIntuneEdition {
            return "292a80b3-139a-4165-a20d-b2d2e764e538"
        }
        switch BusinessModel.type {
        case .freemium:
            return "cd88bd1f-abdf-4d0f-921e-d8acbf02e240"
        case .prepaid:
            return "c3885b4b-5dac-43a6-af93-c869c1a8328b"
        }
    }
    static let scope = "user.read files.readwrite.all offline_access"
        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    static let callbackURLScheme = AppGroup.appURLScheme
    static let redirectURI = "\(AppGroup.appURLScheme)://onedrive-auth"
    static let authURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize?client_id=\(clientID)&scope=\(scope)&prompt=select_account&response_type=code&redirect_uri=\(redirectURI)")!
    static let tokenRequestURL = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!
    static let itemFields = "id,name,size,createdDateTime,lastModifiedDateTime,folder,file,remoteItem"
    
    static let mainEndpoint = "https://graph.microsoft.com/v1.0"
    static let defaultDrivePath = "/me/drive"
    static let personalDriveRootPath = defaultDrivePath + "/root"
    static let sharedWithMeRootPath = defaultDrivePath + "/sharedWithMe"
    
    static let maxUploadSize = 60 * 1024 * 1024 
    
    internal enum Keys {
        static let accessToken = "access_token"
        static let authorization = "Authorization"
        static let code = "code"
        static let contentLength = "Content-Length"
        static let contentRange = "Content-Range"
        static let contentType = "Content-Type"
        static let createdDateTime = "createdDateTime"
        static let displayName = "displayName"
        static let driveId = "driveId"
        static let driveType = "driveType"
        static let email = "email"
        static let error = "error"
        static let errorSubcode = "error_subcode"
        static let errorDescription = "error_description"
        static let errorURI = "error_uri"
        static let expiresIn = "expires_in"
        static let id = "id"
        static let file = "file"
        static let folder = "folder"
        static let lastModifiedDateTime = "lastModifiedDateTime"
        static let message = "message"
        static let name = "name"
        static let owner = "owner"
        static let parentReference = "parentReference"
        static let path = "path"
        static let refreshToken = "refresh_token"
        static let remoteItem = "remoteItem"
        static let size = "size"
        static let suberror = "suberror"
        static let uploadUrl = "uploadUrl"
        static let user = "user"
        static let value = "value"
    }
}

/*
 This code includes parts of https://github.com/lithium0003/ccViewer/blob/master/RemoteCloud/RemoteCloud/Storages/OneDriveStorage.swift
 by GitHub user lithium03, published under the MIT license.
 */
final public class OneDriveManager: NSObject {
    public typealias TokenUpdateCallback = (OAuthToken) -> Void
    
    public static let shared = OneDriveManager()
    
    private var presentationAnchors = [ObjectIdentifier: Weak<ASPresentationAnchor>]()
    
    private lazy var urlSession: URLSession = {
        var config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.multipathServiceType = .none
        config.waitsForConnectivity = false
        return URLSession(
            configuration: config,
            delegate: nil,
            delegateQueue: OneDriveManager.backgroundQueue
        )
    }()
    private static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.OneDriveManager"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()
    
    override private init() {
        super.init()
    }
}

extension OneDriveManager {
    private func parseJSONResponse(
        operation: String,
        data: Data?,
        error: Error?
    ) -> Result<[String: Any], OneDriveError> {
        if let error = error {
            Diag.error("OneDrive request failed [operation: \(operation), message: \(error.localizedDescription)]")
            return .failure(.general(error: error))
        }
        guard let data = data else {
            Diag.error("OneDrive request failed: no data received [operation: \(operation)]")
            return .failure(.emptyResponse)
        }

        guard let json = parseJSONDict(data: data) else {
            Diag.error("OneDrive request failed: misformatted response [operation: \(operation)]")
            return .failure(.emptyResponse)
        }

        
        if let serverError = getServerError(from: json) {
            Diag.error("OneDrive request failed: server-side error [operation: \(operation), message: \(serverError.localizedDescription)]")
            return .failure(serverError)
        }
        return .success(json)
    }
    
    
    private func parseJSONDict(data: Data) -> [String: Any]? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            guard let json = jsonObject as? [String: Any] else {
                Diag.error("Unexpected JSON format")
                return nil
            }
            return json
        } catch {
            Diag.error("Failed to parse JSON data [message: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func getServerError(from json: [String: Any]) -> OneDriveError? {
        guard let error = json[OneDriveAPI.Keys.error] else { 
            return nil
        }
        let errorDetails = json.description
        Diag.error(errorDetails)
        if let errorDict = error as? [String: Any] {
            let message = (errorDict[OneDriveAPI.Keys.message] as? String) ?? "UnknownError"
            return OneDriveError.serverSideError(message: message)
        }
        
        let errorKind = (error as? String) ?? "OneDriveError"
        let suberrorKind = json[OneDriveAPI.Keys.suberror] as? String
        switch (errorKind, suberrorKind) {
        case ("invalid_grant", "token_expired"):
            Diag.warning("Authorization token expired")
            return .authorizationRequired
        default:
            let errorDescription = (json[OneDriveAPI.Keys.errorDescription] as?  String) ?? errorKind
            Diag.warning("Server-side OneDrive error [message: \(errorDescription)]")
            return .serverSideError(message: errorDescription)
        }
    }
}

extension OneDriveManager {
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
    
    public func authenticate(
        presenter: UIViewController,
        privateSession: Bool,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) {
        Diag.info("Authenticating with OneDrive")
        
        let webAuthSession = ASWebAuthenticationSession(
            url: OneDriveAPI.authURL,
            callbackURLScheme: OneDriveAPI.callbackURLScheme,
            completionHandler: { (callbackURL: URL?, error: Error?) in
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
                
                let error = queryItems.getValue(name: OneDriveAPI.Keys.error)
                let errorSubcode = queryItems.getValue(name: OneDriveAPI.Keys.errorSubcode)
                switch (error, errorSubcode) {
                case ("access_denied", "cancel"):
                    completionQueue.addOperation {
                        Diag.error("Access denied, authentication cancelled")
                        completion(.failure(.cancelledByUser))
                    }
                    return
                default:
                    break
                }
                
                if let errorDescription = queryItems.getValue(name: OneDriveAPI.Keys.errorDescription)?
                    .removingPercentEncoding?
                    .replacingOccurrences(of: "+", with: " ")
                {
                    completionQueue.addOperation {
                        Diag.error("Authentication failed: \(errorDescription)")
                        completion(.failure(.serverSideError(message: errorDescription)))
                    }
                    return
                }
                                          
                guard let codeItem = queryItems[OneDriveAPI.Keys.code],
                      let authCodeString = codeItem.value
                else {
                    completionQueue.addOperation {
                        Diag.error("Authentication failed: OAuth token not found in response")
                        completion(.failure(.misformattedResponse))
                    }
                    return
                }
                self.getToken(
                    operation: .authorization(code: authCodeString),
                    completionQueue: completionQueue,
                    completion: completion
                )
            }
        )
        presentationAnchors[ObjectIdentifier(webAuthSession)] = Weak(presenter.view.window!)
        webAuthSession.presentationContextProvider = self
        webAuthSession.prefersEphemeralWebBrowserSession = privateSession

        webAuthSession.start()
    }
    
    private func getToken(
        operation: TokenOperation,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) {
        Diag.debug("Acquiring OAuth token [operation: \(operation)]")
        var urlRequest = URLRequest(url: OneDriveAPI.tokenRequestURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded; charset=UTF-8",
            forHTTPHeaderField: OneDriveAPI.Keys.contentType)
        
        var postParams = [
            "client_id=\(OneDriveAPI.clientID)",
            "redirect_uri=\(OneDriveAPI.redirectURI)",
        ]
        
        let refreshToken: String?
        switch operation {
        case .authorization(let authCode):
            refreshToken = nil
            postParams.append("code=\(authCode)")
            postParams.append("grant_type=authorization_code")
        case .refresh(let token):
            refreshToken = token.refreshToken
            postParams.append("refresh_token=\(token.refreshToken)")
            postParams.append("grant_type=refresh_token")
        }
        
        let postData = postParams
            .joined(separator: "&")
            .data(using: .ascii, allowLossyConversion: false)!
        let postLength = "\(postData.count)"
        urlRequest.setValue(postLength, forHTTPHeaderField: OneDriveAPI.Keys.contentLength)
        urlRequest.httpBody = postData
        
        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(
                operation: operation.description,
                data: data,
                error: error
            )
            switch result {
            case .success(let json):
                if let token = self.parseTokenResponse(json: json, currentRefreshToken: refreshToken) {
                    Diag.debug("OAuth token acquired successfully [operation: \(operation)]")
                    completionQueue.addOperation {
                        completion(.success(token))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseTokenResponse(json: [String: Any], currentRefreshToken: String?) -> OAuthToken? {
        guard let accessToken = json[OneDriveAPI.Keys.accessToken] as? String else {
            Diag.error("Failed to parse token response: access_token missing")
            return nil
        }
        guard let expires_in = json[OneDriveAPI.Keys.expiresIn] as? Int else {
            Diag.error("Failed to parse token response: expires_in missing")
            return nil
        }
        let newRefreshToken = json[OneDriveAPI.Keys.refreshToken] as? String
        guard let refreshToken = (newRefreshToken ?? currentRefreshToken) else {
            Diag.error("Failed to parse token response: refresh_token missing")
            return nil
        }
        
        let token = OAuthToken(
            accessToken: accessToken,
            refreshToken: refreshToken,
            acquired: Date.now,
            lifespan: TimeInterval(expires_in)
        )
        return token
    }
    
    private func maybeRefreshToken(
        token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, OneDriveError>) -> Void
    ) -> Void {
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
                completionQueue: completionQueue,
                completion: completion
            )
        }
    }
}

extension OneDriveManager: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let sessionObjectID = ObjectIdentifier(session)
        return presentationAnchors[sessionObjectID]!.value!
    }
}

extension OneDriveManager {
    public func getDriveInfo(
        parent: OneDriveSharedFolder?,
        freshToken token: OAuthToken,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<OneDriveDriveInfo, OneDriveError>) -> Void
    ) {
        Diag.debug("Requesting drive info")
        let parentPath = parent?.urlPath ?? OneDriveAPI.defaultDrivePath
        let driveInfoURL = URL(string: OneDriveAPI.mainEndpoint + parentPath)!
        var urlRequest = URLRequest(url: driveInfoURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        
        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(operation: "getDriveInfo", data: data, error: error)
            switch result {
            case .success(let json):
                if let driveInfo = self.parseDriveInfoResponse(json: json) {
                    Diag.debug("Drive info received successfully")
                    completionQueue.addOperation {
                        completion(.success(driveInfo))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseDriveInfoResponse(json: [String: Any]) -> OneDriveDriveInfo? {
        guard let driveID = json[OneDriveAPI.Keys.id] as? String else {
            Diag.error("Failed to parse drive info: id field missing")
            return nil
        }
        guard let driveTypeString = json[OneDriveAPI.Keys.driveType] as? String else {
            Diag.error("Failed to parse drive info: driveType field missing")
            return nil
        }
        
        let driveName = (json[OneDriveAPI.Keys.name] as? String) ?? "OneDrive"

        var ownerName: String?
        if let ownerDict = json[OneDriveAPI.Keys.owner] as? [String: Any],
           let userDict = ownerDict[OneDriveAPI.Keys.user] as? [String: Any]
        {
            let ownerEmailString = userDict[OneDriveAPI.Keys.email] as? String
            let ownerDisplayName = userDict[OneDriveAPI.Keys.displayName] as? String
            ownerName = ownerEmailString ?? ownerDisplayName 
        }

        let result = OneDriveDriveInfo(
            id: driveID,
            name: driveName,
            type: .init(rawValue: driveTypeString) ?? .personal,
            ownerName: ownerName
        )
        return result
    }
}

extension OneDriveManager {
    
    public func getItems(
        in folder: OneDriveItem,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<[OneDriveFileItem], OneDriveError>)->Void
    ) {
        Diag.debug("Acquiring file list")
        maybeRefreshToken(token: token, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.getItems(
                    in: folder,
                    freshToken: newToken,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
                return
            }
        }
    }
    
    private func getItems(
        in folder: OneDriveItem,
        freshToken token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[OneDriveFileItem], OneDriveError>)->Void
    ) {
        let requestURL = folder.getChildrenRequestURL()
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        
        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(operation: "listFiles", data: data, error: error)
            switch result {
            case .success(let json):
                if let fileItems = self.parseFileListResponse(json, folder: folder as? OneDriveFileItem) {
                    Diag.debug("File list acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(fileItems))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseFileListResponse(
        _ json: [String: Any],
        folder: OneDriveFileItem?
    ) -> [OneDriveFileItem]? {
        guard let items = json[OneDriveAPI.Keys.value] as? [[String: Any]] else {
            Diag.error("Failed to parse file list response: value field missing")
            return nil
        }
        
        let folderPath = folder?.itemPath ?? "/"
        let parent = folder?.parent
        let folderPathWithTrailingSlash = folderPath.withTrailingSlash()
        let result = items.compactMap { infoDict -> OneDriveFileItem? in
            guard let itemID = infoDict[OneDriveAPI.Keys.id] as? String,
                  let itemName = infoDict[OneDriveAPI.Keys.name] as? String
            else {
                Diag.debug("Failed to parse file item: id or name field missing; skipping the file")
                return nil
            }
            
            var fileItem = OneDriveFileItem(
                name: itemName,
                itemID: itemID,
                itemPath: folderPathWithTrailingSlash + itemName,
                parent: parent,
                isFolder: infoDict[OneDriveAPI.Keys.folder] != nil,
                fileInfo: FileInfo(
                    fileName: itemName,
                    fileSize: infoDict[OneDriveAPI.Keys.size] as? Int64,
                    creationDate: Date(
                        iso8601string: infoDict[OneDriveAPI.Keys.createdDateTime] as? String),
                    modificationDate: Date(
                        iso8601string: infoDict[OneDriveAPI.Keys.lastModifiedDateTime] as? String),
                    isExcludedFromBackup: nil,
                    isInTrash: false 
                )
            )
            updateWithRemoteItemInfo(infoDict, fileItem: &fileItem)
            return fileItem
        }
        return result
    }
    
    
    private func updateWithRemoteItemInfo(
        _ infoDict: [String: Any],
        fileItem: inout OneDriveFileItem
    ) {
        guard let remoteItemDict = infoDict[OneDriveAPI.Keys.remoteItem] as? [String: Any] else {
            return 
        }
        
        guard let remoteItemID = remoteItemDict[OneDriveAPI.Keys.id] as? String else {
            Diag.warning("Unexpected remote item format: item ID field missing")
            return
        }
        guard let parentReference = remoteItemDict[OneDriveAPI.Keys.parentReference] as? [String: Any] else {
            Diag.warning("Unexpected remote item format: parentReference field missing")
            return
        }
        guard let remoteDriveID = parentReference[OneDriveAPI.Keys.driveId] as? String else {
            Diag.warning("Unexpected remote item format: parent driveId field missing")
            return
        }
        let remoteParentID = parentReference[OneDriveAPI.Keys.id] as? String 
        let remotePath = parentReference[OneDriveAPI.Keys.path] as? String 
        fileItem.itemID = remoteItemID
        
        fileItem.isFolder = remoteItemDict[OneDriveAPI.Keys.folder] != nil
        if fileItem.isFolder {
            fileItem.parent = OneDriveSharedFolder(
                driveID: remoteDriveID,
                itemID: remoteItemID,
                name: remotePath ?? fileItem.name
            )
            
            fileItem.itemPath = "/"
        } else {
            fileItem.parent = OneDriveSharedFolder(
                driveID: remoteDriveID,
                itemID: "", 
                name: remotePath ?? ""
            )
        }
        
    }
}

extension OneDriveManager {
    
    public func getItemInfo(
        _ item: OneDriveItemReference,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<OneDriveFileItem, OneDriveError>)->Void
    ) {
        Diag.debug("Acquiring file list")
        maybeRefreshToken(token: token, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.getItemInfo(
                    item,
                    freshToken: newToken,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
                return
            }
        }
    }
    
    private func getItemInfo(
        _ item: OneDriveItemReference,
        freshToken token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OneDriveFileItem, OneDriveError>)->Void
    ) {
        let encodedPath = item.path
            .withLeadingSlash()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let parentPath = item.parent?.urlPath ?? OneDriveAPI.personalDriveRootPath
        let urlString = OneDriveAPI.mainEndpoint + parentPath + ":\(encodedPath)"

        let fileInfoRequestURL = URL(string: urlString)!
        var urlRequest = URLRequest(url: fileInfoRequestURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        
        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(operation: "itemInfo", data: data, error: error)
            switch result {
            case .success(let json):
                if let fileItems = self.parseItemInfoResponse(json, path: item.path, parent: item.parent) {
                    Diag.debug("File list acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(fileItems))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseItemInfoResponse(
        _ json: [String: Any],
        path: String,
        parent: OneDriveSharedFolder?
    ) -> OneDriveFileItem? {
        guard let itemID = json[OneDriveAPI.Keys.id] as? String,
              let itemName = json[OneDriveAPI.Keys.name] as? String
        else {
            Diag.debug("Failed to parse item info: id or name field missing")
            return nil
        }
        return OneDriveFileItem(
            name: itemName,
            itemID: itemID,
            itemPath: path,
            parent: parent,
            isFolder: json[OneDriveAPI.Keys.folder] != nil,
            fileInfo: FileInfo(
                fileName: itemName,
                fileSize: json[OneDriveAPI.Keys.size] as? Int64,
                creationDate: Date(iso8601string: json[OneDriveAPI.Keys.createdDateTime] as? String),
                modificationDate: Date(iso8601string: json[OneDriveAPI.Keys.lastModifiedDateTime] as? String),
                isExcludedFromBackup: nil,
                isInTrash: false 
            )
        )
    }
}

extension OneDriveManager {
    public func updateItemInfo(
        _ fileItem: OneDriveFileItem,
        freshToken token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OneDriveFileItem, OneDriveError>)->Void
    ) {
        guard let parent = fileItem.parent else {
            completionQueue.addOperation {
                completion(.success(fileItem))
            }
            return
        }
        
        let parentDrivePath = "/drives/\(parent.driveID)"
        let urlString = OneDriveAPI.mainEndpoint + parentDrivePath + "/items/\(fileItem.itemID)"

        let fileInfoRequestURL = URL(string: urlString)!
        var urlRequest = URLRequest(url: fileInfoRequestURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        
        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(operation: "updateItemInfo", data: data, error: error)
            switch result {
            case .success(let json):
                Diag.debug("Updating item with remote info")
                var mutableFileItem = fileItem
                self.updateItemInfo(json, fileItem: &mutableFileItem)
                completionQueue.addOperation {
                    completion(.success(mutableFileItem))
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func updateItemInfo(_ infoDict: [String: Any?], fileItem: inout OneDriveFileItem) {
        guard let itemID = infoDict[OneDriveAPI.Keys.id] as? String else {
            Diag.warning("Unexpected item format: item ID field missing")
            return
        }
        
        guard let itemName = infoDict[OneDriveAPI.Keys.name] as? String else {
            Diag.warning("Unexpected item format: name field missing")
            return
        }
        guard let parentReference = infoDict[OneDriveAPI.Keys.parentReference] as? [String: Any] else {
            Diag.warning("Unexpected item format: parentReference field missing")
            return
        }
        guard let parentDriveID = parentReference[OneDriveAPI.Keys.driveId] as? String else {
            Diag.warning("Unexpected item format: parent driveId field missing")
            return
        }
        guard let parentItemID = parentReference[OneDriveAPI.Keys.id] as? String else {
            Diag.warning("Unexpected item format: parent ID field missing")
            return
        }
        
        var parentPath = parentReference[OneDriveAPI.Keys.path] as? String 
        if parentPath != nil,
           let separatorIndex = parentPath!.firstIndex(of: ":")
        {
            let pathStartIndex = parentPath!.index(after: separatorIndex)
            parentPath = parentPath!.suffix(from: pathStartIndex).removingPercentEncoding
            if parentPath?.isEmpty ?? false {
                parentPath = nil
            }
        }

        fileItem.itemID = itemID
        fileItem.name = itemName
        fileItem.itemPath = "/\(itemName)"
        let parentName = parentPath ?? fileItem.parent?.name ?? "?"
        fileItem.parent = OneDriveSharedFolder(
            driveID: parentDriveID,
            itemID: parentItemID,
            name: parentName
        )
        Diag.debug("Item info updated successfully")
    }
}
extension OneDriveManager {
    
    public func getFileContents(
        _ item: OneDriveItemReference,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<Data, OneDriveError>) -> Void
    ) {
        Diag.debug("Downloading file")
        maybeRefreshToken(token: token, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.getFileContents(
                    item,
                    freshToken: newToken,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
                return
            }
        }
    }
    
    private func getFileContents(
        _ item: OneDriveItemReference,
        freshToken token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping (Result<Data, OneDriveError>) -> Void
    ) {
        let encodedPath = item.path
            .withLeadingSlash()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let parentPath = item.parent?.urlPath ?? OneDriveAPI.personalDriveRootPath
        let urlString = OneDriveAPI.mainEndpoint + parentPath + ":\(encodedPath):/content"
        let fileContentsURL = URL(string: urlString)!
        var urlRequest = URLRequest(url: fileContentsURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        
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
            if response?.mimeType == "application/json",
               let json = self.parseJSONDict(data: data),
               let serverError = self.getServerError(from: json)
            {
                completionQueue.addOperation {
                    Diag.error("Failed to download file, server returned error [message: \(serverError.localizedDescription)]")
                    completion(.failure(serverError))
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

extension OneDriveManager {
    public typealias UploadCompletionHandler = (Result<String, OneDriveError>) -> Void
    
    public func uploadFile(
        _ item: OneDriveItemReference,
        contents: ByteArray,
        fileName: String,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        completionQueue: OperationQueue = .main,
        completion: @escaping UploadCompletionHandler
    ) {
        Diag.debug("Uploading file")
        
        guard contents.count < OneDriveAPI.maxUploadSize else {
            Diag.error("Such a large upload is not supported. Please contact support. [fileSize: \(contents.count)]")
            completionQueue.addOperation {
                completion(.failure(.serverSideError(message: "Upload is too large")))
            }
            return
        }
        
        maybeRefreshToken(token: token, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.uploadFile(
                    item,
                    contents: contents,
                    fileName: fileName,
                    freshToken: newToken,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
                return
            }
        }
    }
    
    private func uploadFile(
        _ item: OneDriveItemReference,
        contents: ByteArray,
        fileName: String,
        freshToken token: OAuthToken,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {
        
        Diag.debug("Creating upload session")
        let encodedPath = item.path
            .withLeadingSlash()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let parentPath = item.parent?.urlPath ?? OneDriveAPI.personalDriveRootPath
        let urlString = OneDriveAPI.mainEndpoint + parentPath + ":\(encodedPath):/createUploadSession"
        
        let createSessionURL = URL(string: urlString)!
        var urlRequest = URLRequest(url: createSessionURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: OneDriveAPI.Keys.contentType)
        let postData = try! JSONSerialization.data(withJSONObject: [
            "@microsoft.graph.conflictBehavior": "rename"
        ])
        urlRequest.httpBody = postData
        urlRequest.setValue(String(postData.count), forHTTPHeaderField: OneDriveAPI.Keys.contentLength)
        

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(operation: "uploadSession", data: data, error: error)
            switch result {
            case .success(let json):
                if let uploadURL = self.parseCreateUploadSessionResponse(json) {
                    Diag.debug("Upload session created successfully")
                    self.uploadData(
                        contents,
                        toURL: uploadURL,
                        completionQueue: completionQueue,
                        completion: completion
                    )
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseCreateUploadSessionResponse(_ json: [String: Any]) -> URL? {
        guard let uploadURLString = json[OneDriveAPI.Keys.uploadUrl] as? String else {
            Diag.debug("Failed to parse upload session response: uploadUrl field missing")
            return nil
        }
        guard let uploadURL = URL(string: uploadURLString) else {
            Diag.debug("Failed to parse upload session URL")
            return nil
        }
        return uploadURL
    }
    
    private func uploadData(
        _ data: ByteArray,
        toURL targetURL: URL,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {
        Diag.debug("Uploading file contents")
        assert(data.count < OneDriveAPI.maxUploadSize, "Upload request is too large; range uploads are not implemented")

        var urlRequest = URLRequest(url: targetURL)
        urlRequest.httpMethod = "PUT"
        
        let fileSize = data.count 
        let range = 0..<data.count
        urlRequest.setValue(
            String(range.count),
            forHTTPHeaderField: OneDriveAPI.Keys.contentLength) 
        urlRequest.setValue(
            "bytes \(range.first!)-\(range.last!)/\(fileSize)",
            forHTTPHeaderField: OneDriveAPI.Keys.contentRange) 
        urlRequest.httpBody = data.asData[range]

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = self.parseJSONResponse(operation: "uploadData", data: data, error: error)
            switch result {
            case .success(let json):
                if let finalName = self.parseUploadDataResponse(json) {
                    Diag.debug("File contents uploaded successfully")
                    completionQueue.addOperation {
                        completion(.success(finalName))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let oneDriveError):
                completionQueue.addOperation {
                    completion(.failure(oneDriveError))
                }
            }
        }
        dataTask.resume()
    }
    
    private func parseUploadDataResponse(_ json: [String: Any]) -> String? {
        Diag.debug("Upload complete")
        guard let fileName = json[OneDriveAPI.Keys.name] as? String else {
            Diag.debug("Failed to parse upload response: name field missing")
            return nil
        }
        return fileName
    }
}
