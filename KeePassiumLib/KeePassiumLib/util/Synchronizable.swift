//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol Synchronizable: AnyObject {
    func synchronized<T>(_ handler: ()->(T)) -> T
}

public extension Synchronizable {
    func synchronized<T>(_ handler: ()->(T)) -> T  {
        objc_sync_enter(self)
        defer { objc_sync_exit(self)}
        return handler()
    }
    
    func dispatchMain(_ handler: @escaping ()->()) {
        if Thread.isMainThread {
            handler()
        } else {
            DispatchQueue.main.async(execute: handler)
        }
    }
    
    func execute<SlowResultType>(
        byTime: DispatchTime,
        on queue: DispatchQueue,
        slowSyncOperation: @escaping ()->(SlowResultType),
        onSuccess: @escaping (SlowResultType)->(),
        onTimeout: @escaping ()->())
    {
        queue.async { 
            let semaphore = DispatchSemaphore(value: 0)
            let slowBlockQueue = DispatchQueue.init(label: "", qos: queue.qos, attributes: []) 
            
            var result: SlowResultType?
            slowBlockQueue.async {
                result = slowSyncOperation()
                semaphore.signal()
            }
            
            if semaphore.wait(timeout: byTime) == .timedOut {
                onTimeout()
            } else {
                onSuccess(result!)
            }
        }
    }
}
