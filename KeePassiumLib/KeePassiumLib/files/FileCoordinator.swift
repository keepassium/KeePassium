//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

class FileCoordinator: NSFileCoordinator, Synchronizable {
    fileprivate let backgroundQueue = DispatchQueue(
        label: "com.keepassium.FileCoordinator",
        qos: .default,
        attributes: [.concurrent])
    
    fileprivate static let operationQueue = OperationQueue()
    
    typealias ReadingCallback = (FileAccessError?) -> ()
    
    public func coordinateReading(
        at url: URL,
        fileProvider: FileProvider?,
        options: NSFileCoordinator.ReadingOptions,
        timeout: TimeInterval,
        callback: @escaping ReadingCallback)
    {
        execute(
            withTimeout: timeout,
            on: backgroundQueue,
            slowAsyncOperation: {
                [weak self] (_ notifyAndCheckIfCanProceed: @escaping ()->Bool) -> () in
                self?.coordinate(
                    with: [.readingIntent(with: url, options: options)],
                    queue: FileCoordinator.operationQueue)
                {
                    (error) in
                    guard notifyAndCheckIfCanProceed() else {
                        return
                    }
                    if let error = error {
                        callback(FileAccessError.make(from: error, fileProvider: fileProvider))
                    } else {
                        callback(nil)
                    }
                }
                
            }, onSuccess: {
            }, onTimeout: {
                callback(.timeout(fileProvider: fileProvider))
            }
        )
    }
}
