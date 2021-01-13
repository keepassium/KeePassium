//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

class AbstractArgon2KDF {
    public static let saltParam        = "S" 
    public static let parallelismParam = "P" 
    public static let memoryParam      = "M" 
    public static let iterationsParam  = "I" 
    public static let versionParam     = "V" 
    public static let secretKeyParam   = "K" 
    public static let assocDataParam   = "A" 
    
    fileprivate let minVersion: UInt32 = 0x10
    fileprivate let maxVersion: UInt32 = 0x13
    fileprivate let minSalt    = 8
    fileprivate let maxSalt    = Int.max
    fileprivate let minIterations: UInt64 = 1
    fileprivate let maxIterations: UInt64 = UInt64(UInt32.max) 
    fileprivate let minMemory: UInt64 = 1024 * 8
    fileprivate let maxMemory: UInt64 = UInt64.max
    fileprivate let minParallelism: UInt32 = 1
    fileprivate let maxParallelism: UInt32 = (1 << 24) - 1
    
    fileprivate let defaultIterations: UInt64  = 100
    fileprivate let defaultMemory: UInt64      = 1024 * 1024 
    fileprivate let defaultParallelism: UInt32 = 2
    
    fileprivate var name: String {
        fatalError("Abstract method, override this")
    }
    fileprivate var uuid: UUID {
        fatalError("Abstract method, override this")
    }
    fileprivate var primitiveType: Argon2.PrimitiveType {
        fatalError("Abstract method, override this")
    }
    
    fileprivate var progress = ProgressEx()
    
    func initProgress() -> ProgressEx {
        progress = ProgressEx()
        progress.localizedDescription = NSLocalizedString(
            "[KDF/Progress] Processing the master key",
            bundle: Bundle.framework,
            value: "Processing the master key",
            comment: "Status message: processing of the master key is in progress")
        return progress
    }
    
    func getChallenge(_ params: KDFParams) throws -> ByteArray {
        guard let salt = params.getValue(key: AbstractArgon2KDF.saltParam)?.asByteArray() else {
            throw CryptoError.invalidKDFParam(kdfName: name, paramName: AbstractArgon2KDF.saltParam)
        }
        return salt
    }
    
    public var defaultParams: KDFParams {
        let params = KDFParams()
        params.setValue(key: KDFParams.uuidParam, value: VarDict.TypedValue(value: uuid.data))
        params.setValue(key: AbstractArgon2KDF.versionParam, value: VarDict.TypedValue(value: maxVersion))
        params.setValue(key: AbstractArgon2KDF.iterationsParam, value: VarDict.TypedValue(value: defaultIterations))
        params.setValue(key: AbstractArgon2KDF.memoryParam, value: VarDict.TypedValue(value: defaultMemory))
        params.setValue(key: AbstractArgon2KDF.parallelismParam, value: VarDict.TypedValue(value: defaultParallelism))
        return params
    }

    func randomize(params: inout KDFParams) throws {
        let salt = try CryptoManager.getRandomBytes(count: 32)
        params.setValue(key: AbstractArgon2KDF.saltParam, value: VarDict.TypedValue(value: salt))
    }

    fileprivate func getParams(_ params: KDFParams) throws -> Argon2.Params {
        guard let salt = params.getValue(key: AbstractArgon2KDF.saltParam)?.asByteArray() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.saltParam)
        }
        if salt.count < minSalt || salt.count > maxSalt {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.saltParam)
        }
        
        guard let parallelism = params.getValue(key: AbstractArgon2KDF.parallelismParam)?.asUInt32() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.parallelismParam)
        }
        if parallelism < minParallelism || parallelism > maxParallelism {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.parallelismParam)
        }
        
        guard let memory = params.getValue(key: AbstractArgon2KDF.memoryParam)?.asUInt64() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.memoryParam)
        }
        if memory < minMemory || memory > maxMemory {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.memoryParam)
        }
        
        guard let iterations64 = params.getValue(key: AbstractArgon2KDF.iterationsParam)?.asUInt64() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.iterationsParam)
        }
        if iterations64 < minIterations || iterations64 > maxIterations {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.iterationsParam)
        }
        
        guard let version = params.getValue(key: AbstractArgon2KDF.versionParam)?.asUInt32() else {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.versionParam)
        }
        if version < minVersion || version > maxVersion {
            throw CryptoError.invalidKDFParam(kdfName: self.name, paramName: AbstractArgon2KDF.versionParam)
        }
        
        return Argon2.Params(
            salt: salt,
            parallelism: parallelism,
            memoryKiB: UInt32(memory / UInt64(1024)), 
            iterations: UInt32(iterations64), 
            version: version
        )
    }
    
    func transform(key: SecureByteArray, params: KDFParams) throws -> SecureByteArray {
        assert(key.count > 0)
        
        let hashingParams = try getParams(params) 
        
        
        let outHash = try Argon2.hash(
            data: key,
            params: hashingParams,
            type: primitiveType,
            progress: progress)
        return SecureByteArray(outHash)
    }
}

final class Argon2dKDF: AbstractArgon2KDF, KeyDerivationFunction {
    public static let _uuid = UUID(
        uuid: (0xEF,0x63,0x6D,0xDF,0x8C,0x29,0x44,0x4B,0x91,0xF7,0xA9,0xA4,0x03,0xE3,0x0A,0x0C))
    
    override public var uuid: UUID { return Argon2dKDF._uuid }
    override public var name: String { return "Argon2d" }

    override fileprivate var primitiveType: Argon2.PrimitiveType { return .argon2d }
}

final class Argon2idKDF: AbstractArgon2KDF, KeyDerivationFunction {
    public static let _uuid = UUID(
        uuid: (0x9E,0x29,0x8B,0x19,0x56,0xDB,0x47,0x73,0xB2,0x3D,0xFC,0x3E,0xC6,0xF0,0xA1,0xE6))
    
    override public var uuid: UUID { return Argon2idKDF._uuid }
    override public var name: String { return "Argon2id" }

    override fileprivate var primitiveType: Argon2.PrimitiveType { return .argon2id }
}
