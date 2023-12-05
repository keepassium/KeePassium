//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class OneDriveDataSource: DataSource {
    private struct AuthorizedItem {
        var item: OneDriveItemReference
        var token: OAuthToken
    }

    func getAccessCoordinator() -> FileAccessCoordinator {
        return PassthroughFileAccessCoordinator()
    }

    private func checkAccessAndCredentials<ReturnType>(
        url: URL,
        operation: String,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ReturnType>
    ) -> AuthorizedItem? {
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied [operation: \(operation)]")
            completionQueue.addOperation {
                completion(.failure(.networkAccessDenied))
            }
            return nil
        }
        guard let credential = CredentialManager.shared.get(for: url) else {
            Diag.warning("Did not find OneDrive access credentials [operation: \(operation)]")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return nil
        }
        guard let token = credential.oauthToken else {
            Diag.warning("OneDrive OAuth token missing [operation: \(operation)]")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return nil
        }

        guard let itemReference = OneDriveItemReference.fromURL(url) else {
            Diag.error("Failed to restore OneDrive item reference")
            completionQueue.addOperation {
                completion(.failure(.internalError))
            }
            return nil
        }
        return AuthorizedItem(item: itemReference, token: token)
    }

    private func saveUpdatedToken(_ newToken: OAuthToken, prefixedURL url: URL) {
        let newCredential = NetworkCredential(oauthToken: newToken)
        CredentialManager.shared.store(credential: newCredential, for: url)
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
        assert(fileProvider == .keepassiumOneDrive)
        guard let authorizedItem = checkAccessAndCredentials(
            url: url,
            operation: "readFileInfo",
            completionQueue: completionQueue,
            completion: completion
        ) else {
            return 
        }

        OneDriveManager.shared.getItemInfo(
            authorizedItem.item,
            token: authorizedItem.token,
            tokenUpdater: { self.saveUpdatedToken($0, prefixedURL: url) },
            completionQueue: completionQueue,
            completion: { result in
                assert(completionQueue.isCurrent)
                switch result {
                case .success(let remoteFileItem):
                    assert(remoteFileItem.fileInfo != nil, "File info must be defined for remote items")
                    let fileInfoOrDummy = remoteFileItem.fileInfo ??
                        FileInfo(fileName: remoteFileItem.name, isInTrash: false)
                    completion(.success(fileInfoOrDummy))
                case .failure(let oneDriveError):
                    switch oneDriveError {
                    case .authorizationRequired:
                        let message = oneDriveError.localizedDescription
                        completion(.failure(.authorizationRequired(
                            message: message,
                            recoveryAction: LString.actionSignInToOneDrive
                        )))
                    default:
                        completion(.failure(.systemError(oneDriveError)))
                    }
                }
            }
        )
    }

    func read(
        _ url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        assert(fileProvider == .keepassiumOneDrive)
        guard let authorizedItem = checkAccessAndCredentials(
            url: url,
            operation: "read",
            completionQueue: completionQueue,
            completion: completion
        ) else {
            return 
        }

        OneDriveManager.shared.getFileContents(
            authorizedItem.item,
            token: authorizedItem.token,
            tokenUpdater: { self.saveUpdatedToken($0, prefixedURL: url) },
            completionQueue: completionQueue,
            completion: { result in
                assert(completionQueue.isCurrent)
                switch result {
                case .success(let fileContents):
                    completion(.success(ByteArray(data: fileContents)))
                case .failure(let oneDriveError):
                    completion(.failure(.systemError(oneDriveError)))
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
        assert(fileProvider == .keepassiumOneDrive)
        guard let authorizedItem = checkAccessAndCredentials(
            url: url,
            operation: "write",
            completionQueue: completionQueue,
            completion: completion
        ) else {
            return 
        }
        OneDriveManager.shared.uploadFile(
            authorizedItem.item,
            contents: data,
            fileName: url.lastPathComponent,
            token: authorizedItem.token,
            tokenUpdater: { self.saveUpdatedToken($0, prefixedURL: url) },
            completionQueue: completionQueue,
            completion: { result in
                assert(completionQueue.isCurrent)
                switch result {
                case .success(let finalName):
                    assert(url.lastPathComponent == finalName, "File name changed on upload; investigate this")
                    completion(.success)
                case .failure(let oneDriveError):
                    completion(.failure(.systemError(oneDriveError)))
                }
            }
        )
    }
}
