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
    func isAcceptableDatabasePassword(length: Int, entropy: Float) -> Bool {
        var isGoodEnough = true
        if let minRequredEntropy = ManagedAppConfig.shared.minimumDatabasePasswordEntropy {
            isGoodEnough = isGoodEnough && entropy >= Float(minRequredEntropy)
        }
        if let minRequiredLength = ManagedAppConfig.shared.minimumDatabasePasswordLength {
            isGoodEnough = isGoodEnough && length >= minRequiredLength
        }
        return isGoodEnough
    }

    func isAcceptableAppPasscode(length: Int, entropy: Float) -> Bool {
        var isGoodEnough = true
        if let minRequiredEntropy = ManagedAppConfig.shared.minimumAppPasscodeEntropy {
            isGoodEnough = isGoodEnough && entropy >= Float(minRequiredEntropy)
        }
        if let minRequiredLength = ManagedAppConfig.shared.minimumAppPasscodeLength {
            isGoodEnough = isGoodEnough && length >= minRequiredLength
        }
        return isGoodEnough
    }
}
