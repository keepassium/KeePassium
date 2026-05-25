//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import TPInAppReceipt

extension AppReceiptError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .appStoreReceiptNotFound:
            return "App Store receipt not found."
        case .receiptContentInvalid(let error):
            return "Receipt content invalid. \(error.localizedDescription)"
        case .receiptPayloadMissingOrInvalid:
            return "Receipt payload missing or invalid."
        case .decodingFailed(let error):
            return "Receipt decoding failed. \(error.localizedDescription)"
        }
    }
}

extension ChainVerificationError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidCertificateData:
            return "Invalid certificate data."
        case .chainValidationFailed:
            return "Certificate chain validation failed."
        case .revocationCheckFailed:
            return "Certificate revocation check failed."
        }
    }
}

extension SignatureVerificationError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Invalid signature key."
        case .invalidSignature:
            return "Invalid signature."
        }
    }
}

extension HashVerificationError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingDeviceIdentifier:
            return "Missing device identifier."
        case .hashMismatch:
            return "Receipt hash mismatch."
        }
    }
}

extension MetaVerificationError: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .bundleIdentifierMismatch:
            return "Bundle identifier mismatch."
        case .versionIdentifierMismatch:
            return "Bundle version mismatch."
        case .bundleInfoUnavailable:
            return "Bundle info unavailable."
        }
    }
}
