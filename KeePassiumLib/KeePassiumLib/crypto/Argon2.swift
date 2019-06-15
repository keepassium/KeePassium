//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class Argon2 {
    public static let version: UInt32 = 0x13
    
    private init() {
    }
    
    public static func hash(
        data pwd: ByteArray,
        salt: ByteArray,
        parallelism nThreads: UInt32,
        memoryKiB m_cost: UInt32,
        iterations t_cost: UInt32,
        version: UInt32,
        progress: ProgressEx?
        ) throws -> ByteArray
    {

        var isAbortProcessing: UInt8 = 0
        
        progress?.totalUnitCount = Int64(t_cost)
        progress?.completedUnitCount = 0
        let progressKVO = progress?.observe(
            \.isCancelled,
            options: [.new],
            changeHandler: { (progress, _) in
                if progress.cancellationReason == .lowMemoryWarning {
                    FLAG_clear_internal_memory = 0
                }
                isAbortProcessing = 1
            }
        )
        FLAG_clear_internal_memory = 1
        var outBytes = [UInt8](repeating: 0, count: 32)
        let statusCode = pwd.withBytes {
            (pwdBytes) in
            return salt.withBytes {
                (saltBytes) -> Int32 in
                guard let progress = progress else {
                    return argon2_hash(
                        t_cost, m_cost, nThreads, pwdBytes, pwdBytes.count,
                        saltBytes, saltBytes.count, &outBytes, outBytes.count,
                        nil, 0, Argon2_d, version, nil, nil, &isAbortProcessing)
                }
                
                let progressPtr = UnsafeRawPointer(Unmanaged.passUnretained(progress).toOpaque())
                
                
                return argon2_hash(
                    t_cost, m_cost, nThreads, pwdBytes, pwdBytes.count,
                    saltBytes, saltBytes.count, &outBytes, outBytes.count,
                    nil, 0, Argon2_d, version,
                    {
                        (pass: UInt32, observer: Optional<UnsafeRawPointer>) -> Int32 in
                        guard let observer = observer else { return 0 /* continue hashing */ }
                        let progress = Unmanaged<Progress>.fromOpaque(observer).takeUnretainedValue()
                        progress.completedUnitCount = Int64(pass)
                        let isShouldStop: Int32 = progress.isCancelled ? 1 : 0
                        return isShouldStop
                    },
                    progressPtr,
                    &isAbortProcessing)
            }
        }
        progressKVO?.invalidate()
        if let progress = progress {
            progress.completedUnitCount = Int64(t_cost) 
            if progress.isCancelled {
                throw ProgressInterruption.cancelled(reason: progress.cancellationReason)
            }
        }
        
        if statusCode != ARGON2_OK.rawValue {
            throw CryptoError.argon2Error(code: Int(statusCode))
        }
        return ByteArray(bytes: outBytes)
    }
}
