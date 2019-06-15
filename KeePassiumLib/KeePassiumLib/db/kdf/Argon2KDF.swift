//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

final class Argon2KDF: KeyDerivationFunction {
    public static let _uuid = UUID(uuid:
        (0xEF,0x63,0x6D,0xDF,0x8C,0x29,0x44,0x4B,0x91,0xF7,0xA9,0xA4,0x03,0xE3,0x0A,0x0C))
    public var uuid: UUID { return Argon2KDF._uuid }
    public var name: String { return "Argon2" }

    public static let saltParam        = "S" 
    public static let parallelismParam = "P" 
    public static let memoryParam      = "M" 
    public static let iterationsParam  = "I" 
    public static let versionParam     = "V" 
    public static let secretKeyParam   = "K" 
    public static let assocDataParam   = "A" 
    
    private let minVersion: UInt32 = 0x10
    private let maxVersion: UInt32 = 0x13
    private let minSalt    = 8
    private let maxSalt    = Int.max
    private let minIterations: UInt64 = 1
    private let maxIterations: UInt64 = UInt64.max
    private let minMemory: UInt64 = 1024 * 8
    private let maxMemory: UInt64 = UInt64.max
    private let minParallelism: UInt32 = 1
    private let maxParallelism: UInt32 = (1 << 24) - 1
    
    private let defaultIterations: UInt64  = 100
    private let defaultMemory: UInt64      = 1024 * 1024 
    private let defaultParallelism: UInt32 = 2
    
    public var defaultParams: KDFParams {
        let params = KDFParams()
        params.setValue(key: KDFParams.uuidParam, value: VarDict.TypedValue(value: uuid.data))
        params.setValue(key: Argon2KDF.versionParam, value: VarDict.TypedValue(value: maxVersion))
        params.setValue(key: Argon2KDF.iterationsParam, value: VarDict.TypedValue(value: defaultIterations))
        params.setValue(key: Argon2KDF.memoryParam, value: VarDict.TypedValue(value: defaultMemory))
        params.setValue(key: Argon2KDF.parallelismParam, value: VarDict.TypedValue(value: defaultParallelism))
        return params
    }

    private var progress = ProgressEx()
    
    required init() {
    }
    
    func initProgress() -> ProgressEx {
        progress = ProgressEx()
        progress.localizedDescription = NSLocalizedString("Master key processing", comment: "Status message: processing of the master key is in progress")
        return progress
    }
    
    func randomize(params: inout KDFParams) throws { 
        let salt = try CryptoManager.getRandomBytes(count: 32)
        params.setValue(key: Argon2KDF.saltParam, value: VarDict.TypedValue(value: salt))
    }

    func transform(key: SecureByteArray, params: KDFParams) throws -> SecureByteArray {
        assert(key.count > 0)
        
        guard let salt = params.getValue(key: Argon2KDF.saltParam)?.asByteArray() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.saltParam)
        }
        if salt.count < minSalt || salt.count > maxSalt {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.saltParam)
        }

        guard let parallelism = params.getValue(key: Argon2KDF.parallelismParam)?.asUInt32() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.parallelismParam)
        }
        if parallelism < minParallelism || parallelism > maxParallelism {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.parallelismParam)
        }
        
        guard let memory = params.getValue(key: Argon2KDF.memoryParam)?.asUInt64() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.memoryParam)
        }
        if memory < minMemory || memory > maxMemory {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.memoryParam)
        }
        
        guard let iterations = params.getValue(key: Argon2KDF.iterationsParam)?.asUInt64() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.iterationsParam)
        }
        if iterations < minIterations || iterations > maxIterations {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.iterationsParam)
        }
        
        guard let version = params.getValue(key: Argon2KDF.versionParam)?.asUInt32() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.versionParam)
        }
        if version < minVersion || version > maxVersion {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: Argon2KDF.versionParam)
        }
        
        
        let memoryKiB: UInt32 = UInt32(memory / UInt64(1024)) 
        let outHash = try Argon2.hash(
            data: key,
            salt: salt,
            parallelism: parallelism,
            memoryKiB: memoryKiB,
            iterations: UInt32(iterations),
            version: version,
            progress: progress)
        return SecureByteArray(outHash)
    }
}
