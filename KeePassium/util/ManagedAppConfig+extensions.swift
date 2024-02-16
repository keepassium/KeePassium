//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import Zxcvbn

private let zxcvbn = DBZxcvbn()

extension ManagedAppConfig {
    
    func isAcceptable(databasePassword: String) -> Bool {
        guard let minRequredEntropy = ManagedAppConfig.shared.minimumDatabasePasswordEntropy else {
            return true
        }
        guard let entropyString = zxcvbn.passwordStrength(databasePassword).entropy,
              let entropy = Float(entropyString)
        else {
            Diag.warning("Failed to estimate password complexity")
            assertionFailure()
            return false
        }
        return entropy >= Float(minRequredEntropy)
    }

    func isAcceptable(appPasscode: String) -> Bool {
        guard let minRequiredEntropy = ManagedAppConfig.shared.minimumAppPasscodeEntropy else {
            return true
        }
        guard let entropyString = zxcvbn.passwordStrength(appPasscode).entropy,
              let entropy = Float(entropyString)
        else {
            Diag.warning("Failed to estimate passcode complexity")
            assertionFailure()
            return false
        }
        return entropy >= Float(minRequiredEntropy)
    }
}
