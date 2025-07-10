//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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
            guard case let .basic(itemConfig) = item else { assertionFailure(); return }
            cell.configure(with: itemConfig)
        }
    }

    func configure(with itemConfig: Config) {
        self.handler = itemConfig.handler

        var content: UIListContentConfiguration
        if itemConfig.decorators.contains(.value) {
            content = UIListContentConfiguration.valueCell()
        } else {
            content = UIListContentConfiguration.cell()
        }
        content.text = itemConfig.title
        content.secondaryText = itemConfig.subtitle
        content.image = itemConfig.image

        content.textProperties.font = .preferredFont(forTextStyle: .body)
        if itemConfig.decorators.contains(.action) {
            content.textProperties.color = .actionTint
            content.textProperties.colorTransformer = .init { color in
                return itemConfig.isEnabled ? color : .disabledText
            }
        }
        if itemConfig.decorators.contains(.destructive) {
            content.textProperties.color = .destructiveTint
            content.textProperties.colorTransformer = .init { color in
                return itemConfig.isEnabled ? color : .disabledText
            }
        }
        content.secondaryTextProperties.color = .secondaryLabel
        self.contentConfiguration = content

        var accessories = itemConfig.fixedAccessories
        if itemConfig.needsPremium {
            let badge = PremiumBadgeAccessory()
            let premiumAccessory = UICellAccessory.customView(
                configuration: .init(customView: badge, placement: .trailing())
            )
            accessories.append(premiumAccessory)
        }
        self.accessories = accessories

        isUserInteractionEnabled = itemConfig.isEnabled
        if itemConfig.isEnabled {
            accessibilityTraits.remove(.notEnabled)
        } else {
            accessibilityTraits.insert(.notEnabled)
        }
        if itemConfig.handler != nil {
            self.accessibilityTraits.insert(.button)
        }

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
    enum Decorator {
        case action
        case destructive
        case value
    }

    final class Config: SettingsItemConfig {
        var handler: Handler?
        var decorators: Set<Decorator> = []

        var fixedAccessories: [UICellAccessory] = []

        init(
            title: String,
            subtitle: String? = nil,
            image: UIImage? = nil,
            isEnabled: Bool = true,
            decorators: Set<Decorator> = [],
            fixedAccessories: [UICellAccessory] = [],
            handler: Handler?
        ) {
            self.handler = handler
            self.decorators = decorators
            self.fixedAccessories = fixedAccessories
            super.init(title: title, subtitle: subtitle, image: image, isEnabled: isEnabled)
        }

        override func isEqual(_ another: SettingsItemConfig?) -> Bool {
            guard let another = another as? Self else { return false }
            return super.isEqual(another)
                && self.decorators == another.decorators
        }

        override func hash(into hasher: inout Hasher) {
            super.hash(into: &hasher)
            hasher.combine(decorators)
        }
    }
}
