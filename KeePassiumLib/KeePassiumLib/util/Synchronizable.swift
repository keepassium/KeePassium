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
        var result: SlowResultType?
        let workItem = DispatchWorkItem() {
            result = slowSyncOperation()
        }
        queue.async(execute: workItem)
        
        queue.async {
            switch workItem.wait(timeout: byTime) {
            case .success:
                onSuccess(result!)
            case .timedOut:
                workItem.cancel() 
                onTimeout()
            }
        }
    }
}
