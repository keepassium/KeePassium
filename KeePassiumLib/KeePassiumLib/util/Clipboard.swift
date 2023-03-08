//  KeePassium Password Manager
//  Copyright © 2018–2023 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import MobileCoreServices

public class Clipboard {

    public static let general = Clipboard()
    
    private init() {
    }
    
    public func insert(url: URL, timeout: Double?=nil) {
        Diag.debug("Inserted a URL to clipboard")
        insert(items: [[(kUTTypeURL as String) : url]], timeout: timeout)
        scheduleCleanup(url: url, after: timeout)
    }
    
    @discardableResult
    public func insert(text: String, timeout: Double?=nil) -> Bool {
        Diag.debug("Inserted a string to clipboard")
        insert(items: [[(kUTTypeUTF8PlainText as String) : text]], timeout: timeout)
        let isSuccessful = (UIPasteboard.general.string == text)
        if isSuccessful {
            scheduleCleanup(text: text, after: timeout)
        }
        return isSuccessful
    }
    
    private func insert(items: [[String: Any]], timeout: Double?) {
        let isLocalOnly = !Settings.current.isUniversalClipboardEnabled
        if let timeout = timeout, timeout > 0.0 {
            UIPasteboard.general.setItems(
                items,
                options: [
                    .localOnly: isLocalOnly,
                    .expirationDate: Date(timeIntervalSinceNow: timeout)
                ]
            )
        } else {
            UIPasteboard.general.setItems(items, options: [.localOnly: isLocalOnly])
        }
    }

    private func scheduleCleanup(url: URL, after timeout: TimeInterval?) {
        guard ProcessInfo.isRunningOnMac,
              let timeout = timeout,
              timeout > 0
        else {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            if UIPasteboard.general.url == url {
                self.clear()
            }
        }
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
