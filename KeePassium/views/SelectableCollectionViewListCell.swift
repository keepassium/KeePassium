//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

class SelectableCollectionViewListCell: UICollectionViewListCell {

    override init(frame: CGRect) {
        super.init(frame: frame)
        automaticallyUpdatesContentConfiguration = false
        automaticallyUpdatesBackgroundConfiguration = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        var bgConfig = defaultBackgroundConfiguration().updated(for: state)
        bgConfig.backgroundColorTransformer = .init { color in
            if state.isFocused {
                return .focusTint
            } else if state.isHighlighted || state.isSelected {
                return .systemFill
            } else {
                return color
            }
        }
        self.backgroundConfiguration = bgConfig
    }
}
