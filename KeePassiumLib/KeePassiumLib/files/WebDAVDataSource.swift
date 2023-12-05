//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class WebDAVDataSource: DataSource {
    func getAccessCoordinator() -> FileAccessCoordinator {
        return PassthroughFileAccessCoordinator()
    }

    public func readFileInfo(
        at url: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        timeout: Timeout,
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
            url: WebDAVFileURL.getNakedURL(from: url),
            credential: credential,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }

    public func read(
        _ url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
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
            url: WebDAVFileURL.getNakedURL(from: url),
            credential: credential,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }

    public func write(
        _ data: ByteArray,
        to url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
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
            url: WebDAVFileURL.getNakedURL(from: url),
            credential: credential,
            timeout: timeout,
            completionQueue: completionQueue,
            completion: completion
        )
    }
}
