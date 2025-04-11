//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

class FilePickerCell: UICollectionViewListCell {

    static let reuseIdentifier = "FilePickerCell"

    let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var isSpinnerVisible = false
    private weak var decorator: FilePickerItemDecorator?
    private var fixedAccessories = [UICellAccessory]()

    override init(frame: CGRect) {
        super.init(frame: frame)
        automaticallyUpdatesContentConfiguration = false
        automaticallyUpdatesBackgroundConfiguration = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: FilePickerItem.FileInfo, accessories: [UICellAccessory]?) {
        var config = UIListContentConfiguration.cell()
        config.text = item.fileName
        config.textProperties.numberOfLines = 1

        if let errorMessage = item.errorMessage {
            config.secondaryText = errorMessage
            config.secondaryTextProperties.color = .errorMessage
        } else {
            config.secondaryText = item.modifiedDate?.formatted(date: .long, time: .standard)
                ?? "…"
            config.secondaryTextProperties.color = .secondaryLabel
        }
        config.image = .symbol(item.iconSymbol)
        self.contentConfiguration = config
        isSpinnerVisible = item.isBusy

        self.fixedAccessories = accessories ?? []
        updateAccessories()
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

    private func updateAccessories() {
        var newAccessories = fixedAccessories
        if isSpinnerVisible {
            activityIndicator.startAnimating()
            let activityAccessory = UICellAccessory.customView(configuration: .init(
                customView: activityIndicator,
                placement: .trailing()))
            newAccessories.insert(activityAccessory, at: 0)
        }
        UIView.performWithoutAnimation {
            self.accessories = newAccessories
        }
    }
}
