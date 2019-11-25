//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UILabel {
    
    public func setText(_ text: String?, strikethrough: Bool) {
        if let text = text, strikethrough {
            let attributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: self.font,
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: self.textColor.withAlphaComponent(0.7)])
            self.attributedText = attributedText
        } else {
            self.attributedText = nil
            self.text = text
        }
    }
}
