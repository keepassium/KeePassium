//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AuthenticationServices

extension ASCredentialRequestType: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case .password:
            return "password"
        case .oneTimeCode:
            return "oneTimeCode"
        case .passkeyAssertion:
            return  "passkeyAssertion"
        case .passkeyRegistration:
            return "passkeyRegistration"
        default:
            return "(?)"
        }
    }
}
