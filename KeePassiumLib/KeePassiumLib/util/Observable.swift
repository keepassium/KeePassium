//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public protocol Observer: AnyObject {
}

public struct Subscriber {
    weak var observer: Observer?
}

public protocol Observable: AnyObject {
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
