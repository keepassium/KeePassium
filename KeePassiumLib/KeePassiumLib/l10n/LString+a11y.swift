//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public extension LString {
    enum A11y {
        public static let hintActivateToListen = NSLocalizedString(
            "[Accessibility/activateToListen]",
            bundle: Bundle.framework,
            value: "Activate to listen.",
            comment: "Call to action: perform accessibilty `activate` action to listen to text/content.")
        public static let containsPasskey = NSLocalizedString(
            "[Accessibility/containsPasskey]",
            bundle: Bundle.framework,
            value: "Contains a passkey.",
            comment: "Accessibility notification for entries with a passkey")
    }
}
