//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class TwofishDataCipher: DataCipher {
    private let _uuid = UUID(uuid:
        (0xad,0x68,0xf2,0x9f,0x57,0x6f,0x4b,0xb9,0xa3,0x6a,0xd4,0x7a,0xf9,0x65,0x34,0x6c))
    var uuid: UUID { return _uuid }
    var name: String { return "Twofish" }
    
    var initialVectorSize: Int { return Twofish.blockSize }
    var keySize: Int { return 32 }
    
    internal var progress = ProgressEx()
    
    private let isPaddingLikelyMessedUp: Bool
    
    init(isPaddingLikelyMessedUp: Bool) {
        self.isPaddingLikelyMessedUp = isPaddingLikelyMessedUp
    }

    func encrypt(plainText data: ByteArray, key: ByteArray, iv: ByteArray) throws -> ByteArray {
        assert(key.count == self.keySize)
        assert(iv.count == self.initialVectorSize)
        
        progress.localizedDescription = NSLocalizedString(
            "[Cipher/Progress] Encrypting",
            bundle: Bundle.framework,
            value: "Encrypting",
            comment: "Progress status")
        
        let twofish = Twofish(key: key, iv: iv)
        let dataClone = data.clone() 
        CryptoManager.addPadding(data: dataClone, blockSize: Twofish.blockSize)
        try twofish.encrypt(data: dataClone, progress: progress)
        return dataClone
    }
    
    func decrypt(cipherText encData: ByteArray, key: ByteArray, iv: ByteArray) throws -> ByteArray {
        assert(key.count == self.keySize)
        assert(iv.count == self.initialVectorSize)
        progress.localizedDescription = NSLocalizedString(
            "[Cipher/Progress] Decrypting",
            bundle: Bundle.framework,
            value: "Decrypting",
            comment: "Progress status")
        
        let twofish = Twofish(key: key, iv: iv) 
        let dataClone = encData.clone() 
        try twofish.decrypt(data: dataClone, progress: progress)
        
        if isPaddingLikelyMessedUp {
            try? CryptoManager.removePadding(data: dataClone) 
        } else {
            try CryptoManager.removePadding(data: dataClone) 
        }
        return dataClone
    }
}
