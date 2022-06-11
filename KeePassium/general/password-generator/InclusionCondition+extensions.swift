//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
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
        let config = UIImage.SymbolConfiguration(scale: .large)
        switch self {
        case .inactive:
            return UIImage.get(.minus)?.withConfiguration(config)
                .withTintColor(.disabledText, renderingMode: .alwaysOriginal)
        case .excluded:
            return UIImage.get(.nosign)?.withConfiguration(config)
        case .allowed:
            return UIImage.get(.checkmark)?.withConfiguration(config)
        case .required:
            return UIImage.get(.asterisk)?.withConfiguration(config)
        }
    }
}
