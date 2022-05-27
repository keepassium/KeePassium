//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIFont {
    public func withWeight(_ weight: Weight) -> UIFont {
        let traits = [UIFontDescriptor.TraitKey.weight: weight]
        let attributes = [UIFontDescriptor.AttributeName.traits: traits]
        let newDescriptor = fontDescriptor.addingAttributes(attributes)
        return UIFont(descriptor: newDescriptor, size: 0) 
    }
    
    public func withRelativeSize(_ scale: CGFloat) -> UIFont {
        let scaledSize = pointSize * scale
        return self.withSize(scaledSize)
    }
    
    public static func monospaceFont(forTextStyle style: UIFont.TextStyle) -> UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: style)
        let size = baseFont.pointSize

        var font: UIFont
        if #available(iOS 13, *) {
            let weight: Weight = UIAccessibility.isBoldTextEnabled ? .bold : .regular
            font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
        } else {
            if UIAccessibility.isBoldTextEnabled {
                font = UIFont(name: "Menlo-Bold", size: size) ?? UIFont.boldSystemFont(ofSize: size)
            } else {
                font = UIFont(name: "Menlo", size: size) ?? baseFont
            }
        }
        let fontMetrics = UIFontMetrics(forTextStyle: style)
        return fontMetrics.scaledFont(for: font)
    }
    
    func addingTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        var currentTraits = self.fontDescriptor.symbolicTraits
        currentTraits.update(with: traits)
        guard let newDescriptor = fontDescriptor.withSymbolicTraits(currentTraits) else {
            return self
        }
        return UIFont(descriptor: newDescriptor, size: 0) 
    }
}
