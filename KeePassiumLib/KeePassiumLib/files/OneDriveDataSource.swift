//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
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
                    completion(.failure(.systemError(oneDriveError)))
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
    
    func readThenWrite(
        from readURL: URL,
        to writeURL: URL,
        fileProvider: FileProvider?,
        outputDataSource: @escaping (URL, ByteArray) throws -> ByteArray?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    ) {
        assert(fileProvider == .keepassiumOneDrive)
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied")
            completionQueue.addOperation {
                completion(.failure(.networkAccessDenied))
            }
            return
        }
        
        let operationQueue = queue
        read(
            readURL, 
            fileProvider: fileProvider,
            timeout: timeout,
            queue: operationQueue,
            completionQueue: operationQueue, 
            completion: { [self] result in 
                assert(operationQueue.isCurrent, "Should be still in the operation queue")
                
                switch result {
                case .success(let remoteData):
                    do {
                        guard let dataToWrite = try outputDataSource(readURL, remoteData) 
                        else {
                            completionQueue.addOperation {
                                completion(.success)
                            }
                            return
                        }
                        write(
                            dataToWrite,
                            to: writeURL, 
                            fileProvider: fileProvider,
                            timeout: Timeout(duration: timeout.duration),
                            queue: operationQueue,
                            completionQueue: completionQueue,
                            completion: completion
                        )
                    } catch let fileAccessError as FileAccessError {
                        Diag.error("Failed to write file [message: \(fileAccessError.localizedDescription)")
                        completionQueue.addOperation {
                            completion(.failure(fileAccessError))
                        }
                    } catch {
                        Diag.error("Failed to write file [message: \(error.localizedDescription)")
                        let fileAccessError = FileAccessError.systemError(error)
                        completionQueue.addOperation {
                            completion(.failure(fileAccessError))
                        }
                    }
                case .failure(let fileAccessError):
                    Diag.error("Failed to read file [message: \(fileAccessError.localizedDescription)")
                    completionQueue.addOperation {
                        completion(.failure(fileAccessError))
                    }
                }
            }
        )
    }
}
