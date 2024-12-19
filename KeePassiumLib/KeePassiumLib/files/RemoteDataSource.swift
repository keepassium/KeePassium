//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

struct AuthorizedItem<ItemType> {
    var item: ItemType
    var token: OAuthToken
}

protocol RemoteDataSource: DataSource {
    associatedtype ItemType: SerializableRemoteFileItem
    associatedtype Manager: RemoteDataSourceManager<ItemType>

    var manager: Manager { get }
    var usedFileProvider: FileProvider { get }
    var recoveryAction: String { get }

    func getAccessCoordinator() -> FileAccessCoordinator
    func read(
        _ url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ByteArray>
    )
    func write(
        _ data: ByteArray,
        to url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    )
    func readFileInfo(
        at url: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<FileInfo>
    )
}

extension RemoteDataSource {
    func getAccessCoordinator() -> FileAccessCoordinator {
        return PassthroughFileAccessCoordinator()
    }

    func saveUpdatedToken(_ newToken: OAuthToken, prefixedURL url: URL) {
        let newCredential = NetworkCredential(oauthToken: newToken)
        CredentialManager.shared.store(credential: newCredential, for: url)
    }

    func checkAccessAndCredentials<ReturnType>(
        url: URL,
        operation: String,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ReturnType>
    ) -> AuthorizedItem<ItemType>? {
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied [operation: \(operation)]")
            completionQueue.addOperation {
                completion(.failure(.networkAccessDenied))
            }
            return nil
        }
        guard let credential = CredentialManager.shared.get(for: url) else {
            Diag.warning("Did not find \(usedFileProvider.localizedName) access credentials [operation: \(operation)]")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return nil
        }
        guard let token = credential.oauthToken else {
            Diag.warning("\(usedFileProvider.localizedName) OAuth token missing [operation: \(operation)]")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return nil
        }

        guard let item = ItemType.fromURL(url) else {
            Diag.error("Failed to restore \(usedFileProvider.localizedName) item reference")
            completionQueue.addOperation {
                completion(.failure(.internalError))
            }
            return nil
        }
        return AuthorizedItem(item: item, token: token)
    }

    func read(
        _ url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        assert(fileProvider == usedFileProvider)
        guard let authorizedItem = checkAccessAndCredentials(
            url: url,
            operation: "read",
            completionQueue: completionQueue,
            completion: completion
        ) else {
            return
        }

        manager.getFileContents(
            authorizedItem.item,
            token: authorizedItem.token,
            tokenUpdater: { self.saveUpdatedToken($0, prefixedURL: url) },
            timeout: timeout,
            completionQueue: completionQueue,
            completion: { result in
                assert(completionQueue.isCurrent)
                switch result {
                case .success(let fileContents):
                    completion(.success(ByteArray(data: fileContents)))
                case .failure(let error):
                    completion(.failure(.systemError(error)))
                }
            }
        )
    }

    func write(
        _ data: ByteArray,
        to url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    ) {
        assert(fileProvider == usedFileProvider)
        guard let authorizedItem = checkAccessAndCredentials(
            url: url,
            operation: "write",
            completionQueue: completionQueue,
            completion: completion
        ) else {
            return
        }

        manager.updateFile(
            authorizedItem.item,
            contents: data,
            token: authorizedItem.token,
            tokenUpdater: { self.saveUpdatedToken($0, prefixedURL: url) },
            timeout: timeout,
            completionQueue: completionQueue,
            completion: { result in
                assert(completionQueue.isCurrent)
                switch result {
                case .success:
                    completion(.success)
                case .failure(let error):
                    completion(.failure(.systemError(error)))
                }
            }
        )
    }

    func readFileInfo(
        at url: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<FileInfo>
    ) {
        assert(fileProvider == usedFileProvider)
        guard let authorizedItem = checkAccessAndCredentials(
            url: url,
            operation: "readFileInfo",
            completionQueue: completionQueue,
            completion: completion
        ) else {
            return
        }

        let recoveryAction = self.recoveryAction
        manager.getItemInfo(
            authorizedItem.item,
            token: authorizedItem.token,
            tokenUpdater: { self.saveUpdatedToken($0, prefixedURL: url) },
            timeout: timeout,
            completionQueue: completionQueue,
            completion: { result in
                assert(completionQueue.isCurrent)
                switch result {
                case .success(let remoteFileItem):
                    assert(remoteFileItem.fileInfo != nil, "File info must be defined for remote items")
                    let fileInfoOrDummy = remoteFileItem.fileInfo ??
                        FileInfo(fileName: remoteFileItem.name, isInTrash: false, hash: nil)
                    completion(.success(fileInfoOrDummy))
                case .failure(let error):
                    switch error {
                    case .authorizationRequired:
                        let message = error.localizedDescription
                        completion(.failure(.authorizationRequired(
                            message: message,
                            recoveryAction: recoveryAction
                        )))
                    default:
                        completion(.failure(.systemError(error)))
                    }
                }
            }
        )
    }
}
