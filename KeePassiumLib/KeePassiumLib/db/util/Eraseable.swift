//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol Eraseable {
    func erase()
}

public protocol EraseableStruct {
    mutating func erase()
}

extension Array where Element: EraseableStruct {
    mutating func erase() {
        for i in 0..<count {
            self[i].erase()
        }
        removeAll()
    }
}

extension Array where Element: Eraseable {
    mutating func erase() {
        for i in 0..<count {
            self[i].erase()
        }
        removeAll()
    }
}

public extension Array where Element == UInt8 {
    mutating func erase() {
        withUnsafeBufferPointer {
            let mutatablePointer = UnsafeMutableRawPointer(mutating: $0.baseAddress!)
            memset_s(mutatablePointer, $0.count, 0, $0.count)
        }
        removeAll()
    }
}

extension Data: EraseableStruct {
    mutating public func erase() {
        resetBytes(in: 0..<count)
        removeAll()
    }
}

extension Dictionary where Key: Eraseable, Value: Eraseable {
    mutating func erase() {
        forEach({ (key, value) in
            key.erase()
            value.erase()
        })
        removeAll()
    }
}
extension Dictionary where Value: Eraseable {
    mutating func erase() {
        forEach({ (key, value) in
            value.erase()
        })
        removeAll()
    }
}
