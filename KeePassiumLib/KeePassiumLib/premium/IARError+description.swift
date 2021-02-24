//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import TPInAppReceipt

extension IARError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(reason: let reason):
            return "Initialization failed. \(reason.localizedDescription)"
        case .validationFailed(reason: let reason):
            return "Validation failed. \(reason.localizedDescription)"
        case .purchaseExpired:
            return "Purchase expired."
        }
    }
}

extension IARError.ReceiptInitializationFailureReason: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .appStoreReceiptNotFound:
            return "App Store receipt not found."
        case .pkcs7ParsingError:
            return "PKCS7 parsing error."
        case .dataIsInvalid:
            return "Receipt data is invalid."
        }
    }
}

extension IARError.ValidationFailureReason: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .hashValidation:
            return "Hash validation."
        case .signatureValidation(reason: let reason):
            return "Signature validation. \(reason.localizedDescription)"
        case .bundleIdentifierVerification:
            return "Bundle identifier verification."
        case .bundleVersionVerification:
            return "Bundle version verification."
        }
    }
}

extension IARError.SignatureValidationFailureReason: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .appleIncRootCertificateNotFound:
            return "Apple Inc root certificate not found."
        case .unableToLoadAppleIncRootCertificate:
            return "Unable to load Apple Inc root certificate."
        case .unableToLoadAppleIncPublicKey:
            return "Unable to load Apple Inc public key."
        case .unableToLoadiTunesCertificate:
            return "Unable to load iTunes certificate."
        case .unableToLoadiTunesPublicKey:
            return "Unable to load iTunes public key."
        case .unableToLoadWorldwideDeveloperCertificate:
            return "Unable to load WWDC certificate."
        case .unableToLoadAppleIncPublicSecKey:
            return "Unable to load Apple Inc public sec key."
        case .receiptIsNotSigned:
            return "Receipt is not signed."
        case .receiptSignedDataNotFound:
            return "Receipt signed data not found."
        case .receiptDataNotFound:
            return "Receipt data not found."
        case .signatureNotFound:
            return "Signature not found."
        case .invalidSignature:
            return "Invalid signature."
        case .invalidCertificateChainOfTrust:
            return "Invalid certificate chain of trust."
        }
    }
}
