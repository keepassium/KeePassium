//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final public class LocalNotifications: NSObject {
    private static let totpCopiedNotificationID = "totp-copied"

    public static func requestPermission(_ success: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, error in
            if granted {
                Diag.debug("Local notifications allowed")
                success()
            } else {
                Diag.debug("Local notifications not permitted")
            }
        }
    }

    public static func showTOTPNotification(title: String, body: String) {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1e-6, repeats: false)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: totpCopiedNotificationID,
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UNUserNotificationCenter.current().removeDeliveredNotifications(
                withIdentifiers: [totpCopiedNotificationID]
            )
        }
    }
}

extension LocalNotifications: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}
