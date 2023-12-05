//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
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

    public static func entryTextFont(style: UIFont.TextStyle = .body) -> UIFont {
        let descriptor = Settings.current.entryTextFontDescriptor
        return monospaceFont(descriptor: descriptor, style: style)
    }

    public static func monospaceFont(
        descriptor: UIFontDescriptor? = nil,
        style: UIFont.TextStyle
    ) -> UIFont {
        let baseFont = UIFont.preferredFont(forTextStyle: style)
        let size = baseFont.pointSize

        let font: UIFont
        let weight: Weight = UIAccessibility.isBoldTextEnabled ? .bold : .regular
        if let descriptor {
            let weightTrait = [UIFontDescriptor.TraitKey.weight: weight]
            let adjustedDescriptor = descriptor.addingAttributes([.traits: weightTrait])
            font = UIFont(descriptor: adjustedDescriptor, size: size)
        } else {
            font = UIFont.monospacedSystemFont(ofSize: size, weight: weight)
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
