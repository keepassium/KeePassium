//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public class BaseDocument: UIDocument, Synchronizable {
    public static let timeout = URLReference.defaultTimeout
    
    public typealias OpenCallback = (Result<ByteArray, FileAccessError>) -> Void
    
    public internal(set) var data = ByteArray()
    public internal(set) var error: FileAccessError?
    public var errorMessage: String? { error?.localizedDescription }
    public var hasError: Bool { return error != nil }
    public internal(set) var fileProvider: FileProvider?
    
    fileprivate static let backgroundQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.keepassium.Document"
        queue.qualityOfService = .background
        queue.maxConcurrentOperationCount = 8
        return queue
    }()
    
    public convenience init(fileURL url: URL, fileProvider: FileProvider?) {
        self.init(fileURL: url)
        self.fileProvider = fileProvider
    }
    private override init(fileURL url: URL) {
        super.init(fileURL: url)
    }
    
    public func open(_ callback: @escaping OpenCallback) {
        self.open(withTimeout: BaseDocument.timeout, callback)
    }
    
    public func open(
        withTimeout timeout: TimeInterval = BaseDocument.timeout,
        queue: OperationQueue? = nil,
        _ callback: @escaping OpenCallback)
    {
        let operationQueue = queue ?? BaseDocument.backgroundQueue
        operationQueue.addOperation {
            let semaphore = DispatchSemaphore(value: 0)
            
            var hasTimedOut = false
            super.open { [self] (success) in
                semaphore.signal()
                if hasTimedOut {
                    self.close(completionHandler: nil)
                }
            }
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                hasTimedOut = true
                callback(.failure(.timeout(fileProvider: self.fileProvider)))
                return
            }
            
            if let error = self.error {
                callback(.failure(error))
            } else {
                callback(.success(self.data))
            }
        }
    }
    
    override public func contents(forType typeName: String) throws -> Any {
        error = nil
        return data.asData
    }
    
    override public func load(fromContents contents: Any, ofType typeName: String?) throws {
        assert(contents is Data)
        error = nil
        if let contents = contents as? Data {
            data = ByteArray(data: contents)
        } else {
            data = ByteArray()
        }
    }
    
    public func save(_ completion: @escaping((Result<Void, FileAccessError>) -> Void)) {
        super.save(to: fileURL, for: .forOverwriting, completionHandler: {
            [weak self] (success) in 
            guard let self = self else { return }
            if success {
                self.error = nil
                completion(.success)
            } else {
                if let error = self.error {
                    completion(.failure(error))
                } else {
                    Diag.error("Saving unsuccessful, but without error info.")
                    completion(.failure(.internalError))
                }
            }
        })
    }
    
    public func close(_ completion: @escaping ((Result<Void, FileAccessError>) -> Void)) {
        super.close(completionHandler: {
            [weak self] (success) in
            guard let self = self else { return }
            if success {
                self.error = nil
                completion(.success)
            } else {
                if let error = self.error {
                    completion(.failure(error))
                } else {
                    Diag.error("Closing unsuccessful, but without error info.")
                    completion(.failure(.internalError))
                }
            }
        })
    }
    
    override public func handleError(_ error: Error, userInteractionPermitted: Bool) {
        self.error = FileAccessError.make(from: error, fileProvider: fileProvider)
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
    }
}
