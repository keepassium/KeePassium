//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

final class NullableBoolSettingCell: UITableViewCell {
    static let reuseIdentifier = "NullableBoolSettingCell"

    var title: String? {
        didSet {
            titleLabel.text = title
        }
    }

    var value: Bool? {
        didSet {
            updateMenu()
        }
    }

    var defaultValue: Bool = false {
        didSet {
            updateMenu()
        }
    }

    var onStateChanged: ((Bool?) -> Void)?

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .primaryText
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private lazy var popupButton: UIButton = {
        var config = UIButton.Configuration.borderless()
        config.baseForegroundColor = .secondaryLabel
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true
        button.configurationUpdateHandler = { [weak self] button in
            guard let self else { return }
            var config = button.configuration
            switch (value, defaultValue) {
            case (true, _):
                config?.title = LString.titleYes
            case (false, _):
                config?.title = LString.titleNo
            case (_, true):
                config?.title = String.localizedStringWithFormat(
                    LString.titleUseAppSettingsShortTemplate,
                    LString.titleYes)
            case (_, false):
                config?.title = String.localizedStringWithFormat(
                    LString.titleUseAppSettingsShortTemplate,
                    LString.titleNo)
            }
            button.configuration = config
        }

        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        selectionStyle = .none
        accessoryType = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(popupButton)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        popupButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        popupButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            popupButton.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            popupButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            popupButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        updateMenu()
    }

    private func updateMenu() {
        let titleUseDefault = String.localizedStringWithFormat(
            LString.titleUseAppSettingsTemplate,
            defaultValue ? LString.titleYes : LString.titleNo
        )

        let options: [(Bool?, String)] = [
            (nil, titleUseDefault),
            (true, LString.titleYes),
            (false, LString.titleNo),
        ]
        let actions = options.map { itemValue, itemTitle -> UIAction in
            UIAction(title: itemTitle, state: self.value == itemValue ? .on : .off) { [weak self] _ in
                self?.value = itemValue
                self?.onStateChanged?(itemValue)
            }
        }
        popupButton.menu = UIMenu(children: actions)
    }

    @available(iOS 17.4, *)
    public func showMenu() {
        popupButton.performPrimaryAction()
    }
}
