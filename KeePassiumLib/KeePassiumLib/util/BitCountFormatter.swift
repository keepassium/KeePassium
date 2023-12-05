//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class BitCountFormatter: Formatter {
    public static func string(fromBitCount bitCount: Int64) -> String {
        let result = String.localizedStringWithFormat(LString.bitCountTemplate, bitCount)
        return result
    }
}
