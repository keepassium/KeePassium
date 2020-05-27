//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import MobileCoreServices

public class Clipboard {

    public static let general = Clipboard()
    
    private var insertedText: String?
    private var insertedURL: URL?
    
    private init() {
    }
    
    public func insert(url: URL, timeout: Double?=nil) {
        Diag.debug("Inserted a URL to clipboard")
        insert(items: [[(kUTTypeURL as String) : url]], timeout: timeout)
        insertedURL = url
    }
    
    public func insert(text: String, timeout: Double?=nil) {
        Diag.debug("Inserted a string to clipboard")
        insert(items: [[(kUTTypeUTF8PlainText as String) : text]], timeout: timeout)
        insertedText = text
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
    
    public func clear() {
        let pasteboard = UIPasteboard.general

        var containsOurStuff = false
        if let insertedText = insertedText {
            containsOurStuff = containsOurStuff || (pasteboard.string == insertedText)
        }
        if let insertedURL = insertedURL {
            containsOurStuff = containsOurStuff || (pasteboard.url == insertedURL)
        }
        
        if containsOurStuff {
            pasteboard.setItems([[:]], options: [.localOnly: true])
            self.insertedText = nil
            self.insertedURL = nil
            Diag.info("Clipboard content cleared")
        }
    }
}
