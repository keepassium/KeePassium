//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

enum SettingsItem: Hashable {
    case basic(_ config: BasicCell.Config)
    case toggle(_ config: ToggleCell.Config)
    case picker(_ config: PickerCell.Config)
    case textScale(_ config: TextScaleCell.Config)

    var canBeHighlighted: Bool {
        switch self {
        case .basic:
            return true
        case .toggle:
            return false
        case .picker:
            return true
        case .textScale:
            return false
        }
    }
}
