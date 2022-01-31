//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

protocol GroupChangeObserver: AnyObject {
    func groupDidChange(group: Group)
}

class GroupChangeNotifications {
    private static let groupChanged = Notification.Name("com.keepassium.GroupChanged")
    private static let userInfoGroupKey = "ChangedGroup"

    private weak var observer: GroupChangeObserver?
    
    init(observer: GroupChangeObserver) {
        self.observer = observer
    }
    
    func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(groupDidChange),
            name: GroupChangeNotifications.groupChanged,
            object: nil)
    }
    
    func stopObserving() {
        NotificationCenter.default.removeObserver(
            self,
            name: GroupChangeNotifications.groupChanged,
            object: nil)
    }
    
    @objc private func groupDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let group = userInfo[GroupChangeNotifications.userInfoGroupKey] as? Group else { return }
        observer?.groupDidChange(group: group)
    }

    static func post(groupDidChange group: Group) {
        NotificationCenter.default.post(
            name: GroupChangeNotifications.groupChanged,
            object: nil,
            userInfo: [
                GroupChangeNotifications.userInfoGroupKey: group
            ]
        )
    }
}
