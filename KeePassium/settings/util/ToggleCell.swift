//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class ToggleCell: UICollectionViewListCell {
    typealias Handler = (Config) -> Void

    private var itemConfig: Config!
    private weak var toggleSwitch: UISwitch?

    static func makeRegistration() -> UICollectionView.CellRegistration<ToggleCell, SettingsItem> {
        return UICollectionView.CellRegistration<ToggleCell, SettingsItem> {
            cell, indexPath, item in
            guard case let .toggle(itemConfig) = item else { assertionFailure(); return }
            cell.configure(with: itemConfig)
        }
    }

    func configure(with itemConfig: Config) {
        self.itemConfig = itemConfig
        var contentConfig = UIListContentConfiguration.cell()
        contentConfig.text = itemConfig.title
        contentConfig.secondaryText = itemConfig.subtitle
        contentConfig.image = itemConfig.image
        self.contentConfiguration = contentConfig

        let toggleSwitch = UISwitch()
        toggleSwitch.isOn = itemConfig.isOn
        toggleSwitch.addTarget(self, action: #selector(didToggleSwitch), for: .valueChanged)

        var accessories = [UICellAccessory]()
        if itemConfig.needsPremium {
            let badge = PremiumBadgeAccessory()
            let premiumAccessory = UICellAccessory.customView(
                configuration: .init(customView: badge, placement: .trailing())
            )
            accessories.append(premiumAccessory)
        }
        accessories.append(
            .customView(configuration: .init(customView: toggleSwitch, placement: .trailing()))
        )
        self.accessories = accessories

        isUserInteractionEnabled = itemConfig.isEnabled
        toggleSwitch.isEnabled = itemConfig.isEnabled
        self.toggleSwitch = toggleSwitch
    }

    @objc private func didToggleSwitch(_ sender: UISwitch) {
        itemConfig.isOn = sender.isOn
        itemConfig.handler?(itemConfig)
        setNeedsUpdateConfiguration()
    }
}

extension ToggleCell {
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(didPressToggle)),
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(didPressToggle)),
        ]
    }

    @objc private func didPressToggle(_ sender: Any) {
        guard let toggleSwitch else { return }
        toggleSwitch.setOn(!toggleSwitch.isOn, animated: true)
        toggleSwitch.sendActions(for: .valueChanged)
    }
}

extension ToggleCell {
    final class Config: SettingsItemConfig {
        var isOn: Bool
        var handler: Handler?

        init(
            title: String,
            subtitle: String? = nil,
            image: UIImage? = nil,
            isEnabled: Bool = true,
            isOn: Bool,
            needsPremium: Bool = false,
            handler: Handler? = nil
        ) {
            self.isOn = isOn
            self.handler = handler
            super.init(
                title: title,
                subtitle: subtitle,
                image: image,
                isEnabled: isEnabled,
                needsPremium: needsPremium
            )
        }

        override func isEqual(_ another: SettingsItemConfig?) -> Bool {
            guard let another = another as? Self else { return false }
            return super.isEqual(another)
                && self.isOn == another.isOn
        }

        override func hash(into hasher: inout Hasher) {
            super.hash(into: &hasher)
            hasher.combine(isOn)
        }
    }
}
