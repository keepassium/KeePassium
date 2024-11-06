//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices
import Foundation

final class CredentialProviderIdentity: NSObject {
    let recordIdentifier: String?
    let serviceIdentifier: ASCredentialServiceIdentifier

    init(_ password: ASPasswordCredentialIdentity) {
        self.recordIdentifier = password.recordIdentifier
        self.serviceIdentifier = password.serviceIdentifier
        super.init()
    }

    init(_ credential: ASCredentialIdentity) {
        self.recordIdentifier = credential.recordIdentifier
        self.serviceIdentifier = credential.serviceIdentifier
        super.init()
    }
}
