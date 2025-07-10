//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class TOTPGeneratorFactory {

    public static func makeGenerator(for entry: Entry) -> TOTPGenerator? {
        return makeGenerator(from: entry.fields)
    }

    private static func find(_ name: String, in fields: [EntryField]) -> EntryField? {
        return fields.first(where: { $0.name == name })
    }

    public static func makeGenerator(from fields: [EntryField]) -> TOTPGenerator? {
        if let otpField = find(SingleFieldFormat.fieldName, in: fields) {
            return parseSingleFieldFormat(otpField.resolvedValue)
        }
        if let seedField = find(SplitFieldFormat.seedFieldName, in: fields) {
            return SplitFieldFormat.parse(
                seedString: seedField.resolvedValue,
                settingsString: find(SplitFieldFormat.settingsFieldName, in: fields)?.resolvedValue
            )
        }
        if let secretField = find(KeePassFormat.secretFieldName, in: fields) {
            return KeePassFormat.parse(
                secretString: secretField.resolvedValue,
                lengthString: find(KeePassFormat.lengthFieldName, in: fields)?.resolvedValue,
                periodString: find(KeePassFormat.periodFieldName, in: fields)?.resolvedValue,
                algorithmString: find(KeePassFormat.algorithmFieldName, in: fields)?.resolvedValue
            )
        }
        return nil
    }

    private static func parseSingleFieldFormat(_ paramString: String) -> TOTPGenerator? {
        let trimmedParamString = paramString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uriComponents = URLComponents(string: trimmedParamString) else {
            Diag.warning("Unexpected OTP field format")
            return nil
        }

        if GAuthFormat.isMatching(scheme: uriComponents.scheme, host: uriComponents.host) {
            return GAuthFormat.parse(uriComponents)
        }
        if KeeOtpFormat.isMatching(scheme: uriComponents.scheme, host: uriComponents.host) {
            return KeeOtpFormat.parse(paramString)
        }
        Diag.warning("Unrecognized OTP field format")
        return nil
    }

    public static func isValidURI(_ paramString: String) -> Bool {
        return parseSingleFieldFormat(paramString) != nil
    }

    public static func makeOtpauthURI(
        base32Seed seed: String,
        issuer: String?,
        accountName: String?
    ) -> URL {
        return GAuthFormat.make(base32Seed: seed, issuer: issuer, accountName: accountName)
    }
}


public extension EntryField {
    static let otpConfig1 = EntryField.otp
    static let otpConfig2Seed = SplitFieldFormat.seedFieldName
    static let otpConfig2Settings = SplitFieldFormat.settingsFieldName
    static let timeOtpSecret = KeePassFormat.secretFieldName
    static let timeOtpPeriod = KeePassFormat.periodFieldName
    static let timeOtpAlgorithm = KeePassFormat.algorithmFieldName
    static let timeOtpLength = KeePassFormat.lengthFieldName
}

private class SingleFieldFormat {
    static let fieldName = EntryField.otp
}

private class GAuthFormat: SingleFieldFormat {
    static let scheme = "otpauth"
    static let host = "totp"

    static let seedParam = "secret"
    static let timeStepParam = "period"
    static let lengthParam = "digits"
    static let algorithmParam = "algorithm"
    static let issuerParam = "issuer"
    static let encoderParam = "encoder" 

    static let defaultTimeStep = 30
    static let defaultLength = 6
    static let defaultAlgorithm = TOTPHashAlgorithm.sha1

    static func isMatching(scheme: String?, host: String?) -> Bool {
        return scheme == GAuthFormat.scheme
    }

    static func parse(_ uriComponents: URLComponents) -> TOTPGenerator? {
        guard uriComponents.scheme == scheme,
              uriComponents.host == host,
              let queryItems = uriComponents.queryItems
        else {
            Diag.warning("OTP URI has unexpected format")
            return nil
        }

        let params = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }

        guard let seedString = params[seedParam],
              let seedData = base32DecodeToData(seedString),
              !seedData.isEmpty
        else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(seedParam)]")
            return nil
        }

        guard let timeStep = Int(params[timeStepParam] ?? "\(defaultTimeStep)") else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(timeStepParam)]")
            return nil
        }

        let isSteam = uriComponents.path.starts(with: "/Steam:") ||
            (params[issuerParam] == "Steam") ||
            (params[encoderParam] == "steam")
        if isSteam {
            return TOTPGeneratorSteam(seed: ByteArray(data: seedData), timeStep: timeStep)
        }

        var algorithm: TOTPHashAlgorithm?
        if let algorithmString = params[algorithmParam] {
            guard let _algorithm = TOTPHashAlgorithm.fromString(algorithmString) else {
                Diag.warning("OTP algorithm is not supported [algorithm: \(algorithmString)]")
                return nil
            }
            algorithm = _algorithm
        }

        guard let length = Int(params[lengthParam] ?? "\(defaultLength)") else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(lengthParam)]")
            return nil
        }

        return TOTPGeneratorRFC6238(
            seed: ByteArray(data: seedData),
            timeStep: timeStep,
            length: length,
            hashAlgorithm: algorithm ?? defaultAlgorithm)
    }

    static func make(base32Seed: String, issuer: String?, accountName: String?) -> URL {
        var components = URLComponents()
        components.scheme = GAuthFormat.scheme
        components.host = GAuthFormat.host
        components.queryItems = [
            URLQueryItem(
                name: GAuthFormat.seedParam,
                value: base32Seed),
            URLQueryItem(
                name: GAuthFormat.timeStepParam,
                value: String(GAuthFormat.defaultTimeStep)),
            URLQueryItem(
                name: GAuthFormat.lengthParam,
                value: String(GAuthFormat.defaultLength)),
            URLQueryItem(
                name: GAuthFormat.algorithmParam,
                value: GAuthFormat.defaultAlgorithm.asString)
        ]

        if let accountName, accountName.isNotEmpty {
            let sanitizedAccountName = accountName.replacingOccurrences(of: ":", with: "_")
            if let issuer, issuer.isNotEmpty {
                let sanitizedIssuer = issuer.replacingOccurrences(of: ":", with: "_")
                components.queryItems?.append(
                    URLQueryItem(name: GAuthFormat.issuerParam, value: sanitizedIssuer)
                )
                components.path = "/" + sanitizedIssuer + ":" + sanitizedAccountName
            } else {
                components.path = "/" + sanitizedAccountName
            }
        }
        return components.url!
    }
}

private class KeeOtpFormat: SingleFieldFormat {
    static let seedParam = "key"
    static let timeStepParam = "step"
    static let lengthParam = "size"
    static let typeParam = "type"
    static let algorithmParam = "otpHashMode"

    static let defaultTimeStep = 30
    static let defaultLength = 6
    static let defaultAlgorithm = TOTPHashAlgorithm.sha1
    static let supportedType = "totp"

    static func isMatching(scheme: String?, host: String?) -> Bool {
        return (scheme == nil) && (host == nil)
    }

    static func parse(_ paramString: String) -> TOTPGenerator? {
        guard let uriComponents = URLComponents(string: "fakeScheme://fakeHost?" + paramString),
              let queryItems = uriComponents.queryItems
        else {
            return nil
        }

        let params = queryItems.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        }

        guard let seedString = params[seedParam],
              let seedData = base32DecodeToData(seedString),
              !seedData.isEmpty
        else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(seedParam)]")
            return nil
        }

        if let type = params[typeParam],
           type.caseInsensitiveCompare(supportedType) != .orderedSame
        {
            Diag.warning("OTP type is not suppoorted [type: \(type)]")
            return nil
        }

        var algorithm: TOTPHashAlgorithm?
        if let algorithmString = params[algorithmParam] {
            guard let _algorithm = TOTPHashAlgorithm.fromString(algorithmString) else {
                Diag.warning("OTP algorithm is not supported [algorithm: \(algorithmString)]")
                return nil
            }
            algorithm = _algorithm
        }

        guard let timeStep = Int(params[timeStepParam] ?? "\(defaultTimeStep)") else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(timeStepParam)]")
            return nil
        }

        guard let length = Int(params[lengthParam] ?? "\(defaultLength)") else {
            Diag.warning("OTP parameter cannot be parsed [parameter: \(lengthParam)]")
            return nil
        }

        return TOTPGeneratorRFC6238(
            seed: ByteArray(data: seedData),
            timeStep: timeStep,
            length: length,
            hashAlgorithm: algorithm ?? defaultAlgorithm)
    }
}

private class SplitFieldFormat {
    static let seedFieldName = "TOTP Seed"
    static let settingsFieldName = "TOTP Settings"
    static let defaultSettingsValue = "30;6"

    static func parse(seedString: String, settingsString: String?) -> TOTPGenerator? {
        guard let seed = parseSeedString(seedString) else {
            Diag.warning("Unrecognized TOTP seed format")
            return nil
        }

        let settingsString = settingsString ?? SplitFieldFormat.defaultSettingsValue
        let settings = settingsString.split(separator: ";")
        if settings.count > 2 {
            Diag.verbose("Found redundant TOTP settings, ignoring [expected: 2, got: \(settings.count)]")
        } else if settings.count < 2 {
            Diag.warning("Insufficient TOTP settings number [expected: 2, got: \(settings.count)]")
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
            return TOTPGeneratorRFC6238(
                seed: seed,
                timeStep: timeStep,
                length: length,
                hashAlgorithm: .sha1
            )
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

private class KeePassFormat {
    static let secretFieldName = "TimeOtp-Secret-Base32"
    static let lengthFieldName = "TimeOtp-Length"
    static let periodFieldName = "TimeOtp-Period"
    static let algorithmFieldName = "TimeOtp-Algorithm"

    private static let defaultLengthValue = 6
    private static let defaultPeriodValue = 30
    private static let defaultAlgorithmValue: TOTPHashAlgorithm = .sha1

    static func parse(
        secretString: String,
        lengthString: String?,
        periodString: String?,
        algorithmString: String?
    ) -> TOTPGenerator? {
        let cleanedSecretString = secretString.trimmingCharacters(in: .whitespaces)
        guard let seedData = base32DecodeToData(cleanedSecretString) else {
            return nil
        }

        let seed = ByteArray(data: seedData)
        let timeStep = periodString.flatMap({ Int($0) }) ?? Self.defaultPeriodValue
        let length = lengthString.flatMap({ Int($0) }) ?? Self.defaultLengthValue
        let algorithm = algorithmString.flatMap {
            switch $0 {
            case "HMAC-SHA-1":
                return .sha1
            case "HMAC-SHA-256":
                return .sha256
            case "HMAC-SHA-512":
                return .sha512
            default:
                Diag.error("Unknown TimeOtp-Algorithm [value: \($0)]")
                return nil
            }
        } ?? defaultAlgorithmValue

        return TOTPGeneratorRFC6238(
            seed: seed,
            timeStep: timeStep,
            length: length,
            hashAlgorithm: algorithm
        )
    }
}
