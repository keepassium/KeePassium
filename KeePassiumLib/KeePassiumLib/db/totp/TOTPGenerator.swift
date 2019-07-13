//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

open class TOTPGeneratorFactory {
    enum SplitFormat {
        public static let seedFieldName = "TOTP Seed"
        public static let settingsFieldName = "TOTP Settings"
    }
    
    enum URIFormat {
        public static let fieldName = "otp"
        
        public static let scheme = "otpauth"
        public static let host = "totp"
        
        public static let seedParam = "secret"
        public static let timeStepParam = "period"
        public static let lengthParam = "digits"
        public static let algorithmParam = "algorithm"
        
        public static let defaultTimeStep = 30
        public static let defaultLength = 6
        public static let defaultAlgorithm = "SHA1"
    }
    
    public static func makeGenerator(for entry: Entry) -> TOTPGenerator? {
        return makeGenerator(from: entry.fields)
    }
    
    public static func makeGenerator(from fields: [EntryField]) -> TOTPGenerator? {
        if let totpURIField = fields.first(where: { $0.name == URIFormat.fieldName }) {
            return TOTPGeneratorFactory.makeGenerator(uri: totpURIField.value)
        } else {
            guard let seedField =
                fields.first(where: { $0.name == SplitFormat.seedFieldName })
                else { return nil }
            guard let settingsField =
                fields.first(where: { $0.name == SplitFormat.settingsFieldName })
                else { return nil }
            return TOTPGeneratorFactory.makeGenerator(
                seed: seedField.value,
                settings: settingsField.value)
        }
    }
    
    public static func makeGenerator(uri uriString: String) -> TOTPGenerator? {
         guard let components = URLComponents(string: uriString),
            components.scheme == URIFormat.scheme,
            components.host == URIFormat.host,
            let queryItems = components.queryItems else
        {
            Diag.warning("OTP URI has unexpected format")
            return nil
        }
        
        let params = queryItems.reduce(into: [String: String]()) { (result, item) in
            result[item.name] = item.value
        }
        
        guard let seedString = params[URIFormat.seedParam],
            let seedData = base32DecodeToData(seedString),
            !seedData.isEmpty else
        {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(URIFormat.seedParam)]")
            return nil
        }
        
        if let algorithm = params[URIFormat.algorithmParam],
            algorithm != URIFormat.defaultAlgorithm
        {
            Diag.warning("OTP algorithm is not supported [algorithm: \(algorithm)]")
            return nil
        }
        guard let timeStep = Int(params[URIFormat.timeStepParam] ?? "\(URIFormat.defaultTimeStep)") else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(URIFormat.timeStepParam)]")
            return nil
        }
        guard let length = Int(params[URIFormat.lengthParam] ?? "\(URIFormat.defaultLength)") else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(URIFormat.lengthParam)]")
            return nil
        }
        
        return TOTPGeneratorRFC6238(
            seed: ByteArray(data: seedData),
            timeStep: timeStep,
            length: length)
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
    internal let seed: ByteArray
    internal let timeStep: Int
    internal let length: Int
    
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
