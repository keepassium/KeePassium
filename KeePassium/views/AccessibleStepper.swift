//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class AccessibleStepper: UIStepper {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configureControl()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        configureControl()
    }

    private func configureControl() {
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
    }

    override func accessibilityIncrement() {
        value += stepValue
        sendActions(for: .valueChanged)
    }

    override func accessibilityDecrement() {
        value -= stepValue
        sendActions(for: .valueChanged)
    }
}
