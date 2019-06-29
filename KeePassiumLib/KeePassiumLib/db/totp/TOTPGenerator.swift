//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

open class TOTPGeneratorFactory {
    public static let totpSeedFieldName = "TOTP Seed"
    public static let totpSettingsFieldName = "TOTP Settings"
    
    public static func makeGenerator(for entry: Entry) -> TOTPGenerator? {
        guard let seedField =
            entry.getField(with: TOTPGeneratorFactory.totpSeedFieldName) else { return nil }
        guard let settingsField =
            entry.getField(with: TOTPGeneratorFactory.totpSettingsFieldName) else { return nil }
        return TOTPGeneratorFactory.makeGenerator(
            seed: seedField.value,
            settings: settingsField.value)
    }
    
    public static func makeGenerator(from fields: [EntryField]) -> TOTPGenerator? {
        guard let seedField =
            fields.first(where: { $0.name == TOTPGeneratorFactory.totpSeedFieldName })
            else { return nil }
        guard let settingsField =
            fields.first(where: { $0.name == TOTPGeneratorFactory.totpSettingsFieldName })
            else { return nil }
        return TOTPGeneratorFactory.makeGenerator(
            seed: seedField.value,
            settings: settingsField.value)
    }
    
    public static func makeGenerator(
        seed seedString: String,
        settings settingsString: String
    ) -> TOTPGenerator? {
        guard let seed = parseSeedString(seedString) else {
            Diag.warning("Unrecognized TOTP seed format")
            return nil
        }
        
        let settings = settingsString.split(separator: ";")
        guard settings.count == 2 else {
            Diag.warning("Unexpected TOTP settings number [expected: 2, got: \(settings.count)]")
            return nil
        }
        guard let timeStep = Int(settings[0]) else {
            Diag.warning("Failed to parse TOTP time step as Int")
            return nil
        }
        guard timeStep > 0 else {
            Diag.warning("Invalid TOTP time step value: \(timeStep)")
            return nil
        }
        
        if let length = Int(settings[1]) {
            return TOTPGeneratorRFC6238(seed: seed, timeStep: timeStep, length: length)
        } else if settings[1] == TOTPGeneratorSteam.typeSymbol {
            return TOTPGeneratorSteam(seed: seed, timeStep: timeStep)
        } else {
            Diag.warning("Unexpected TOTP size or type: '\(settings[1])'")
            return nil
        }
    }
    
    static func parseSeedString(_ seedString: String) -> ByteArray? {
        let cleanedSeedString = seedString
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "=", with: "")
        if let seedData = base32DecodeToData(cleanedSeedString) {
            return ByteArray(data: seedData)
        }
        if let seedData = base32HexDecodeToData(cleanedSeedString) {
            return ByteArray(data: seedData)
        }
        if let seedData = Data(base64Encoded: cleanedSeedString) {
            return ByteArray(data: seedData)
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
    
    fileprivate func calculateFullCode(counterBytes: ByteArray, seed: ByteArray) -> Int {
        let hmac = CryptoManager.hmacSHA1(data: counterBytes, key: seed)
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
    private let seed: ByteArray
    private let timeStep: Int
    private let length: Int
    
    public var elapsedTimeFraction: Float { return getElapsedTimeFraction(timeStep: timeStep) }

    fileprivate init?(seed: ByteArray, timeStep: Int, length: Int) {
        guard length >= 4 && length <= 8 else { return nil }
        
        self.seed = seed
        self.timeStep = timeStep
        self.length = length
    }

    
    public func generate() -> String {
        let counter = UInt64(floor(Date.now.timeIntervalSince1970 / Double(timeStep))).bigEndian
        let fullCode = calculateFullCode(counterBytes: ByteArray(bytes: counter.bytes), seed: seed)
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

    fileprivate init?(seed: ByteArray, timeStep: Int) {
        self.seed = seed
        self.timeStep = timeStep
    }
    
    public func generate() -> String {
        let counter = UInt64(floor(Date.now.timeIntervalSince1970 / Double(timeStep))).bigEndian
        var code = calculateFullCode(counterBytes: ByteArray(bytes: counter.bytes), seed: seed)
        var result = [String]()
        for _ in 0..<length {
            let index = code % steamChars.count
            result.append(steamChars[index])
            code /= steamChars.count
        }
        return result.joined()
    }
}
