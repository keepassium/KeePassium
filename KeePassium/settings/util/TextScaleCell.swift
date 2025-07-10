//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class TextScaleCell: UICollectionViewListCell {
    typealias Handler = (Config) -> Void

    private var itemConfig: Config!
    private var rescaleTimer: Timer?

    static func makeRegistration() -> UICollectionView.CellRegistration<TextScaleCell, SettingsItem> {
        return UICollectionView.CellRegistration<TextScaleCell, SettingsItem> {
            cell, indexPath, item in
            guard case let .textScale(itemConfig) = item else { assertionFailure(); return }
            cell.configure(with: itemConfig)
        }
    }

    private var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isAccessibilityElement = false
        label.numberOfLines = 1
        return label
    }()

    private var slider: UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        let textScaleRange = Settings.textScaleAllowedRange
        slider.minimumValue = Float(textScaleRange.lowerBound)
        slider.maximumValue = Float(textScaleRange.upperBound)
        slider.accessibilityLabel = LString.appearanceTextSizeTitle
        return slider
    }()

    private var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.adjustsImageSizeForAccessibilityContentSizeCategory = true
        button.accessibilityLabel = LString.actionResetTextSize

        var config = UIButton.Configuration.plain()
        config.buttonSize = .mini
        config.title = "1:1"
        config.titleAlignment = .center
        config.titleLineBreakMode = .byClipping
        config.background.cornerRadius = 3
        config.background.strokeWidth = 1
        config.background.strokeColor = .systemTint
        config.contentInsets = .init(top: 2, leading: 4, bottom: 2, trailing: 4)
        button.configuration = config
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayout()
    }

    private func setupLayout() {
        contentView.addSubview(label)
        contentView.addSubview(slider)
        contentView.addSubview(resetButton)

        label.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow + 1, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultHigh + 2, for: .vertical)

        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        slider.setContentHuggingPriority(.defaultLow, for: .vertical)
        slider.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        slider.setContentCompressionResistancePriority(.defaultHigh + 1, for: .vertical)

        resetButton.setContentHuggingPriority(.defaultLow + 1, for: .horizontal)
        resetButton.setContentHuggingPriority(.defaultLow + 1, for: .vertical)
        resetButton.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        resetButton.setContentCompressionResistancePriority(.defaultHigh + 3, for: .vertical)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),

            slider.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            slider.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            slider.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            resetButton.centerYAnchor.constraint(equalTo: slider.centerYAnchor),
            resetButton.leadingAnchor.constraint(equalTo: slider.trailingAnchor, constant: 16),
            resetButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            resetButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
    }

    func configure(with itemConfig: Config) {
        self.itemConfig = itemConfig

        let scale = CGFloat(itemConfig.value)
        label.font = itemConfig.font.withRelativeSize(scale)
        label.text = itemConfig.title

        slider.value = itemConfig.value
        slider.addAction(
            UIAction { [unowned self] _ in
                setScale(slider.value)
            },
            for: .valueChanged
        )

        resetButton.addAction(
            UIAction { [unowned self] _ in
                setScale(1.0)
            },
            for: .touchUpInside
        )
    }

    private func setScale(_ scale: Float) {
        label.font = itemConfig.font.withRelativeSize(CGFloat(scale))
        itemConfig.value = scale
        itemConfig.handler?(itemConfig)
    }
}

extension TextScaleCell {
    final class Config: SettingsItemConfig {
        var value: Float
        var font: UIFont
        var handler: Handler?

        init(
            title: String,
            value: Float,
            font: UIFont,
            handler: Handler? = nil
        ) {
            self.value = value
            self.font = font
            self.handler = handler
            super.init(
                title: title,
                subtitle: nil,
                image: nil,
                isEnabled: true,
                needsPremium: false
            )
        }

        override func isEqual(_ another: SettingsItemConfig?) -> Bool {
            guard let another = another as? Self else { return false }
            return super.isEqual(another)
                && self.value == another.value
                && self.font == another.font
        }

        override func hash(into hasher: inout Hasher) {
            super.hash(into: &hasher)
            hasher.combine(value)
            hasher.combine(font)
        }
    }
}
