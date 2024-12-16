//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol TextInputView: UITextInput & UIView {
    func replaceText(in range: Range<String.Index>, withText: String)
}

extension UITextField: TextInputView {
    func replaceText(in range: Range<String.Index>, withText: String) {
        let newText = text?.replacingCharacters(in: range, with: withText) ?? ""
        text = newText
        sendActions(for: .editingChanged)

        let selectionEndIndex = newText.index(range.lowerBound, offsetBy: withText.count)
        let offset = newText.distance(from: newText.startIndex, to: selectionEndIndex)
        if let cursorPos = position(from: beginningOfDocument, offset: offset) {
            selectedTextRange = textRange(from: cursorPos, to: cursorPos)
        }
    }
}

extension UITextView: TextInputView {
    func replaceText(in range: Range<String.Index>, withText: String) {
        let newText = text?.replacingCharacters(in: range, with: withText) ?? ""
        text = newText
        NotificationCenter.default.post(name: UITextView.textDidChangeNotification, object: self)

        let selectionEnd = newText.index(range.lowerBound, offsetBy: withText.count)
        selectedRange = NSRange(selectionEnd..<selectionEnd, in: text)
    }
}

protocol TextInputEditMenuDelegate: AnyObject {
    func textInputDidRequestRandomizer(_ textInput: TextInputView)
}

extension TextInputView {
    internal func addRandomizerEditMenu(to suggestedActions: [UIMenuElement]) -> UIMenu? {
        let delegate = (self as? UITextView)?.delegate as? TextInputEditMenuDelegate ??
                       (self as? UITextField)?.delegate as? TextInputEditMenuDelegate
        assert(delegate != nil, "Field delegate does not handle randomizer menu")
        let menuTitle = ProcessInfo.isRunningOnMac
            ? LString.PasswordGenerator.editMenuTitleFull
            : LString.PasswordGenerator.editMenuTitleShort
        let randomizerMenu = UIAction(title: menuTitle) { [weak delegate] _ in
            delegate?.textInputDidRequestRandomizer(self)
        }
        return UIMenu(children: suggestedActions + [randomizerMenu])
    }
}
