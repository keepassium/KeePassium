//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import MobileCoreServices
import UIKit
import UniformTypeIdentifiers

public class Clipboard {

    public static let general = Clipboard()
    private static let concealedTypeID = "org.nspasteboard.ConcealedType"

    private init() {
    }

    @discardableResult
    public func copyWithTimeout(_ string: String) -> Bool {
        let timeout = Settings.current.clipboardTimeout
        guard timeout != .immediately else {
            Diag.debug("Clipboard is disabled")
            return false
        }
        return insert(string, timeout: TimeInterval(timeout.seconds))
    }

    @discardableResult
    public func copyWithoutExpiry(_ string: String) -> Bool {
        return insert(string, timeout: nil)
    }

    private func insert(_ string: String, timeout: TimeInterval?) -> Bool {
        var pasteboardItem = [String: Any]()
        if string.isOpenableURL,
           let url = URL(string: string)
        {
            Diag.debug("Inserted a URL to clipboard")
            pasteboardItem[UTType.url.identifier] = url
            pasteboardItem[UTType.utf8PlainText.identifier] = string
        } else {
            Diag.debug("Inserted a string to clipboard")
            pasteboardItem[UTType.utf8PlainText.identifier] = string
        }
        if ProcessInfo.isRunningOnMac {
            pasteboardItem[Self.concealedTypeID] = string
        }

        let isLocalOnly = !Settings.current.isUniversalClipboardEnabled
        if let timeout = timeout, timeout > 0.0 {
            UIPasteboard.general.setItems(
                [pasteboardItem],
                options: [
                    .localOnly: isLocalOnly,
                    .expirationDate: Date(timeIntervalSinceNow: timeout)
                ]
            )
        } else {
            UIPasteboard.general.setItems([pasteboardItem], options: [.localOnly: isLocalOnly])
        }

        let isSuccessful = (UIPasteboard.general.string == string)
        if isSuccessful {
            scheduleCleanup(text: string, after: timeout)
        }
        return isSuccessful
    }

    private func scheduleCleanup(text: String, after timeout: TimeInterval?) {
        guard ProcessInfo.isRunningOnMac,
              let timeout = timeout,
              timeout > 0
        else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if UIPasteboard.general.string == text {
                self.clear()
            }
        }
    }

    private func clear() {
        let isLocalOnly = !Settings.current.isUniversalClipboardEnabled
        UIPasteboard.general.setItems([[:]], options: [.localOnly: isLocalOnly])
        Diag.info("Clipboard content cleared")
    }
}
