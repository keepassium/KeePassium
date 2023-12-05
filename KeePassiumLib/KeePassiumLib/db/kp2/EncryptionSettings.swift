//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public struct EncryptionSettings: Equatable {
    public enum DataCipherType: CaseIterable, CustomStringConvertible {
        case aes
        case twofish
        case chaCha20

        var cipher: DataCipher {
            switch self {
            case .aes:
                return AESDataCipher()
            case .twofish:
                return TwofishDataCipher(isPaddingLikelyMessedUp: true)
            case .chaCha20:
                return ChaCha20DataCipher()
            }
        }

        public var description: String {
            switch self {
            case .aes:
                return "AES 256-bit"
            case .twofish:
                return "Twofish 256-bit"
            case .chaCha20:
                return "ChaCha20 256-bit"
            }
        }
    }

    public enum KeyDerivationFunctionType: CaseIterable, CustomStringConvertible {
        case argon2d
        case argon2id
        case aesKdf

        var function: KeyDerivationFunction {
            switch self {
            case .aesKdf:
                return AESKDF()
            case .argon2d:
                return Argon2dKDF()
            case .argon2id:
                return Argon2idKDF()
            }
        }

        public var description: String {
            switch self {
            case .argon2d:
                return "Argon2d"
            case .argon2id:
                return "Argon2id"
            case .aesKdf:
                return "AES-KDF"
            }
        }
    }

    public var dataCipher: DataCipherType
    public var kdf: KeyDerivationFunctionType
    public var iterations: UInt64?
    public var memory: UInt64?
    public var parallelism: UInt32?

    init(header: Header2) {
        switch header.dataCipher {
        case is ChaCha20DataCipher:
            dataCipher = .chaCha20
        case is TwofishDataCipher:
            dataCipher = .twofish
        case is AESDataCipher:
            dataCipher = .aes
        default:
            fatalError("Unknown data cipher")
        }

        switch header.kdf {
        case is AESKDF:
            kdf = .aesKdf
        case is Argon2dKDF:
            kdf = .argon2d
        case is Argon2idKDF:
            kdf = .argon2id
        default:
            fatalError("Unknown KDF")
        }

        header.kdf.parseParams(header.kdfParams, to: &self)
    }

    init(
        dataCipher: EncryptionSettings.DataCipherType,
        kdf: EncryptionSettings.KeyDerivationFunctionType,
        iterations: UInt64?,
        memory: UInt64?,
        parallelism: UInt32?
    ) {
        self.dataCipher = dataCipher
        self.kdf = kdf
        self.iterations = iterations
        self.memory = memory
        self.parallelism = parallelism
    }

    public static let `default`: Self = EncryptionSettings(
        dataCipher: .chaCha20,
        kdf: .argon2d,
        iterations: 100,
        memory: 1 * 1024 * 1024,
        parallelism: 2
    )
}
