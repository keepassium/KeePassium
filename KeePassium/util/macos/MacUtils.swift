//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

@objc(MacUtils)
protocol MacUtils: NSObjectProtocol {
    init()

    func disableSecureEventInput()

    func isSecureEventInputEnabled() -> Bool

    func isControlKeyPressed() -> Bool

    func isAccessibilityPermissionGranted() -> Bool

    func requestAccessibilityPermission()

    func openAccessibilityPermissionSettings()

    func hideApplication()

    func activate()

    func performAutoType(username: String, password: String, completion: @escaping (Bool) -> Void)
}
