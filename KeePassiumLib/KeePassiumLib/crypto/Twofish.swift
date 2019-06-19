//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class Twofish {
    public static let blockSize = 16
    private let key: SecureByteArray
    private let initVector: SecureByteArray
    private var internalKey: Twofish_key
    
    init(key: ByteArray, iv: ByteArray) {
        precondition(key.count <= 32, "Twofish key must be within 32 bytes")
        precondition(iv.count == Twofish.blockSize, "Twofish expects \(Twofish.blockSize)-byte IV")
        
        self.key = SecureByteArray(key)
        self.initVector = SecureByteArray(iv)
        self.internalKey = Twofish_key()
    }
    
    deinit {
        erase()
    }
    
    public func erase() {
        key.erase()
        initVector.erase()
        Twofish_clear_key(&internalKey)
    }
    
    func encrypt(data: ByteArray, progress: ProgressEx?) throws  {
        let nBlocks: Int = data.count / Twofish.blockSize
        
        progress?.totalUnitCount = Int64(nBlocks / 100) + 1 
        progress?.completedUnitCount = 0
        
        let initStatus = Twofish_initialise()
        guard initStatus == 0 else { throw CryptoError.twofishError(code: Int(initStatus)) }
        
        let keyPrepStatus = key.withMutableBytes { (keyBytes: inout [UInt8]) in
            return Twofish_prepare_key(&keyBytes, Int32(keyBytes.count), &internalKey)
        }
        guard keyPrepStatus == 0 else { throw CryptoError.twofishError(code: Int(keyPrepStatus)) }
        
        var outBuffer = [UInt8](repeating: 0, count: Twofish.blockSize)
        var block = [UInt8](repeating: 0, count: Twofish.blockSize)
        var iv = self.initVector.bytesCopy()
        for iBlock in 0..<nBlocks {
            let blockStartPos = iBlock * Twofish.blockSize
            for i in 0..<Twofish.blockSize {
                block[i] = data[blockStartPos + i] ^ iv[i]
            }
            Twofish_encrypt(&internalKey, &block, &outBuffer)
            for i in 0..<Twofish.blockSize {
                iv[i] = outBuffer[i]
                data[blockStartPos + i] = outBuffer[i]
            }
            if (iBlock % 100 == 0) {
                progress?.completedUnitCount += 1
                if progress?.isCancelled ?? false { break }
            }
        }
        Twofish_clear_key(&internalKey)
        
        if let progress = progress {
            progress.completedUnitCount = progress.totalUnitCount
            if progress.isCancelled {
                throw ProgressInterruption.cancelled(reason: progress.cancellationReason)
            }
        }
    }
    
    func decrypt(data: ByteArray, progress: ProgressEx?) throws {
        print("twofish key \(key.asHexString)")
        print("twofish iv \(initVector.asHexString)")
        print("twofish cipher \(data.prefix(32).asHexString)")

        let nBlocks: Int = data.count / Twofish.blockSize
        progress?.totalUnitCount = Int64(nBlocks / 100)
        progress?.completedUnitCount = 0

        let initStatus = Twofish_initialise()
        guard initStatus == 0 else { throw CryptoError.twofishError(code: Int(initStatus)) }
        
        let keyPrepStatus = key.withMutableBytes { (keyBytes: inout [UInt8]) in
            return Twofish_prepare_key(&keyBytes, Int32(keyBytes.count), &internalKey)
        }
        guard keyPrepStatus == 0 else { throw CryptoError.twofishError(code: Int(keyPrepStatus)) }
        
        var iv = self.initVector.bytesCopy()
        data.withMutableBytes { (dataBytes: inout [UInt8]) in
            var block = Array<UInt8>(repeating: 0, count: Twofish.blockSize)
            for iBlock in 0..<nBlocks {
                let blockStartPos = iBlock * Twofish.blockSize
                Twofish_decrypt(&internalKey, &dataBytes + blockStartPos, &block)
                for i in 0..<Twofish.blockSize {
                    block[i] ^= iv[i]
                }
                memcpy(&iv, &dataBytes + blockStartPos, Twofish.blockSize)
                memcpy(&dataBytes + blockStartPos, &block, Twofish.blockSize)
                if (iBlock % 100 == 0) {
                    progress?.completedUnitCount += 1
                    if progress?.isCancelled ?? false { break }
                }
            }
        }
        Twofish_clear_key(&internalKey)

        if let progress = progress {
            progress.completedUnitCount = progress.totalUnitCount
            if progress.isCancelled {
                throw ProgressInterruption.cancelled(reason: progress.cancellationReason)
            }
        }
    }
}
