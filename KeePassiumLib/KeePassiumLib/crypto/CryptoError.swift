//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum CryptoError: LocalizedError {
    case invalidKDFParam(kdfName: String, paramName: String)
    case paddingError(code: Int)
    case aesInitError(code: Int)
    case aesEncryptError(code: Int)
    case aesDecryptError(code: Int)
    case argon2Error(code: Int)
    case twofishError(code: Int)
    case rngError(code: Int)
    public var errorDescription: String? {
        switch self {
        case .invalidKDFParam(let kdfName, let paramName):
            return NSLocalizedString(
                "Invalid KDF parameter: \(kdfName) - \(paramName). File corrupt?",
                comment: "Error message about key derivation function (KDF) parameters.")
        case .paddingError(let code):
            return NSLocalizedString(
                "Invalid data padding (code \(code)). File corrupt?",
                comment: "Error message about PKCS7 padding, with an error code.")
        case .aesInitError(let code):
            return NSLocalizedString(
                "AES initialization error (code \(code))",
                comment: "Error message about AES cipher, with an error code")
        case .aesEncryptError(let code):
            return NSLocalizedString(
                "AES encryption error (code \(code))",
                comment: "Error message about AES cipher, with an error code")
        case .aesDecryptError(let code):
            return NSLocalizedString(
                "AES decryption error (code \(code))",
                comment: "Error message about AES cipher, with an error code")
        case .argon2Error(let code):
            return NSLocalizedString(
                "Argon2 hashing error (code \(code))",
                comment: "Error message about Argon2 hashing function, with an error code")
        case .twofishError(let code):
            return NSLocalizedString(
                "Twofish cipher error (code \(code))",
                comment: "Error message about Twofish cipher, with an error code")
        case .rngError(let code):
            return NSLocalizedString(
                "Random number generator error (code \(code))",
                comment: "Error message about random number generator, with an error code")
        }
    }
}
