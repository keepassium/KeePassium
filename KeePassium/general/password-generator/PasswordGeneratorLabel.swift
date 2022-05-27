//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class PasswordGeneratorLabel: UILabel {
    
    var accessibilityIsPhrase = false
    
    override var text: String? {
        get {
            super.text
        }
        set {
            super.text = newValue
            updateAccessibility()
        }
    }
    
    private func updateAccessibility() {
        accessibilityLabel = LString.PasswordGenerator.titleGeneratedText
        accessibilityHint = LString.A11y.hintActivateToListen
        accessibilityValue = nil
    }
    
    override func accessibilityActivate() -> Bool {
        guard let text = text else {
            return false
        }
        if accessibilityIsPhrase {
            accessibilityValue = text
        } else {
            accessibilityLanguage = nil
            let attributedText = NSAttributedString(
                string: text,
                attributes: [.accessibilitySpeechSpellOut: true]
            )
            accessibilityAttributedValue = attributedText
        }
        UIAccessibility.post(notification: .layoutChanged, argument: self)
        return true
    }
    
    override func accessibilityElementDidLoseFocus() {
        accessibilityValue = nil
    }
}
