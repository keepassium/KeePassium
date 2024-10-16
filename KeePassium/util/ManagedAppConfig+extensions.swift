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
    func isAcceptableDatabasePassword(entropy: Float) -> Bool {
        guard let minRequredEntropy = ManagedAppConfig.shared.minimumDatabasePasswordEntropy else {
            return true
        }
        return entropy >= Float(minRequredEntropy)
    }

    func isAcceptableAppPasscode(entropy: Float) -> Bool {
        guard let minRequiredEntropy = ManagedAppConfig.shared.minimumAppPasscodeEntropy else {
            return true
        }
        return entropy >= Float(minRequiredEntropy)
    }
}
