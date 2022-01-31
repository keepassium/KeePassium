//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class KDFParams: VarDict {
    public static let uuidParam = "$UUID"
    public var kdfUUID: UUID {
        let uuidBytes = getValue(key: KDFParams.uuidParam)?.asByteArray()
        return UUID(data: uuidBytes) ?? UUID.ZERO
    }
    
    override func erase() {
        super.erase()
    }
    
    override func read(data: ByteArray) -> Bool {
        Diag.debug("Parsing KDF params")
        guard super.read(data: data) else { return false }
        
        guard let value = getValue(key: KDFParams.uuidParam) else {
            Diag.warning("KDF UUID is missing")
            return false
        }
        guard let uuidData = value.asByteArray(),
            let _ = UUID(data: uuidData) else {
                Diag.warning("KDF UUID is malformed")
                return false
        }
        return true
    }
}
