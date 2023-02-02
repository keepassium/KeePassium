//  KeePassium Password Manager
//  Copyright © 2018–2023 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

protocol EntryChangeObserver: AnyObject {
    func entryDidChange(entry: Entry)
}

class EntryChangeNotifications {
    private static let entryChanged = Notification.Name("com.keepassium.EntryChanged")
    private static let userInfoEntryKey = "ChangedEntry"
    
    private weak var observer: EntryChangeObserver?
    
    init(observer: EntryChangeObserver) {
        self.observer = observer
    }
    
    func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(entryDidChange(_:)),
            name: EntryChangeNotifications.entryChanged,
            object: nil)
    }
    
    func stopObserving() {
        NotificationCenter.default.removeObserver(
            self,
            name: EntryChangeNotifications.entryChanged,
            object: nil)
    }

    @objc func entryDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let entry = userInfo[EntryChangeNotifications.userInfoEntryKey] as? Entry else { return }
        
        observer?.entryDidChange(entry: entry)
    }
    
    static func post(entryDidChange entry: Entry) {
        let userInfo = [EntryChangeNotifications.userInfoEntryKey: entry]
        NotificationCenter.default.post(
            name: EntryChangeNotifications.entryChanged,
            object: nil,
            userInfo: userInfo)
    }
}
