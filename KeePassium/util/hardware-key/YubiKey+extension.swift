//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension YubiKey {
    static func getTitle(for yubiKey: YubiKey?) -> String {
        guard let yubiKey = yubiKey else {
            return LString.noHardwareKey
        }
        return String.localizedStringWithFormat(
            LString.yubikeySlotNTemplate,
            yubiKey.slot.number
        )
    }
}
