//
//  Observable.swift
//  KeePassiumLib
//
//  Created by Andrei Popleteev on 2019-10-12.
//  Copyright © 2019 Andrei Popleteev. All rights reserved.
//

public protocol Observer: class {
}

public struct Subscriber {
    weak var observer: Observer?
}

public protocol Observable: class {
    var subscribers: [ObjectIdentifier: Subscriber] { get set }
}

public extension Observable {
    func addObserver(_ observer: Observer) {
        objc_sync_enter(subscribers)
        defer { objc_sync_exit(subscribers) }

        let id = ObjectIdentifier(observer)
        subscribers[id] = Subscriber(observer: observer)
    }

    func removeObserver(_ observer: Observer) {
        objc_sync_enter(subscribers)
        defer { objc_sync_exit(subscribers) }
        
        let id = ObjectIdentifier(observer)
        subscribers.removeValue(forKey: id)
    }

}
