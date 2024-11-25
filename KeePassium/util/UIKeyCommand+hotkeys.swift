//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

struct Hotkey {
    fileprivate let input: String
    fileprivate let modifiers: UIKeyModifierFlags

    static let appPreferences = Self(input: ",", modifiers: [.command])
    static let refreshList    = Self(input: "r", modifiers: [.command])
    static let search         = Self(input: "f", modifiers: [.command])

    static let createDatabase     = Self(input: "n", modifiers: [.command, .shift])
    static let openDatabase       = Self(input: "o", modifiers: [.command])
    static let connectToServer    = Self(input: "o", modifiers: [.command, .shift])
    static let lockDatabase       = Self(input: "l", modifiers: [.command])
    static let reloadDatabase     = Self(input: "r", modifiers: [.command])
    static let printDatabase      = Self(input: "p", modifiers: [.command])
    static let encryptionSettings = Self(input: ",", modifiers: [.command, .shift])

    static let passwordGenerator = Self(input: "/", modifiers: [.command])
    static let passwordAudit     = Self(input: "a", modifiers: [.command, .shift])

    static let createEntry       = Self(input: "n", modifiers: [.command])
    static let createGroup       = Self(input: "n", modifiers: [.command, .control])

    static let copyUserName = Self(input: "B", modifiers: [.command])
    static let copyPassword = Self(input: "C", modifiers: [.command])
    static let copyURL      = Self(input: "U", modifiers: [.command])
}

extension UIKeyCommand {
    convenience init(
        action: Selector,
        hotkey: Hotkey,
        discoverabilityTitle: String? = nil
    ) {
        self.init(
            action: action,
            input: hotkey.input,
            modifierFlags: hotkey.modifiers,
            discoverabilityTitle: discoverabilityTitle
        )
    }
    convenience init(
        title: String,
        action: Selector,
        hotkey: Hotkey,
        discoverabilityTitle: String? = nil
    ) {
        self.init(
            title: title,
            action: action,
            input: hotkey.input,
            modifierFlags: hotkey.modifiers,
            discoverabilityTitle: discoverabilityTitle
        )
    }
}
