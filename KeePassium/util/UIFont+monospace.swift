//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIFont {
    public static func systemFont(
        forTextStyle style: UIFont.TextStyle,
        weight: UIFont.Weight = .regular)
        -> UIFont
    {
        let font = UIFont.systemFont(ofSize: 17, weight: weight)
        let fontMetrics = UIFontMetrics(forTextStyle: style)
        return fontMetrics.scaledFont(for: font)
    }
    
    public static func monospaceFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        let font = UIFont(name: "Menlo", size: 17) ?? UIFont.systemFont(ofSize: 17)
        let fontMetrics = UIFontMetrics(forTextStyle: style)
        return fontMetrics.scaledFont(for: font)
    }
}
