//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices

public struct PasskeyRegistrationParams {
    public let identity: ASPasskeyCredentialIdentity
    public let userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference
    public let clientDataHash: Data
    public let supportedAlgorithms: [ASCOSEAlgorithmIdentifier]

    public init(
        identity: ASPasskeyCredentialIdentity,
        userVerificationPreference: ASAuthorizationPublicKeyCredentialUserVerificationPreference,
        clientDataHash: Data,
        supportedAlgorithms: [ASCOSEAlgorithmIdentifier]
    ) {
        assert(identity.credentialID.isEmpty, "Empty credential ID is expected for passkey registrations")
        self.identity = identity
        self.userVerificationPreference = userVerificationPreference
        self.clientDataHash = clientDataHash
        self.supportedAlgorithms = supportedAlgorithms
    }
}
