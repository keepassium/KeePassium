//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension LString {
    public static let actionSwitchToAlphanumericKeyboard = NSLocalizedString(
        "[AppLock/Passcode/KeyboardType/switchAction] 123→ABC",
        bundle: Bundle.framework,
        value: "123→ABC",
        comment: "Action: change keyboard type to enter alphanumeric passphrases")
    public static let actionSwitchToDigitalKeyboard = NSLocalizedString(
        "[AppLock/Passcode/KeyboardType/switchAction] ABC→123",
        bundle: Bundle.framework,
        value: "ABC→123",
        comment: "Action: change keyboard type to enter PIN numbers")
    public static let hintPressEscForTouchID = NSLocalizedString(
        "[AppLock/Passcode/pressEscForTouchID]",
        bundle: Bundle.framework,
        value: "Press Esc for Touch ID",
        comment: "Hint/call to action about keyboard shortcut")
    public static let orgRequiresStrongerPasscode = NSLocalizedString(
        "[AppLock/Passcode/orgRequiresStonger]",
        bundle: Bundle.framework,
        value: "Your organization requires a more complex passcode.",
        comment: "Notification for business users when they set up too weak app protection passcode.")
}
