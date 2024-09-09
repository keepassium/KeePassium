//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import UIKit

extension UITextView {
    @objc func timeoutCopy(_ sender: Any?) {
        guard let selectedTextRange,
              let selectedText = self.text(in: selectedTextRange)
        else {
            return
        }
        Clipboard.general.copyWithTimeout(selectedText)
    }

    @objc func timeoutCut(_ sender: Any?) {
        if let selectedTextRange,
           let selectedText = self.text(in: selectedTextRange)
        {
            self.timeoutCut(sender)
            Clipboard.general.copyWithTimeout(selectedText)
        }
    }

    @objc func timeoutCanPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if (action == #selector(copy(_:)) || action == #selector(cut(_:)))
           && Settings.current.clipboardTimeout == .immediately
        {
            return false
        }
        return self.timeoutCanPerformAction(action, withSender: sender)
    }

    static func swizzleMethods() {
        Swizzler.exchangeMethods(
            type: Self.self,
            originalSelector: #selector(canPerformAction(_:withSender:)),
            swizzledSelector: #selector(timeoutCanPerformAction(_:withSender:))
        )
        Swizzler.exchangeMethods(
            type: Self.self,
            originalSelector: #selector(copy(_:)),
            swizzledSelector: #selector(timeoutCopy(_:))
        )
        Swizzler.exchangeMethods(
            type: Self.self,
            originalSelector: #selector(cut(_:)),
            swizzledSelector: #selector(timeoutCut(_:))
        )
    }
}

extension UITextField {
    @objc func timeoutCopy(_ sender: Any?) {
        guard let selectedTextRange,
              let selectedText = self.text(in: selectedTextRange)
        else {
            return
        }
        Clipboard.general.copyWithTimeout(selectedText)
    }

    @objc func timeoutCut(_ sender: Any?) {
        if let selectedTextRange,
           let selectedText = self.text(in: selectedTextRange)
        {
            self.timeoutCut(sender)
            Clipboard.general.copyWithTimeout(selectedText)
        }
    }

    @objc func timeoutCanPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if (action == #selector(copy(_:)) || action == #selector(cut(_:)))
           && Settings.current.clipboardTimeout == .immediately
        {
            return false
        }
        return self.timeoutCanPerformAction(action, withSender: sender)
    }

    static func swizzleMethods() {
        Swizzler.exchangeMethods(
            type: Self.self,
            originalSelector: #selector(canPerformAction(_:withSender:)),
            swizzledSelector: #selector(timeoutCanPerformAction(_:withSender:))
        )
        Swizzler.exchangeMethods(
            type: Self.self,
            originalSelector: #selector(copy(_:)),
            swizzledSelector: #selector(timeoutCopy(_:))
        )
        Swizzler.exchangeMethods(
            type: Self.self,
            originalSelector: #selector(cut(_:)),
            swizzledSelector: #selector(timeoutCut(_:))
        )
    }
}
