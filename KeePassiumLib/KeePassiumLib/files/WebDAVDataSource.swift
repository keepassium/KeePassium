//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class WebDAVDataSource: DataSource {
    static let defaultTimeout = URLReference.defaultTimeout
    
    public static var urlSchemePrefix: String? = "webdav"
    public static var urlSchemes = ["http", "https"]
    
    func getAccessCoordinator() -> FileAccessCoordinator {
        return PassthroughFileAccessCoordinator()
    }
    
    public func readFileInfo(
        at url: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        byTime: DispatchTime,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<FileInfo>
    ) {
        assert(fileProvider == .keepassiumWebDAV)
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied")
            completionQueue.addOperation {
                completion(.failure(.networkAccessDenied))
            }
            return
        }
        guard let credential = CredentialManager.shared.get(for: url) else {
            Diag.warning("Found no WebDAV credentials, skipping")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return
        }
        WebDAVManager.shared.getFileInfo(
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: FileDataProvider.defaultTimeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }
    
    
    public func read(
        _ url: URL,
        fileProvider: FileProvider?,
        byTime: DispatchTime,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        assert(fileProvider == .keepassiumWebDAV)
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied")
            completionQueue.addOperation {
                completion(.failure(.networkAccessDenied))
            }
            return
        }
        guard let credential = CredentialManager.shared.get(for: url) else {
            Diag.warning("Found no WebDAV credentials, skipping")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return
        }
        WebDAVManager.shared.downloadFile(
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: FileDataProvider.defaultTimeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }
    
    public func write(
        _ data: ByteArray,
        to url: URL,
        fileProvider: FileProvider?,
        byTime: DispatchTime,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    ) {
        assert(fileProvider == .keepassiumWebDAV)
        guard Settings.current.isNetworkAccessAllowed else {
            Diag.error("Network access denied")
            completionQueue.addOperation {
                completion(.failure(.networkAccessDenied))
            }
            return
        }
        guard let credential = CredentialManager.shared.get(for: url) else {
            Diag.warning("Found no WebDAV credentials, skipping")
            completionQueue.addOperation {
                completion(.failure(.noInfoAvailable))
            }
            return
        }
        WebDAVManager.shared.uploadFile(
            data: data,
            url: url.withoutSchemePrefix(),
            credential: credential,
            timeout: FileDataProvider.defaultTimeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }
    
    public func readThenWrite(
        from readURL: URL,
        to writeURL: URL,
        fileProvider: FileProvider?,
        outputDataSource: @escaping (_ url: URL, _ oldData: ByteArray) throws -> ByteArray?,
        byTime: DispatchTime,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    ) {
        assert(fileProvider == .keepassiumWebDAV)
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
            byTime: byTime,
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
                            byTime: .now() + WebDAVDataSource.defaultTimeout,
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
