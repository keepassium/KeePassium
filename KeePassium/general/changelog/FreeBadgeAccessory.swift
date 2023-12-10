//  KeePassium Password Manager
//  Copyright © 2018-2023 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

final class FreeBadgeAccessory: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        font = UIFont.preferredFont(forTextStyle: .callout)
        adjustsFontForContentSizeCategory = true
        textColor = .auxiliaryText
        text = LString.premiumFreePlanPrice
    }
}
