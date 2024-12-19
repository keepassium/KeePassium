//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public typealias TokenUpdateCallback = (OAuthToken) -> Void
public typealias CreateCompletionHandler<ItemType> = (Result<ItemType, RemoteError>) -> Void

public protocol RemoteDataSourceManager<ItemType> {
    associatedtype ItemType: SerializableRemoteFileItem
    associatedtype AccountInfo
    associatedtype UploadResponse
    typealias UploadCompletionHandler = (Result<UploadResponse, RemoteError>) -> Void

    var maxUploadSize: Int { get }

    func acquireTokenSilent(
        token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    )

    func getItems(
        in folder: ItemType,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[ItemType], RemoteError>) -> Void
    )

    func getFileContents(
        _ item: ItemType,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<Data, RemoteError>) -> Void
    )

    func getItemInfo(
        _ item: ItemType,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<ItemType, RemoteError>) -> Void
    )

    func updateFile(
        _ item: ItemType,
        contents: ByteArray,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    )

    func createFile(
        in folder: ItemType,
        contents: ByteArray,
        fileName: String,
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping CreateCompletionHandler<ItemType>
    )

    func authenticate(
        presenter: UIViewController,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<OAuthToken, RemoteError>) -> Void
    )

    func getAccountInfo(
        freshToken token: OAuthToken,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<AccountInfo, RemoteError>) -> Void
    )
}

extension RemoteDataSourceManager {
    public func getItems(
        in folder: ItemType,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping (Result<[ItemType], RemoteError>) -> Void
    ) {
        Diag.debug("Acquiring file list")
        acquireTokenSilent(token: token, timeout: timeout, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.getItems(
                    in: folder,
                    freshToken: newToken,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
                return
            }
        }
    }

    public func getFileContents(
        _ item: ItemType,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        timeout: Timeout,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<Data, RemoteError>) -> Void
    ) {
        Diag.debug("Downloading file")
        acquireTokenSilent(token: token, timeout: timeout, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.getFileContents(
                    item,
                    freshToken: newToken,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
                return
            }
        }
    }

    public func updateFile(
        _ fileItem: ItemType,
        contents: ByteArray,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        timeout: Timeout,
        completionQueue: OperationQueue,
        completion: @escaping UploadCompletionHandler
    ) {
        Diag.debug("Uploading file")
        assert(!fileItem.isFolder)

        guard contents.count < maxUploadSize else {
            Diag.error("Such a large upload is not supported. Please contact support. [fileSize: \(contents.count)]")
            completionQueue.addOperation {
                completion(.failure(.serverSideError(message: "Upload is too large")))
            }
            return
        }

        acquireTokenSilent(token: token, timeout: timeout, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.updateFile(
                    fileItem,
                    contents: contents,
                    freshToken: newToken,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
                return
            }
        }
    }

    public func getItemInfo(
        _ item: ItemType,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        timeout: Timeout,
        completionQueue: OperationQueue = .main,
        completion: @escaping (Result<ItemType, RemoteError>) -> Void
    ) {
        Diag.debug("Acquiring file info")
        acquireTokenSilent(token: token, timeout: timeout, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.getItemInfo(
                    item,
                    freshToken: newToken,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
                return
            }
        }
    }

    public func createFile(
        in folder: ItemType,
        contents: ByteArray,
        fileName: String,
        token: OAuthToken,
        tokenUpdater: TokenUpdateCallback?,
        timeout: Timeout,
        completionQueue: OperationQueue = .main,
        completion: @escaping CreateCompletionHandler<ItemType>
    ) {
        Diag.debug("Creating a file")
        assert(folder.isFolder)

        guard contents.count < maxUploadSize else {
            Diag.error("Such a large upload is not supported. Please contact support. [fileSize: \(contents.count)]")
            completionQueue.addOperation {
                completion(.failure(.serverSideError(message: "Upload is too large")))
            }
            return
        }

        acquireTokenSilent(token: token, timeout: timeout, completionQueue: completionQueue) { authResult in
            switch authResult {
            case .success(let newToken):
                tokenUpdater?(newToken)
                self.createFile(
                    in: folder,
                    contents: contents,
                    fileName: fileName,
                    freshToken: newToken,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let error):
                completionQueue.addOperation {
                    completion(.failure(error))
                }
                return
            }
        }
    }
}
