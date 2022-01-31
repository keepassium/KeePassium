//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

fileprivate let _textBorderColor = UIColor(white: 0.76, alpha: 1.0).cgColor

extension UITextView {
    
    public func setupBorder() {
        layer.cornerRadius = 5.0
        layer.borderWidth = 0.5
        layer.borderColor = _textBorderColor
    }
}
