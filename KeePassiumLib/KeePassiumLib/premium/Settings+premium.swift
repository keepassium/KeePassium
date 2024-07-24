//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public extension Settings {
    var premiumIsQuickTypeEnabled: Bool {
        let actualValue = Settings.current.isQuickTypeEnabled
        if PremiumManager.shared.isAvailable(feature: .canUseQuickTypeAutoFill) {
            return actualValue
        } else {
            return false
        }
    }
}
