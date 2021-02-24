//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UITableViewCell {
    
    func setEnabled(_ isEnabled: Bool) {
        let alpha: CGFloat = isEnabled ? 1.0 : 0.43
        contentView.alpha = alpha
        isUserInteractionEnabled = isEnabled
        if isEnabled {
            accessibilityTraits.remove(.notEnabled)
        } else {
            accessibilityTraits.insert(.notEnabled)
        }
    }
}
