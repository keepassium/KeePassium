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
    
    public func open(_ completion: @escaping OpenCallback) {
        self.open(withTimeout: BaseDocument.timeout, completion: completion)
    }
    
    public func open(
        withTimeout timeout: TimeInterval = BaseDocument.timeout,
        queue: OperationQueue? = nil,
        completionQueue: OperationQueue? = nil,
        completion: @escaping OpenCallback)
    {
        let operationQueue = queue ?? BaseDocument.backgroundQueue
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        operationQueue.addOperation {
            let semaphore = DispatchSemaphore(value: 0)
            
            var hasTimedOut = false
            super.open { [self] (success) in
                semaphore.signal()
                if hasTimedOut {
                    self.close(completionQueue: completionQueue, completion: nil)
                }
            }
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                hasTimedOut = true
                completionQueue.addOperation {
                    completion(.failure(.timeout(fileProvider: self.fileProvider)))
                }
                return
            }
            
            if let error = self.error {
                completionQueue.addOperation {
                    completion(.failure(error))
                }
            } else {
                completionQueue.addOperation {
                    completion(.success(self.data))
                }
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
    
    public func save(
        completionQueue: OperationQueue? = nil,
        completion: @escaping((Result<Void, FileAccessError>) -> Void)
    ) {
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        super.save(to: fileURL, for: .forOverwriting, completionHandler: {
            [self] (success) in 
            if success {
                self.error = nil
                completionQueue.addOperation {
                    completion(.success)
                }
            } else {
                if let error = self.error {
                    completionQueue.addOperation {
                        completion(.failure(error))
                    }
                } else {
                    Diag.error("Saving unsuccessful, but without error info.")
                    completionQueue.addOperation {
                        completion(.failure(.internalError))
                    }
                }
            }
        })
    }
    
    public func close(
        completionQueue: OperationQueue? = nil,
        completion: ((Result<Void, FileAccessError>) -> Void)?
    ) {
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        super.close(completionHandler: {
            [self] (success) in
            if success {
                self.error = nil
                completionQueue.addOperation {
                    completion?(.success)
                }
                Diag.info("Document closed OK")
            } else {
                if let error = self.error {
                    completionQueue.addOperation {
                        completion?(.failure(error))
                    }
                } else {
                    Diag.error("Closing unsuccessful, but without error info.")
                    completionQueue.addOperation {
                        completion?(.failure(.internalError))
                    }
                }
            }
        })
    }
    
    public func saveAndClose(
        completionQueue: OperationQueue? = nil,
        completion: @escaping ((Result<Void, FileAccessError>) -> Void)
    ) {
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        save(completionQueue: completionQueue) { [self] result in
            assert(completionQueue.isCurrent)
            switch result {
            case .success:
                self.close(completionQueue: completionQueue, completion: completion)
            case .failure(let fileAccessError):
                completionQueue.addOperation {
                    completion(.failure(fileAccessError))
                }
            }
        }
    }
    
    override public func handleError(_ error: Error, userInteractionPermitted: Bool) {
        self.error = FileAccessError.make(from: error, fileProvider: fileProvider)
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
    }
}


extension BaseDocument {

    public static func read(
        _ fileRef: URLReference,
        timeout: TimeInterval = BaseDocument.timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping OpenCallback
    ) {
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        fileRef.resolveAsync(timeout: timeout) { result in
            switch result {
            case .success(let fileURL):
                let baseDocument = BaseDocument(fileURL: fileURL, fileProvider: fileRef.fileProvider)
                baseDocument.open(withTimeout: timeout, completionQueue: completionQueue) {
                    (result) in
                    assert(completionQueue.isCurrent)
                    baseDocument.close(completionHandler: nil)
                    completion(result)
                }
            case .failure(let fileAccessError):
                Diag.error("Failed to open document [message: \(fileAccessError.localizedDescription)]")
                completionQueue.addOperation {
                    completion(.failure(fileAccessError))
                }
            }
        }
    }

    public static func read(
        _ url: URL,
        queue: OperationQueue? = nil,
        timeout: TimeInterval = BaseDocument.timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping OpenCallback
    ) {
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        let baseDocument = BaseDocument(fileURL: url, fileProvider: nil)
        baseDocument.open(withTimeout: timeout, queue: queue, completionQueue: completionQueue){
            (result) in
            assert(completionQueue.isCurrent)
            baseDocument.close(completionQueue: nil, completion: nil)
            completionQueue.addOperation {
                completion(result)
            }
        }
    }
    
    public static func write(
        _ data: ByteArray,
        to url: URL,
        timeout: TimeInterval = BaseDocument.timeout,
        completionQueue: OperationQueue? = nil,
        completion: @escaping (Result<Void, FileAccessError>) -> Void
   ) {
        let completionQueue = completionQueue ?? BaseDocument.backgroundQueue
        let document = BaseDocument(fileURL: url)
        document.open(withTimeout: timeout, completionQueue: completionQueue) { result in
            assert(completionQueue.isCurrent)
            switch result {
            case .success(_): 
                document.data = data
                document.saveAndClose(completionQueue: completionQueue, completion: completion)
            case .failure(let fileAccessError):
                Diag.error("Failed to open document [message: \(fileAccessError.localizedDescription)]")
                completion(.failure(fileAccessError))
            }
        }
   }
}
