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
        ofSize size: CGFloat = 17,
        forTextStyle style: UIFont.TextStyle,
        weight: UIFont.Weight = .regular)
        -> UIFont
    {
        var font: UIFont
        if UIAccessibility.isBoldTextEnabled {
            font = UIFont.boldSystemFont(ofSize: size)
        } else {
            font = UIFont.systemFont(ofSize: size, weight: weight)
        }
        let fontMetrics = UIFontMetrics(forTextStyle: style)
        return fontMetrics.scaledFont(for: font)
    }
    
    public static func monospaceFont(
        ofSize size: CGFloat = 17,
        forTextStyle style: UIFont.TextStyle)
        -> UIFont
    {
        var font: UIFont
        if #available(iOS 13, *) {
            let weight: Weight = UIAccessibility.isBoldTextEnabled ? .bold : .regular
            font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            if UIAccessibility.isBoldTextEnabled {
                font = UIFont(name: "Menlo-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
            } else {
                font = UIFont(name: "Menlo", size: size) ?? UIFont.systemFont(ofSize: size)
            }
        }
        let fontMetrics = UIFontMetrics(forTextStyle: style)
        return fontMetrics.scaledFont(for: font)
    }
}
