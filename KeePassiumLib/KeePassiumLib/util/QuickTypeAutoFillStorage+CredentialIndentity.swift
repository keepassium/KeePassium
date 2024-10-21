//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices
import Foundation

protocol CredentialIdentity {}

extension ASPasswordCredentialIdentity: CredentialIdentity {}

@available(iOS 18.0, *)
extension ASOneTimeCodeCredentialIdentity: CredentialIdentity {}

extension ASCredentialIdentityStore {
    func replaceCredentialIdentities(
        with newCredentialIdentities: [CredentialIdentity],
        completion: ((Bool, (any Error)?) -> Void)? = nil
    ) {
        if #available(iOS 18.0, *) {
            let credentialIndentities = newCredentialIdentities.compactMap({ $0 as? ASCredentialIdentity })
            replaceCredentialIdentities(credentialIndentities, completion: completion)
        } else {
            let credentialIndentities = newCredentialIdentities.compactMap({ $0 as? ASPasswordCredentialIdentity })
            replaceCredentialIdentities(with: credentialIndentities, completion: completion)
        }
    }

    func saveCredentialIdentities(
        _ credentialIdentities: [CredentialIdentity],
        completion: ((Bool, (any Error)?) -> Void)? = nil
    ) {
        if #available(iOS 18.0, *) {
            let credentialIdentities = credentialIdentities.compactMap({ $0 as? ASCredentialIdentity })
            saveCredentialIdentities(credentialIdentities, completion: completion)
        } else {
            let credentialIdentities = credentialIdentities.compactMap({ $0 as? ASPasswordCredentialIdentity })
            saveCredentialIdentities(credentialIdentities, completion: completion)
        }
    }
}
