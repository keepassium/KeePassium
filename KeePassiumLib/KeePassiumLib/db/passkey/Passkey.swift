//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices
import CryptoKit
import Foundation
import OSLog
import SwiftCBOR

enum PasskeyRegistrationError: LocalizedError {
    case unsupportedAlgorithm

    var errorDescription: String? {
        switch self {
        case .unsupportedAlgorithm:
            return NSLocalizedString(
                "[Database/Passkey/Error/UnsupportedAlgorithm/description]",
                bundle: Bundle.framework,
                value: "Unsupported passkey algorithm",
                comment: "Error message about creation of a new passkey.")
        }
    }
}

public class Passkey {
    let log = Logger(subsystem: "com.keepassium.autofill", category: "Passkey")

    enum AuthDataFlags {
        static let up: UInt8   = 0x01
        static let rfu1: UInt8 = 0x02
        static let uv: UInt8   = 0x04
        static let be: UInt8   = 0x08
        static let bs: UInt8   = 0x10
        static let rfu2: UInt8 = 0x20
        static let at: UInt8   = 0x40
        static let ed: UInt8   = 0x80
    }

    let credentialID: Data
    private(set) var privateKeyPEM: String
    public let relyingParty: String
    public let username: String
    let userHandle: Data

    init(
        credentialID: Data,
        privateKeyPEM: String,
        relyingParty: String,
        username: String,
        userHandle: Data
    ) {
        self.credentialID = credentialID
        self.privateKeyPEM = privateKeyPEM
        self.relyingParty = relyingParty
        self.username = username
        self.userHandle = userHandle
    }

    public static func make(from entry: Entry) -> Passkey? {
        guard let entry2 = entry as? Entry2 else { return nil }

        guard let credentialIDString = entry2.getField(EntryField.passkeyCredentialID)?.resolvedValue,
              let privateKeyPEM = entry2.getField(EntryField.passkeyPrivateKeyPEM)?.resolvedValue,
              let relyingParty = entry2.getField(EntryField.passkeyRelyingParty)?.resolvedValue,
              let userHandleString = entry2.getField(EntryField.passkeyUserHandle)?.resolvedValue,
              let username = entry2.getField(EntryField.passkeyUsername)?.resolvedValue
        else {
            return nil
        }

        guard let credentialID = Data(base64URLEncoded: credentialIDString),
              let userHandle = Data(base64URLEncoded: userHandleString)
        else {
            Diag.error("Failed to parse Base64URL encoded data")
            assertionFailure()
            return nil
        }

        return Passkey(
            credentialID: credentialID,
            privateKeyPEM: privateKeyPEM,
            relyingParty: relyingParty,
            username: username,
            userHandle: userHandle
        )
    }

    public static func probablyPresent(in entry: Entry) -> Bool {
        guard let entry2 = entry as? Entry2 else { return false }

        guard let credentialID = entry2.getField(EntryField.passkeyCredentialID)?.resolvedValue,
              let privateKeyPEM = entry2.getField(EntryField.passkeyPrivateKeyPEM)?.resolvedValue,
              let relyingParty = entry2.getField(EntryField.passkeyRelyingParty)?.resolvedValue,
              let userHandle = entry2.getField(EntryField.passkeyUserHandle)?.resolvedValue,
              let username = entry2.getField(EntryField.passkeyUsername)?.resolvedValue
        else {
            return false
        }

        guard credentialID.isNotEmpty,
              privateKeyPEM.isNotEmpty,
              relyingParty.isNotEmpty,
              userHandle.isNotEmpty,
              username.isNotEmpty
        else {
            return false
        }
        return true
    }

    public func asCredentialIdentity(recordIdentifier: String?) -> ASPasskeyCredentialIdentity {
        return ASPasskeyCredentialIdentity(
            relyingPartyIdentifier: relyingParty,
            userName: username,
            credentialID: credentialID,
            userHandle: userHandle,
            recordIdentifier: recordIdentifier)
    }

    public func apply(to entry: Entry2) {
        entry.setField(
            name: EntryField.passkeyCredentialID,
            value: credentialID.base64URLEncodedString(),
            isProtected: true)
        entry.setField(
            name: EntryField.passkeyPrivateKeyPEM,
            value: privateKeyPEM,
            isProtected: true)
        entry.setField(
            name: EntryField.passkeyRelyingParty,
            value: relyingParty,
            isProtected: false)
        entry.setField(
            name: EntryField.passkeyUserHandle,
            value: userHandle.base64URLEncodedString(),
            isProtected: true)
        entry.setField(
            name: EntryField.passkeyUsername,
            value: username,
            isProtected: false)
    }
}

extension Passkey {
    public func makeAssertionCredential(clientDataHash: Data) -> ASPasskeyAssertionCredential? {
        let authenticatorData = getAuthenticatorData()
        let challenge = authenticatorData + clientDataHash

        guard let signature = signWithPrivateKey(challenge) else {
            return nil
        }

        let assertion = ASPasskeyAssertionCredential(
            userHandle: userHandle,
            relyingParty: relyingParty,
            signature: signature,
            clientDataHash: clientDataHash,
            authenticatorData: authenticatorData,
            credentialID: credentialID
        )
        return assertion
    }

    private func getAuthenticatorData() -> Data {
        let rpIDHash = relyingParty.utf8data.sha256.asData

        let flags = AuthDataFlags.uv | AuthDataFlags.up | AuthDataFlags.be | AuthDataFlags.bs

        let counter = Data(repeating: 0, count: 4)

        var result = Data()
        result.append(rpIDHash)
        result.append(flags)
        result.append(counter)
        assert(result.count == 37)

        return result
    }

    private func signWithPrivateKey(_ challenge: Data) -> Data? {
        return signUsingES256(challenge) ?? signUsingEd25519(challenge)
    }

    private func signUsingES256(_ challenge: Data) -> Data? {
        let privateKey: P256.Signing.PrivateKey
        do {
            privateKey = try P256.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        } catch {
            let message = (error as NSError).debugDescription
            log.debug("Failed to parse as ES256 private key: \(message, privacy: .public)")
            Diag.debug("Failed to parse as ES256 private key [message: \(message)]")
            return nil
        }

        do {
            let signature = try privateKey.signature(for: challenge)
            log.debug("Signed with ES256")
            Diag.debug("Signed with ES256")
            return signature.derRepresentation
        } catch {
            let message = (error as NSError).debugDescription
            log.error("Failed to sign using ES256: \(message, privacy: .public)")
            Diag.error("Failed to sign using ES256 [message: \(message)]")
            return nil
        }
    }

    private func signUsingEd25519(_ challenge: Data) -> Data? {
        let privateKey: Curve25519.Signing.PrivateKey
        do {
            privateKey = try Curve25519.Signing.PrivateKey(pemRepresentation: privateKeyPEM)
        } catch {
            let message = (error as NSError).debugDescription
            log.debug("Failed to parse as EdDSA private key: \(message, privacy: .public)")
            Diag.debug("Failed to parse as EdDSA private key [message: \(message)]")
            return nil
        }
        do {
            let signature = try privateKey.signature(for: challenge)
            log.debug("Signed with EdDSA")
            Diag.debug("Signed with EdDSA")
            return signature
        } catch {
            let message = (error as NSError).debugDescription
            log.error("Failed to sign using EdDSA: \(message, privacy: .public)")
            Diag.error("Failed to sign using EdDSA [message: \(message)]")
            return nil
        }
    }
}

public class NewPasskey: Passkey {
    let aaguid = UUID(uuidString: "23A349A8-0DD1-49C3-8B00-5D36FA3B3C03")!

    private let privateKey: P256.Signing.PrivateKey
    private let credentialIDSizeInBytes = 32
    private let publicKeySizeInBytes = 64

    fileprivate init(
        relyingParty: String,
        username: String,
        userHandle: Data
    ) {
        self.privateKey = P256.Signing.PrivateKey()
        let credentialID = (try? CryptoManager.getRandomBytes(count: credentialIDSizeInBytes).asData) ?? Data()
        super.init(
            credentialID: credentialID,
            privateKeyPEM: privateKey.pemRepresentation,
            relyingParty: relyingParty,
            username: username,
            userHandle: userHandle
        )
    }

    public static func make(with params: PasskeyRegistrationParams) throws -> NewPasskey {
        guard params.supportedAlgorithms.contains(.ES256) else {
            Diag.error("Supported algorithms do not include ES256, cancelling")
            throw PasskeyRegistrationError.unsupportedAlgorithm
        }
        return NewPasskey(
            relyingParty: params.identity.relyingPartyIdentifier,
            username: params.identity.userName,
            userHandle: params.identity.userHandle)
    }

    public func makeRegistrationCredential(clientDataHash: Data) -> ASPasskeyRegistrationCredential {
        let attestationObject = makeAttestationObject()
        let credential = ASPasskeyRegistrationCredential(
            relyingParty: relyingParty,
            clientDataHash: clientDataHash,
            credentialID: credentialID,
            attestationObject: attestationObject)
        return credential
    }

    private func makeAttestationObject() -> Data {
        var authData = Data()
        let rpIdHash = CryptoKit.SHA256.hash(data: relyingParty.data(using: .utf8)!)
        authData.append(contentsOf: rpIdHash)

        let flags = AuthDataFlags.at
                  | AuthDataFlags.uv
                  | AuthDataFlags.up
                  | AuthDataFlags.be
                  | AuthDataFlags.bs
        authData.append(flags)

        authData.append(contentsOf: UInt32(0).bigEndian.bytes)

        authData.append(contentsOf: aaguid.data.asData)
        authData.append(contentsOf: UInt16(credentialID.count).bigEndian.bytes)
        authData.append(contentsOf: credentialID.bytes)
        let encodedPublicKey = cborEncodePublicKey(privateKey.publicKey)
        authData.append(contentsOf: encodedPublicKey)
        let attestationObject = cborEncodeAttestation(authData)
        return attestationObject
    }

    private func cborEncodePublicKey(_ publicKey: P256.Signing.PublicKey) -> Data {
        let rawPublicKey = publicKey.rawRepresentation
        guard rawPublicKey.count == publicKeySizeInBytes else {
            Diag.error("Unexpected public key size: \(rawPublicKey.count)")
            log.error("Unexpected public key size")
            assertionFailure()
            return Data()
        }

        let x = Array(rawPublicKey.prefix(upTo: 33))
        let y = Array(rawPublicKey.suffix(32))
        let dict: CBOR = [
            1: CBOR(integerLiteral: 2),
            3: CBOR(integerLiteral: ASCOSEAlgorithmIdentifier.ES256.rawValue),
            -1: CBOR(integerLiteral: ASCOSEEllipticCurveIdentifier.P256.rawValue),
            -2: CBOR.byteString(x),
            -3: CBOR.byteString(y)
        ]
        let encoded = Data(dict.encode())
        return encoded
    }

    private func cborEncodeAttestation(_ authData: Data) -> Data {
        let dict: CBOR = [
            "fmt": "none",
            "attStmt": CBOR.map([:]),
            "authData": CBOR.byteString(authData.bytes)
        ]
        let encoded = dict.encode()
        return Data(encoded)
    }
}
