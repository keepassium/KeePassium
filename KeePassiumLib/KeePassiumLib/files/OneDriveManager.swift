//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices

/*
 This code includes parts of https://github.com/lithium0003/ccViewer/blob/master/RemoteCloud/RemoteCloud/Storages/OneDriveStorage.swift
 by GitHub user lithium03, published under the MIT license.
 */
final public class OneDriveManager: RemoteDataSourceManager {
    public static let shared = OneDriveManager()

    private var presentationAnchors = [ObjectIdentifier: Weak<ASPresentationAnchor>]()

    private let urlSession: URLSession
    private var authProvider: OneDriveAuthProvider

    public var maxUploadSize: Int {
        return OneDriveAPI.maxUploadSize
    }

    private static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.OneDriveManager"
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 4
        return queue
    }()

    private init() {
        urlSession = {
            let config = URLSessionConfiguration.ephemeral
            config.allowsCellularAccess = true
            config.multipathServiceType = .none
            config.waitsForConnectivity = false
            return URLSession(
                configuration: config,
                delegate: nil,
                delegateQueue: OneDriveManager.backgroundQueue
            )
        }()
        authProvider = BasicOneDriveAuthProvider(urlSession: urlSession)
    }

    public func acquireTokenSilent(
        token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        authProvider.acquireTokenSilent(
            token: token,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }
}

extension OneDriveManager {

    public func setAuthProvider(_ authProvider: OneDriveAuthProvider) {
        self.authProvider = authProvider
    }

    public func authenticate(
        presenter: UIViewController,
        timeout: Timeout,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    ) {
        authProvider.acquireToken(
            presenter: presenter,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }
}

extension OneDriveManager {
    public func getAccountInfo(
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OneDriveDriveInfo, RemoteError>) -> Void
    ) {
        Diag.debug("Requesting drive info")
        let parentPath = OneDriveAPI.defaultDrivePath
        let driveInfoURL = URL(string: OneDriveAPI.mainEndpoint + parentPath)!
        var urlRequest = URLRequest(url: driveInfoURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "getDriveInfo", data: data, error: error)
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
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
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
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[OneDriveItem], RemoteError>) -> Void
    ) {
        let requestURL = folder.getRequestURL(.children)
        var urlRequest = URLRequest(url: requestURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "listFiles", data: data, error: error)
            switch result {
            case .success(let json):
                if let fileItems = parseFileListResponse(json, folder: folder) {
                    Diag.debug("File list acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(fileItems))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
                }
            }
        }
        dataTask.resume()
    }

    private func parseFileListResponse(
        _ json: [String: Any],
        folder: OneDriveItem
    ) -> [OneDriveItem]? {
        guard let items = json[OneDriveAPI.Keys.value] as? [[String: Any]] else {
            Diag.error("Failed to parse file list response: value field missing")
            return nil
        }

        let folderPath = folder.itemPath
        let parent = folder.parent
        let folderPathWithTrailingSlash = folderPath.withTrailingSlash()
        let result = items.compactMap { infoDict -> OneDriveItem? in
            guard let itemID = infoDict[OneDriveAPI.Keys.id] as? String,
                  let itemName = infoDict[OneDriveAPI.Keys.name] as? String
            else {
                Diag.debug("Failed to parse file item: id or name field missing; skipping the file")
                return nil
            }

            var fileItem = OneDriveItem(
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
                    attributes: [:],
                    isInTrash: false,
                    hash: parseFileHash(json: infoDict)
                ),
                driveInfo: folder.driveInfo
            )
            updateWithRemoteItemInfo(infoDict, fileItem: &fileItem)
            return fileItem
        }
        return result
    }

    private func parseFileHash(json: [String: Any]) -> String? {
        guard let file = json[OneDriveAPI.Keys.file] as? [String: Any],
              let hashes = file[OneDriveAPI.Keys.hashes] as? [String: Any],
              let hash = hashes[OneDriveAPI.Keys.hash] as? String else {
            return nil
        }
        return hash
    }

    private func updateWithRemoteItemInfo(
        _ infoDict: [String: Any],
        fileItem: inout OneDriveItem
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
        _ item: OneDriveItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OneDriveItem, RemoteError>) -> Void
    ) {
        let fileInfoRequestURL = item.getRequestURL(.itemInfo)
        var urlRequest = URLRequest(url: fileInfoRequestURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { [self] data, response, error in
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "itemInfo", data: data, error: error)
            switch result {
            case .success(let json):
                let fileItems = parseItemInfoResponse(
                    json,
                    path: item.itemPath,
                    parent: item.parent,
                    driveInfo: item.driveInfo
                )
                if let fileItems {
                    Diag.debug("File list acquired successfully")
                    completionQueue.addOperation {
                        completion(.success(fileItems))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
                }
            }
        }
        dataTask.resume()
    }

    private func parseItemInfoResponse(
        _ json: [String: Any],
        path: String,
        parent: OneDriveSharedFolder?,
        driveInfo: OneDriveDriveInfo
    ) -> OneDriveItem? {
        guard let itemID = json[OneDriveAPI.Keys.id] as? String,
              let itemName = json[OneDriveAPI.Keys.name] as? String
        else {
            Diag.debug("Failed to parse item info: id or name field missing")
            return nil
        }

        let itemDriveInfo: OneDriveDriveInfo
        if let parentRef = json[OneDriveAPI.Keys.parentReference] as? [String: String],
           let driveID = parentRef[OneDriveAPI.Keys.driveId],
           let driveName = parentRef[OneDriveAPI.Keys.name],
           let driveTypeString = parentRef[OneDriveAPI.Keys.driveType],
           let driveType = OneDriveDriveInfo.DriveType(rawValue: driveTypeString)
        {
            let driveOwner = parentRef[OneDriveAPI.Keys.owner]
            itemDriveInfo = OneDriveDriveInfo(id: driveID, name: driveName, type: driveType, ownerName: driveOwner)
        } else {
            Diag.debug("Using fallback drive info")
            itemDriveInfo = driveInfo
        }

        return OneDriveItem(
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
                attributes: [:],
                isInTrash: false,
                hash: parseFileHash(json: json)
            ),
            driveInfo: itemDriveInfo
        )
    }
}

extension OneDriveManager {
    public func updateItemInfo(
        _ fileItem: OneDriveItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OneDriveItem, RemoteError>) -> Void
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
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "updateItemInfo", data: data, error: error)
            switch result {
            case .success(let json):
                Diag.debug("Updating item with remote info")
                var mutableFileItem = fileItem
                self.updateItemInfo(json, fileItem: &mutableFileItem)
                completionQueue.addOperation {
                    completion(.success(mutableFileItem))
                }
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
                }
            }
        }
        dataTask.resume()
    }

    private func updateItemInfo(_ infoDict: [String: Any?], fileItem: inout OneDriveItem) {
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
        _ item: OneDriveItem,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<Data, RemoteError>) -> Void
    ) {
        let fileContentsURL = item.getRequestURL(.content)
        var urlRequest = URLRequest(url: fileContentsURL)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.timeoutInterval = timeout.duration

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
               let json = OneDriveAPI.ResponseParser.parseJSONDict(data: data),
               let serverError = OneDriveAPI.ResponseParser.getServerError(from: json)
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
    public struct UploadResponse {
        var itemID: String
        var finalName: String
    }

    public func updateFile(
        _ item: OneDriveItem,
        contents: ByteArray,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {

        Diag.debug("Creating upload session")

        let createSessionURL = item.getRequestURL(.createUploadSessionForUpdating)
        var urlRequest = URLRequest(url: createSessionURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: OneDriveAPI.Keys.contentType)
        let postData = try! JSONSerialization.data(withJSONObject: [
            "@microsoft.graph.conflictBehavior": "rename",
        ])
        urlRequest.httpBody = postData
        urlRequest.setValue(String(postData.count), forHTTPHeaderField: OneDriveAPI.Keys.contentLength)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "uploadSession", data: data, error: error)
            switch result {
            case .success(let json):
                if let uploadURL = self.parseCreateUploadSessionResponse(json) {
                    Diag.debug("Upload session created successfully")
                    self.uploadData(
                        contents,
                        toURL: uploadURL,
                        timeout: timeout,
                        completionQueue: completionQueue,
                        completion: completion
                    )
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
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
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {
        Diag.debug("Uploading file contents")
        assert(data.count < OneDriveAPI.maxUploadSize, "Upload request is too large; range uploads are not implemented")

        var urlRequest = URLRequest(url: targetURL)
        urlRequest.httpMethod = "PUT"
        urlRequest.timeoutInterval = timeout.duration
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
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "uploadData", data: data, error: error)
            switch result {
            case .success(let json):
                if let uploadResponse = self.parseUploadDataResponse(json) {
                    Diag.debug("File contents uploaded successfully")
                    completionQueue.addOperation {
                        completion(.success(uploadResponse))
                    }
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
                }
            }
        }
        dataTask.resume()
    }

    private func parseUploadDataResponse(_ json: [String: Any]) -> UploadResponse? {
        Diag.debug("Upload complete")
        guard let fileName = json[OneDriveAPI.Keys.name] as? String else {
            Diag.debug("Failed to parse upload response: name field missing")
            return nil
        }
        guard let itemID = json[OneDriveAPI.Keys.id] as? String else {
            Diag.debug("Failed to parse upload response: itemID field missing")
            return nil
        }
        return UploadResponse(itemID: itemID, finalName: fileName)
    }
}

extension OneDriveManager {
    public func createFile(
        in folder: OneDriveItem,
        contents: ByteArray,
        fileName: String,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping CreateCompletionHandler<OneDriveItem>
    ) {
        Diag.debug("Creating new file")

        let createSessionURL = folder.getRequestURL(.createUploadSessionForCreating(newFileName: fileName))

        var urlRequest = URLRequest(url: createSessionURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: OneDriveAPI.Keys.authorization)
        urlRequest.setValue("application/json; charset=UTF-8", forHTTPHeaderField: OneDriveAPI.Keys.contentType)
        let postData = try! JSONSerialization.data(withJSONObject: [
            "@microsoft.graph.conflictBehavior": "rename",
            "name": fileName,
        ])
        urlRequest.httpBody = postData
        urlRequest.setValue(String(postData.count), forHTTPHeaderField: OneDriveAPI.Keys.contentLength)
        urlRequest.timeoutInterval = timeout.duration

        let dataTask = urlSession.dataTask(with: urlRequest) { data, response, error in
            let result = OneDriveAPI.ResponseParser
                .parseJSONResponse(operation: "uploadSession", data: data, error: error)
            switch result {
            case .success(let json):
                if let uploadURL = self.parseCreateUploadSessionResponse(json) {
                    Diag.debug("Upload session created successfully")
                    self.uploadData(
                        contents,
                        toURL: uploadURL,
                        timeout: timeout,
                        completionQueue: completionQueue,
                        completion: { result in
                            assert(completionQueue.isCurrent)
                            switch result {
                            case .success(let uploadResponse):
                                let newFileItem = folder.childFileItem(
                                    name: uploadResponse.finalName,
                                    itemID: uploadResponse.itemID
                                )
                                completion(.success(newFileItem))
                            case .failure(let remoteError):
                                completion(.failure(remoteError))
                            }
                        }
                    )
                } else {
                    completionQueue.addOperation {
                        completion(.failure(.misformattedResponse))
                    }
                }
            case .failure(let remoteError):
                completionQueue.addOperation {
                    completion(.failure(remoteError))
                }
            }
        }
        dataTask.resume()
    }
}
