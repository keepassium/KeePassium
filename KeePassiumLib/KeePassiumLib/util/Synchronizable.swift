//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol Synchronizable: class {
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
        withTimeout timeout: TimeInterval,
        on queue: DispatchQueue,
        slowSyncOperation: @escaping ()->(SlowResultType),
        onSuccess: @escaping (SlowResultType)->(),
        onTimeout: @escaping ()->())
    {
        assert(timeout >= TimeInterval.zero)
        queue.async { [self] in 
            let semaphore = DispatchSemaphore(value: 0)
            let slowBlockQueue = DispatchQueue.init(label: "", qos: queue.qos, attributes: []) 
            
            var result: SlowResultType?
            var isCancelled = false
            var isFinished = false
            slowBlockQueue.async { [weak self] in
                result = slowSyncOperation()
                
                guard let self = self else { return }
                defer { semaphore.signal() }
                self.synchronized {
                    if !isCancelled {
                        isFinished = true
                    }
                }
            }
            
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                self.synchronized {
                    if !isFinished {
                        isCancelled = true
                    }
                }
            }
            
            if isFinished {
                onSuccess(result!)
            } else {
                onTimeout()
            }
        }
    }
}
