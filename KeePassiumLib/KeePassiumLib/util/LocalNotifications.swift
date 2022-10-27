//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final public class LocalNotifications {
    
    public static func requestPermission(_ success: @escaping ()->Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) {
            (granted, error) in
            if granted {
                Diag.debug("Local notifications allowed")
                success()
            } else {
                Diag.debug("Local notifications not permitted")
            }
        }
    }
    
    public static func showTOTPNotification(title: String, body: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil
        
        let request = UNNotificationRequest(
            identifier: "totp-copied",
            content: content,
            trigger: trigger
        )
        
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        center.add(request) { error in
            if let error = error {
                Diag.warning("Failed to add local notification [message: \(error.localizedDescription)]")
            }
        }
    }
}
