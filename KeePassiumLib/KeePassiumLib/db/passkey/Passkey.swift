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

public final class Passkey {
    let log = Logger(subsystem: "com.keepassium.autofill", category: "Passkey")

    enum AuthenticatorDataFlags {
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
    let privateKeyPEM: String
    let relyingParty: String
    let username: String
    let userHandle: Data

    private init(
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

    public func asCredentialIdentity(recordIdentifier: String?) -> ASPasskeyCredentialIdentity {
        return ASPasskeyCredentialIdentity(
            relyingPartyIdentifier: relyingParty,
            userName: username,
            credentialID: credentialID,
            userHandle: userHandle,
            recordIdentifier: recordIdentifier)
    }

    public func makeCredential(clientDataHash: Data) -> ASPasskeyAssertionCredential? {

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

        let flags = AuthenticatorDataFlags.uv | AuthenticatorDataFlags.up

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
