//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class FileDataProvider {
    public static let defaultTimeout = URLReference.defaultTimeout
        
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
            byTime: .now() + FileDataProvider.defaultTimeout,
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
                    let fileAccessError = FileAccessError.systemError(error)
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
        at fileURL: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        byTime: DispatchTime = .now() + FileDataProvider.defaultTimeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<FileInfo>
    ) {
        let operationQueue = FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        
        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .readingIntent(with: fileURL, options: [.resolvesSymbolicLink, .withoutChanges]),
            fileProvider: fileProvider,
            byTime: byTime,
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
                    byTime: byTime,
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
        byTime: DispatchTime = .now() + FileDataProvider.defaultTimeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        fileRef.resolveAsync(byTime: byTime, callbackQueue: operationQueue) {
            assert(operationQueue.isCurrent)
            switch $0 {
            case .success(let prefixedFileURL):
                read(
                    prefixedFileURL,
                    fileProvider: fileRef.fileProvider,
                    queue: operationQueue,
                    byTime: byTime,
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
        byTime: DispatchTime = .now() + FileDataProvider.defaultTimeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .readingIntent(with: fileURL, options: [.forUploading]),
            fileProvider: fileProvider,
            byTime: byTime,
            queue: operationQueue,
            fileOperation: { (coordinatedURL) in
                assert(operationQueue.isCurrent)
                defer {
                    if isAccessed {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                dataSource.read(
                    coordinatedURL,
                    fileProvider: fileProvider,
                    byTime: byTime,
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
        byTime: DispatchTime = .now() + FileDataProvider.defaultTimeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<Void, FileAccessError>) -> Void
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        
        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateFileOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            intent: .writingIntent(with: fileURL, options: [.forMerging]),
            fileProvider: fileProvider,
            byTime: byTime,
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
                    byTime: byTime,
                    queue: operationQueue,
                    completionQueue: completionQueue,
                    completion: completion
                )
            },
            completionQueue: completionQueue,
            completion: completion
        )
    }
    
    public static func readThenWrite(
        to fileURL: URL,
        fileProvider: FileProvider?,
        queue: OperationQueue? = nil,
        outputDataSource: @escaping (_ url: URL, _ newData: ByteArray) throws -> ByteArray?,
        byTime: DispatchTime = .now() + FileDataProvider.defaultTimeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<Void, FileAccessError>) -> Void
    ) {
        let operationQueue = queue ?? FileDataProvider.backgroundQueue
        let completionQueue = completionQueue ?? FileDataProvider.backgroundQueue
        
        let isAccessed = fileURL.startAccessingSecurityScopedResource()
        let dataSource = DataSourceFactory.getDataSource(for: fileURL)
        coordinateReadThenWriteOperation(
            accessCoordinator: dataSource.getAccessCoordinator(),
            fileURL: fileURL,
            fileProvider: fileProvider,
            byTime: byTime,
            queue: operationQueue,
            fileOperation: { readURL, writeURL in
                assert(operationQueue.isCurrent)
                defer {
                    if isAccessed {
                        fileURL.stopAccessingSecurityScopedResource()
                    }
                }
                dataSource.readThenWrite(
                    from: readURL,
                    to: writeURL,
                    fileProvider: fileProvider,
                    outputDataSource: outputDataSource,
                    byTime: byTime,
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
        byTime: DispatchTime,
        queue: OperationQueue,
        fileOperation: @escaping (URL) -> Void,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<T>
    ) {
        var hasStartedCoordinating = false
        var hasTimedOut = false
        coordinatorSyncQueue.asyncAfter(deadline: byTime) {
            if hasStartedCoordinating {
                return
            }
            hasTimedOut = true
            accessCoordinator.cancel()
            completionQueue.addOperation {
                completion(.failure(.timeout(fileProvider: fileProvider)))
            }
        }
        
        accessCoordinator.coordinate(with: [intent], queue: queue) {
            (coordinatorError) in
            assert(queue.isCurrent)
            let canContinue = coordinatorSyncQueue.sync(execute: { () -> Bool in
                if hasTimedOut {
                    return false
                }
                hasStartedCoordinating = true
                return true
            })
            guard canContinue else { 
                return
            }
            
            if let coordinatorError = coordinatorError {
                completionQueue.addOperation {
                    completion(.failure(.systemError(coordinatorError)))
                }
                return
            }
            
            fileOperation(intent.url)
        }
    }
    
    private static func coordinateReadThenWriteOperation<T>(
        accessCoordinator: FileAccessCoordinator,
        fileURL: URL,
        fileProvider: FileProvider?,
        byTime: DispatchTime,
        queue: OperationQueue,
        fileOperation: @escaping (URL, URL) -> Void,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<T>
    ) {
        var hasStartedCoordinating = false
        var hasTimedOut = false
        coordinatorSyncQueue.asyncAfter(deadline: byTime) {
            if hasStartedCoordinating {
                return
            }
            hasTimedOut = true
            accessCoordinator.cancel()
            completionQueue.addOperation {
                completion(.failure(.timeout(fileProvider: fileProvider)))
            }
        }
        
        let readingIntent = NSFileAccessIntent.readingIntent(with: fileURL, options: [])
        let writingIntent = NSFileAccessIntent.writingIntent(with: fileURL, options: [.forMerging])
        accessCoordinator.coordinate(with: [readingIntent, writingIntent], queue: queue) {
            (coordinatorError) in
            assert(queue.isCurrent)
            let canContinue = coordinatorSyncQueue.sync(execute: { () -> Bool in
                if hasTimedOut {
                    return false 
                }
                hasStartedCoordinating = true
                return true
            })
            guard canContinue else { 
                return
            }
            
            if let coordinatorError = coordinatorError {
                completionQueue.addOperation {
                    completion(.failure(.systemError(coordinatorError)))
                }
                return
            }
            
            fileOperation(readingIntent.url, writingIntent.url)
        }
    }
}
