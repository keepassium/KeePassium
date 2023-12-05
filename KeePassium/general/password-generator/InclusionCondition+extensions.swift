//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension InclusionCondition {

    var glyphSymbol: String {
        switch self {
        case .inactive:
            return "−"
        case .excluded:
            return "✕"
        case .allowed:
            return "✓"
        case .required:
            return "﹡"
        }
    }

    var image: UIImage? {
        switch self {
        case .inactive:
            return .symbol(.minus, tint: .disabledText)
        case .excluded:
            return .symbol(.nosign)
        case .allowed:
            return .symbol(.checkmark)
        case .required:
            return .symbol(.asterisk)
        }
    }
}
