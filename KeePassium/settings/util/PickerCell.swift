//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class PickerCell: UICollectionViewListCell {
    private var itemConfig: Config!

    static func makeRegistration() -> UICollectionView.CellRegistration<PickerCell, SettingsItem> {
        return UICollectionView.CellRegistration<PickerCell, SettingsItem> {
            cell, indexPath, item in
            guard case let .picker(itemConfig) = item else { assertionFailure(); return }
            cell.configure(with: itemConfig)
        }
    }

    func configure(with itemConfig: Config) {
        self.itemConfig = itemConfig
        assert(itemConfig.subtitle == nil, "Picker cell does not support subtitles")
        var config = UIListContentConfiguration.valueCell()
        config.text = itemConfig.title
        config.secondaryText = itemConfig.value
        config.image = itemConfig.image
        self.contentConfiguration = config

        var accessories = [UICellAccessory]()
        if itemConfig.needsPremium {
            let badge = PremiumBadgeAccessory()
            let premiumAccessory = UICellAccessory.customView(
                configuration: .init(customView: badge, placement: .trailing())
            )
            accessories.append(premiumAccessory)
        }
        self.accessories = accessories

        self.accessibilityTraits.insert(.button)
        isUserInteractionEnabled = itemConfig.isEnabled
        if itemConfig.isEnabled {
            accessibilityTraits.remove(.notEnabled)
        } else {
            accessibilityTraits.insert(.notEnabled)
        }
        self.accessories = [.popUpMenu(itemConfig.menu)]
    }
}

extension PickerCell {
}

extension PickerCell {
    final class Config: SettingsItemConfig {
        var value: String?
        var menu: UIMenu

        init(
            title: String,
            subtitle: String? = nil,
            image: UIImage? = nil,
            isEnabled: Bool = true,
            value: String? = nil,
            menu: UIMenu
        ) {
            self.value = value
            self.menu = menu
            super.init(title: title, subtitle: subtitle, image: image, isEnabled: isEnabled)
        }

        override func isEqual(_ another: SettingsItemConfig?) -> Bool {
            guard let another = another as? Self else { return false }
            return super.isEqual(another)
                && self.value == another.value
                && self.menu == another.menu
        }

        override func hash(into hasher: inout Hasher) {
            super.hash(into: &hasher)
            hasher.combine(value)
            hasher.combine(menu)
        }
    }
}
