//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

typealias TextInputView = UITextInput & UIView

protocol TextInputEditMenuDelegate {
    func textInputDidRequestRandomizer(_ textInput: TextInputView)
}

extension UITextField {
    internal func addRandomizerEditMenu() {
        assert(delegate is TextInputEditMenuDelegate, "Field delegate does not handle randomizer menu")
        let randomizerMenu = UIMenuItem(
            title: LString.PasswordGenerator.editMenuTitle,
            action: #selector(didPressRandomizerEditMenu(_:)))
        UIMenuController.shared.menuItems = [randomizerMenu]
    }
    
    @objc private func didPressRandomizerEditMenu(_ sender: Any) {
        guard let editMenuDelegate = delegate as? TextInputEditMenuDelegate else {
            assertionFailure("This delegate cannot handle edit menu")
            return
        }
        editMenuDelegate.textInputDidRequestRandomizer(self)
    }
}


extension UITextView {
    internal func addRandomizerEditMenu() {
        assert(delegate is TextInputEditMenuDelegate, "Field delegate does not handle randomizer menu")
        let randomizerMenu = UIMenuItem(
            title: LString.PasswordGenerator.editMenuTitle,
            action: #selector(didPressRandomizerEditMenu(_:)))
        UIMenuController.shared.menuItems = [randomizerMenu]
    }
    
    @objc private func didPressRandomizerEditMenu(_ sender: Any) {
        guard let editMenuDelegate = delegate as? TextInputEditMenuDelegate else {
            assertionFailure("This delegate cannot handle edit menu")
            return
        }
        editMenuDelegate.textInputDidRequestRandomizer(self)
    }
}
