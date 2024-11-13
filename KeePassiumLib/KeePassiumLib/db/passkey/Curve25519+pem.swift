//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import CryptoKit
import Foundation
import OSLog

private let log = Logger(subsystem: "com.keepassium.crypto", category: "Curve25519PEMParser")
private let pemHeader = "-----BEGIN PRIVATE KEY-----"
private let pemFooter = "-----END PRIVATE KEY-----"

private let rawPrivateKeySize = 32

private let privateKeyASN1Prefix = Data(
// swiftlint:disable collection_alignment
    [0x30, 0x2E,
        0x02, 0x01, 0x00,
        0x30, 0x05,
            0x06, 0x03,
                0x2B, 0x65, 0x70,
        0x04, 0x22,
            0x04, 0x20
    ])
// swiftlint:enable collection_alignment

extension Curve25519.Signing.PrivateKey {
    init(pemRepresentation pem: String) throws {
        let pem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pem.hasPrefix(pemHeader),
              pem.hasSuffix(pemFooter)
        else {
            log.debug("Missing PEM header/footer")
            throw CryptoKitError.invalidParameter
        }
        let noisyBase64String = pem
            .dropFirst(pemHeader.count)
            .dropLast(pemFooter.count)

        guard let asn1Data = Data(base64Encoded: String(noisyBase64String), options: .ignoreUnknownCharacters)
        else {
            log.debug("Failed to parse Base64 data")
            throw CryptoKitError.invalidParameter
        }

        guard asn1Data.starts(with: privateKeyASN1Prefix) else {
            log.debug("ASN1 does not match the expected prefix")
            throw CryptoKitError.invalidParameter
        }
        let rawKeyRepresentation = asn1Data.dropFirst(privateKeyASN1Prefix.count)
        guard rawKeyRepresentation.count == rawPrivateKeySize else {
            log.debug("Unexpected raw key size: \(rawKeyRepresentation.count)")
            throw CryptoKitError.incorrectKeySize
        }

        try self.init(rawRepresentation: rawKeyRepresentation)
    }
}
