//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class QuickAutoFillPrompt {
    private enum Keys {
        static let root = "com.keepassium.quickAutoFillPrompt"
        static let lastSeenDate = root + ".lastSeenDate"
        static let dismissDate = root + ".dismissDate"
    }
    
    static var shouldShow: Bool {
        if dismissDate != nil {
            return false
        }
        let timeSinceSeen = -(lastSeenDate ?? .distantPast).timeIntervalSinceNow
        return timeSinceSeen > .week
    }
    
    static var lastSeenDate: Date? {
        get {
            guard let timestamp =
                    UserDefaults.appGroupShared.object(forKey: Keys.lastSeenDate) as? Double
            else {
                return nil
            }
            return Date(timeIntervalSinceReferenceDate: timestamp)
        }
        set {
            if let timestamp = newValue?.timeIntervalSinceReferenceDate as Double? {
                UserDefaults.appGroupShared.set(timestamp, forKey: Keys.lastSeenDate)
            } else {
                UserDefaults.appGroupShared.removeObject(forKey: Keys.lastSeenDate)
            }
        }
    }
    
    static var dismissDate: Date? {
        get {
            guard let timestamp =
                    UserDefaults.appGroupShared.object(forKey: Keys.dismissDate) as? Double
            else {
                return nil
            }
            return Date(timeIntervalSinceReferenceDate: timestamp)
        }
        set {
            if let timestamp = newValue?.timeIntervalSinceReferenceDate as Double? {
                UserDefaults.appGroupShared.set(timestamp, forKey: Keys.dismissDate)
            } else {
                UserDefaults.appGroupShared.removeObject(forKey: Keys.dismissDate)
            }
        }
    }

}
