//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation


public enum TOTPHashAlgorithm {
    public static let allValues: [TOTPHashAlgorithm] = [.sha1, .sha256, .sha512]
    case sha1
    case sha256
    case sha512
    
    var asString: String {
        switch self {
        case .sha1: return "SHA1"
        case .sha256: return "SHA256"
        case .sha512: return "SHA512"
        }
    }
    
    public static func fromString(_ algorithmString: String) -> TOTPHashAlgorithm? {
        for candidate in TOTPHashAlgorithm.allValues {
            if algorithmString.caseInsensitiveCompare(candidate.asString) == .orderedSame {
                return candidate
            }
        }
        return nil
    }
}

public protocol TOTPGenerator: class {
    var elapsedTimeFraction: Float { get }
    
    func generate() -> String
}

extension TOTPGenerator {
    fileprivate func getElapsedTimeFraction(timeStep: Int) -> Float {
        let now = Date.now.timeIntervalSince1970
        let _timeStep = Double(timeStep)
        let totpTime = floor(now / _timeStep) * _timeStep
        let result = Float((now - totpTime) / _timeStep)
        return result
    }
    
    fileprivate func calculateFullCode(
        counterBytes: ByteArray,
        seed: ByteArray,
        algorithm: TOTPHashAlgorithm
    ) -> Int {
        let hmac: ByteArray
        switch algorithm {
        case .sha1:
            hmac = CryptoManager.hmacSHA1(data: counterBytes, key: seed)
        case .sha256:
            hmac = CryptoManager.hmacSHA256(data: counterBytes, key: seed)
        case .sha512:
            hmac = CryptoManager.hmacSHA512(data: counterBytes, key: seed)
        }
        let fullCode = hmac.withBytes { (hmacBytes) -> UInt32 in
            let startPos = Int(hmacBytes[hmacBytes.count - 1] & 0x0F)
            let hmacBytesSlice = ByteArray(bytes: hmacBytes[startPos..<(startPos+4)])
            let code = UInt32(data: hmacBytesSlice)!.byteSwapped
            return code & 0x7FFFFFFF
        }
        return Int(fullCode)
    }
}

public class TOTPGeneratorRFC6238: TOTPGenerator {
    internal let seed: ByteArray
    internal let timeStep: Int
    internal let length: Int
    internal let hashAlgorithm: TOTPHashAlgorithm
    
    public var elapsedTimeFraction: Float { return getElapsedTimeFraction(timeStep: timeStep) }

    internal init?(seed: ByteArray, timeStep: Int, length: Int, hashAlgorithm: TOTPHashAlgorithm) {
        guard length >= 4 && length <= 8 else { return nil }
        guard timeStep > 0 else { return nil }
        
        self.seed = seed
        self.timeStep = timeStep
        self.length = length
        self.hashAlgorithm = hashAlgorithm
    }

    
    public func generate() -> String {
        let counter = UInt64(floor(Date.now.timeIntervalSince1970 / Double(timeStep))).bigEndian
        let fullCode = calculateFullCode(
            counterBytes: ByteArray(bytes: counter.bytes),
            seed: seed,
            algorithm: hashAlgorithm
        )
        let trimmingMask = Int(pow(Double(10), Double(length)))
        let trimmedCode = fullCode % trimmingMask
        return String(format: "%0.\(length)d", arguments: [trimmedCode])
    }
}


public class TOTPGeneratorSteam: TOTPGenerator {
    public static let typeSymbol = "S"
    private let steamChars = [
        "2","3","4","5","6","7","8","9","B","C","D","F","G",
        "H","J","K","M","N","P","Q","R","T","V","W","X","Y"]

    public var elapsedTimeFraction: Float { return getElapsedTimeFraction(timeStep: timeStep) }
    
    private let seed: ByteArray
    private let timeStep: Int
    private let length = 5
    private let hashAlgorithm = TOTPHashAlgorithm.sha1

    internal init?(seed: ByteArray, timeStep: Int) {
        guard timeStep > 0 else { return nil }
        
        self.seed = seed
        self.timeStep = timeStep
    }
    
    public func generate() -> String {
        let counter = UInt64(floor(Date.now.timeIntervalSince1970 / Double(timeStep))).bigEndian
        var code = calculateFullCode(
            counterBytes: ByteArray(bytes: counter.bytes),
            seed: seed,
            algorithm: hashAlgorithm
        )
        var result = [String]()
        for _ in 0..<length {
            let index = code % steamChars.count
            result.append(steamChars[index])
            code /= steamChars.count
        }
        return result.joined()
    }
}
