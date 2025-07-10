//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class ThreadCountFormatter: Formatter {
    public static func string(fromThreadsCount threadsCount: UInt32) -> String {
        let result = String.localizedStringWithFormat(LString.threadCountTemplate, threadsCount)
        return result
    }
}
