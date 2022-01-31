//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class Twofish {
    public static let blockSize = 16
    private let key: SecureBytes
    private let initVector: SecureBytes
    private var internalKey: Twofish_key
    
    init(key: SecureBytes, iv: SecureBytes) {
        precondition(key.count <= 32, "Twofish key must be within 32 bytes")
        precondition(iv.count == Twofish.blockSize, "Twofish expects \(Twofish.blockSize)-byte IV")
        
        self.key = key.clone()
        self.initVector = iv.clone()
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
        
        let keyPrepStatus = key.withDecryptedMutableBytes { (keyBytes: inout [UInt8]) in
            return Twofish_prepare_key(&keyBytes, Int32(keyBytes.count), &internalKey)
        }
        guard keyPrepStatus == 0 else {
            throw CryptoError.twofishError(code: Int(keyPrepStatus))
        }
        
        var outBuffer = [UInt8](repeating: 0, count: Twofish.blockSize)
        var block = [UInt8](repeating: 0, count: Twofish.blockSize)
        initVector.withDecryptedMutableBytes { iv in
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
        #if DEBUG
        key.withDecryptedByteArray { keyBytes in
            initVector.withDecryptedByteArray { ivBytes in
                print("twofish key \(keyBytes.asHexString)")
                print("twofish iv \(ivBytes.asHexString)")
            }
        }
        print("twofish cipher \(data.prefix(32).asHexString)")
        #endif
        
        let nBlocks: Int = data.count / Twofish.blockSize
        progress?.totalUnitCount = Int64(nBlocks / 100)
        progress?.completedUnitCount = 0

        let initStatus = Twofish_initialise()
        guard initStatus == 0 else { throw CryptoError.twofishError(code: Int(initStatus)) }
        
        let keyPrepStatus = key.withDecryptedMutableBytes { (keyBytes: inout [UInt8]) -> Int32 in
            return Twofish_prepare_key(&keyBytes, Int32(keyBytes.count), &internalKey)
        }
        guard keyPrepStatus == 0 else { throw CryptoError.twofishError(code: Int(keyPrepStatus)) }
        
        data.withMutableBytes { (dataBytes: inout [UInt8]) in
            initVector.withDecryptedMutableBytes { ivBytes in
                var block = Array<UInt8>(repeating: 0, count: Twofish.blockSize)
                for iBlock in 0..<nBlocks {
                    let blockStartPos = iBlock * Twofish.blockSize
                    dataBytes.withUnsafeMutableBufferPointer {
                        (buffer: inout UnsafeMutableBufferPointer) in
                        Twofish_decrypt(&internalKey, buffer.baseAddress! + blockStartPos, &block)
                        for i in 0..<Twofish.blockSize {
                            block[i] ^= ivBytes[i]
                        }
                        memcpy(&ivBytes, buffer.baseAddress! + blockStartPos, Twofish.blockSize)
                        memcpy(buffer.baseAddress! + blockStartPos, &block, Twofish.blockSize)
                    }
                    if (iBlock % 100 == 0) {
                        progress?.completedUnitCount += 1
                        if progress?.isCancelled ?? false { break }
                    }
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
