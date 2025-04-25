//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

class BasicCell: UICollectionViewListCell {
    typealias Handler = () -> Void
    private var handler: Handler?

    class func makeRegistration<CellType: BasicCell>()
        -> UICollectionView.CellRegistration<CellType, SettingsItem>
    {
        return  UICollectionView.CellRegistration<CellType, SettingsItem> {
            cell, indexPath, item in
            guard case let .navigation(itemConfig) = item else { assertionFailure(); return }
            cell.configure(with: itemConfig)
        }
    }

    func configure(with itemConfig: Config) {
        self.handler = itemConfig.handler

        var contentConfig = UIListContentConfiguration.cell()
        contentConfig.text = itemConfig.title
        contentConfig.secondaryText = itemConfig.subtitle
        contentConfig.image = itemConfig.image

        if itemConfig.isButton {
            contentConfig.textProperties.color = .actionTint
            contentConfig.textProperties.colorTransformer = .init { color in
                return itemConfig.isEnabled ? color : .disabledText
            }
            accessories = []
        } else {
            accessories = [.disclosureIndicator()]
        }
        self.contentConfiguration = contentConfig

        isUserInteractionEnabled = itemConfig.isEnabled
    }
}

extension BasicCell {
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(didPressEnter)),
        ]
    }

    @objc private func didPressEnter(_ sender: Any) {
        handler?()
    }
}

extension BasicCell {
    final class Config: SettingsItemConfig {
        var handler: Handler?
        var isButton: Bool

        init(
            title: String,
            subtitle: String? = nil,
            image: UIImage? = nil,
            isEnabled: Bool = true,
            isButton: Bool = false,
            handler: Handler?
        ) {
            self.handler = handler
            self.isButton = isButton
            super.init(title: title, subtitle: subtitle, image: image, isEnabled: isEnabled)
        }
    }
}
