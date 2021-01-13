//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension Clipboard {
    
    public func insert(_ content: String) {
        let timeout = Double(Settings.current.clipboardTimeout.seconds)
        if content.isOpenableURL {
            Clipboard.general.insert(url: URL(string: content)!, timeout: timeout)
        } else {
            Clipboard.general.insert(text: content, timeout: timeout)
        }
    }
}
