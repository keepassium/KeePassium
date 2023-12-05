//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol Cloneable {
    associatedtype T 
    func clone() -> T
}

public extension Array where Element == UInt8 {
    func clone() -> [UInt8] {
        return self.withUnsafeBufferPointer {
            [UInt8].init($0)
        }
    }
}
