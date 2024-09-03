//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class FileDataProvider {
    public static let defaultTimeoutDuration = URLReference.defaultTimeoutDuration

    fileprivate static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "FileDataProvider"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 8
        return queue
    }()

    fileprivate static let coordinatorSyncQueue = DispatchQueue(
        label: "CoordinatorSyncQueue",
        qos: .utility,
        attributes: []
    )
}

extension FileDataProvider {

    internal static func bookmarkFile(
        at fileURL: URL,
        location: URLReference.Location,
        creationHandler: @escaping (URL, URLReference.Location) throws -> URLReference,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<URLReference>
    ) {
        let operationQueue = FileDataProvider.backgroundQueue
        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .readingIntent(with: fileURL, options: [.withoutChanges]),
            fileProvider: FileProvider.find(for: fileURL), 
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            queue: operationQueue,
            fileOperation: { url in
                assert(operationQueue.isCurrent)
                defer {
                    if isAccessed {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let fileRef = try creationHandler(url, location)
                    completionQueue.addOperation {
                        completion(.success(fileRef))
                    }
                } catch {
                    Diag.error("Failed to create file reference [message: \(error.localizedDescription)]")
                    let fileAccessError = FileAccessError.make(
                        from: error,
                        fileName: url.lastPathComponent,
                        fileProvider: FileProvider.find(for: url))
                    completionQueue.addOperation {
                        completion(.failure(fileAccessError))
                    }
                }
            },
            completionQueue: completionQueue,
            completion: completion
        )
    }

    public static func readFileInfo(
        _ fileRef: URLReference,
        canUseCache: Bool,
        timeout: Timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<FileInfo>
    ) {
        if canUseCache,
           let fileURL = fileRef.url
        {
            readFileInfo(
                at: fileURL,
                fileProvider: fileRef.fileProvider,
                canUseCache: true,
                timeout: timeout,
                completionQueue: completionQueue,
                completion: completion
            )
            return
        }

        let operationQueue = Self.backgroundQueue
        let completionQueue = completionQueue ?? Self.backgroundQueue
        fileRef.resolveAsync(timeout: timeout, callbackQueue: operationQueue) {
            assert(operationQueue.isCurrent)
            switch $0 {
            case .success(let prefixedFileURL):
                readFileInfo(
                    at: prefixedFileURL,
                    fileProvider: fileRef.fileProvider,
                    canUseCache: canUseCache,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let fileAccessError):
                Diag.error("Failed to resolve file reference [message: \(fileAccessError.localizedDescription)]")
                completionQueue.addOperation {
                    completion(.failure(fileAccessError))
                }
            }
        }
    }

    public static func readFileInfo(
        at fileURL: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        timeout: Timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<FileInfo>
    ) {
        let operationQueue = FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        guard fileProvider?.isAllowed ?? true else {
            completionQueue.addOperation { completion(.failure(.managedAccessDenied)) }
            return
        }

        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .readingIntent(with: fileURL, options: [.resolvesSymbolicLink, .withoutChanges]),
            fileProvider: fileProvider,
            timeout: timeout,
            queue: operationQueue,
            fileOperation: { coordinatedURL in
                assert(operationQueue.isCurrent)
                defer {
                    if isAccessed {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }

                dataSource.readFileInfo(
                    at: coordinatedURL,
                    fileProvider: fileProvider,
                    canUseCache: canUseCache,
                    timeout: timeout,
                    queue: operationQueue,
                    completionQueue: completionQueue,
                    completion: completion
                )
            },
            completionQueue: completionQueue,
            completion: completion
        )
    }

    public static func read(
        _ fileRef: URLReference,
        queue: OperationQueue? = nil,
        timeout: Timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        fileRef.resolveAsync(timeout: timeout, callbackQueue: operationQueue) {
            assert(operationQueue.isCurrent)
            switch $0 {
            case .success(let prefixedFileURL):
                read(
                    prefixedFileURL,
                    fileProvider: fileRef.fileProvider,
                    queue: operationQueue,
                    timeout: timeout,
                    completionQueue: completionQueue,
                    completion: completion
                )
            case .failure(let fileAccessError):
                Diag.error("Failed to resolve file reference [message: \(fileAccessError.localizedDescription)]")
                completionQueue.addOperation {
                    completion(.failure(fileAccessError))
                }
            }
        }
    }

    public static func read(
        _ fileURL: URL,
        fileProvider: FileProvider?,
        queue: OperationQueue? = nil,
        timeout: Timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        guard fileProvider?.isAllowed ?? true else {
            completionQueue.addOperation { completion(.failure(.managedAccessDenied)) }
            return
        }

        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .readingIntent(with: fileURL, options: [.forUploading]),
            fileProvider: fileProvider,
            timeout: timeout,
            queue: operationQueue,
            fileOperation: { coordinatedURL in
                assert(operationQueue.isCurrent)
                defer {
                    if isAccessed {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                dataSource.read(
                    coordinatedURL,
                    fileProvider: fileProvider,
                    timeout: timeout,
                    queue: operationQueue,
                    completionQueue: completionQueue,
                    completion: completion
                )
            },
            completionQueue: completionQueue,
            completion: completion
        )
    }

    public static func write(
        _ data: ByteArray,
        to fileURL: URL,
        fileProvider: FileProvider?,
        queue: OperationQueue? = nil,
        timeout: Timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<Void, FileAccessError>) -> Void
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        guard fileProvider?.isAllowed ?? true else {
            completionQueue.addOperation { completion(.failure(.managedAccessDenied)) }
            return
        }

        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .writingIntent(with: fileURL, options: [.forMerging]),
            fileProvider: fileProvider,
            timeout: timeout,
            queue: operationQueue,
            fileOperation: { coordintedURL in
                assert(operationQueue.isCurrent)
                defer {
                    if isAccessed {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                dataSource.write(
                    data,
                    to: coordintedURL,
                    fileProvider: fileProvider,
                    timeout: timeout,
                    queue: operationQueue,
                    completionQueue: completionQueue,
                    completion: completion
                )
            },
            completionQueue: completionQueue,
            completion: completion
        )
    }
}


extension FileDataProvider {
    private static func coordinateFileOperation<T>(
        accessCoordinator: FileAccessCoordinator,
        intent: NSFileAccessIntent,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        fileOperation: @escaping (URL) -> Void,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<T>
    ) {
        var hasStartedCoordinating = false
        var hasTimedOut = false
        coordinatorSyncQueue.asyncAfter(deadline: timeout.deadline) {
            if hasStartedCoordinating {
                return
            }
            hasTimedOut = true
            accessCoordinator.cancel()
            completionQueue.addOperation {
                Diag.error("File coordination timed out")
                completion(.failure(.timeout(fileProvider: fileProvider)))
            }
        }

        accessCoordinator.coordinate(with: [intent], queue: queue) { coordinatorError in
            assert(queue.isCurrent)
            let canContinue = coordinatorSyncQueue.sync(execute: { () -> Bool in
                if hasTimedOut {
                    return false
                }
                hasStartedCoordinating = true
                return true
            })
            guard canContinue else {
                Diag.debug("File coordination timed out")
                return
            }

            if let coordinatorError = coordinatorError {
                completionQueue.addOperation {
                    let nsError = coordinatorError as NSError
                    Diag.error("File coordination failed [message: \(nsError.debugDescription)]")
                    completion(.failure(.systemError(coordinatorError)))
                }
                return
            }

            Diag.verbose("Starting coordinated file access")
            fileOperation(intent.url)
            Diag.verbose("Coordinated file access finished")
        }
    }
}
