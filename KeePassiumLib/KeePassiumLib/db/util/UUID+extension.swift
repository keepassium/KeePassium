//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension UUID {
    public static let ZERO = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    public static let byteWidth = 16
    
    mutating func erase() {
        self = UUID.ZERO
    }
    
    internal var data: ByteArray {
        var bytes = Array<UInt8>(repeating: 0, count: UUID.byteWidth)
        guard let nsuuid = NSUUID(uuidString: self.uuidString) else {
            fatalError()
        }
        nsuuid.getBytes(&bytes)
        return ByteArray(bytes: bytes)
    }

    internal init?(data: ByteArray?) {
        guard let data = data else { return nil }
        guard data.count == UUID.byteWidth else { return nil }
        let nsuuid = data.withBytes {
            NSUUID(uuidBytes: $0)
        }
        self.init(uuidString: nsuuid.uuidString)
    }
    
    internal init?(base64Encoded base64: String?) {
        guard let data = ByteArray(base64Encoded: base64) else { return nil }
        let nsuuid = data.withBytes {
            NSUUID(uuidBytes: $0)
        }
        self.init(uuidString: nsuuid.uuidString)
    }
    
    internal func base64EncodedString() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        (self as NSUUID).getBytes(&bytes)
        return Data(bytes).base64EncodedString()
    }
}
