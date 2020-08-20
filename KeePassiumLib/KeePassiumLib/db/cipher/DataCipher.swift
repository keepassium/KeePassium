//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

protocol DataCipher: class {
    var uuid: UUID { get }
    var initialVectorSize: Int { get }
    var keySize: Int { get }
    var name: String { get }
    
    var progress: ProgressEx { get set }
    
    func initProgress() -> ProgressEx
    
    func encrypt(plainText: ByteArray, key: ByteArray, iv: ByteArray) throws -> ByteArray
    func decrypt(cipherText: ByteArray, key: ByteArray, iv: ByteArray) throws -> ByteArray
    
    func resizeKey(key: ByteArray) -> SecureByteArray
}

extension DataCipher {
    
    func initProgress() -> ProgressEx {
        progress = ProgressEx()
        return progress
    }
    
    func resizeKey(key: ByteArray) -> SecureByteArray {
        assert(key.count > 0)
        assert(keySize >= 0)
        
        if keySize == 0 {
            return SecureByteArray(ByteArray(count: 0))
        }
        
        let hash = (keySize <= 32) ? key.sha256 : key.sha512
        if hash.count == keySize {
            return SecureByteArray(hash)
        }
        
        if keySize < hash.count {
            return SecureByteArray(hash.prefix(keySize))
        } else {
            fatalError("Not implemented")
        }
    }
}
