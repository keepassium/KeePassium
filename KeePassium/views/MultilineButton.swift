//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class MultilineButton: UIButton {
    override var canBecomeFocused: Bool { isEnabled }
    
    #if targetEnvironment(macCatalyst)
    @available(iOS 15, *)
    override var focusEffect: UIFocusEffect? {
        get {
            UIFocusHaloEffect(
                roundedRect: bounds.insetBy(dx: -2, dy: -2),
                cornerRadius: cornerRadius,
                curve: .circular)
        }
        set {
        }
    }
    #endif
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel?.lineBreakMode = .byWordWrapping
        titleLabel?.numberOfLines = 0
    }
}
