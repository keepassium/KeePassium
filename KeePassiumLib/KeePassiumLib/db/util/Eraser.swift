//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class Eraser {
    public static func erase(array: inout [UInt8]) {
        let count = array.count
        array.withUnsafeMutableBytes { pointer in
            _ = memset(pointer.baseAddress, 0, count)
        }
    }
    
    public static func erase<T: Eraseable>(_ array: inout [T]) {
        for item in array {
            item.erase()
        }
        array.removeAll()
    }
}




