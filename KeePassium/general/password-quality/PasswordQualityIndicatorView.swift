//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

final class PasswordQualityIndicatorView: UIView {
    var quality: PasswordQuality? {
        didSet {
            guard let quality = quality else {
                isHidden = true
                return
            }

            isHidden = false
            let qualityIndex = PasswordQuality.allCases.firstIndex(of: quality) ?? 0
            indicatorViews.enumerated().forEach { index, view in
                view.backgroundColor = index <= qualityIndex ? quality.strengthColor : .auxiliaryText
            }

            let qualityDescription: String
            if quality == PasswordQuality.veryGood(0) {
                let formattedBitCount = BitCountFormatter.string(fromBitCount: Int64(quality.entropy))
                qualityDescription = String.localizedStringWithFormat(
                    LString.passwordQualityWithEntropyTemplate,
                    quality.title,
                    formattedBitCount)
            } else {
                qualityDescription = quality.title
            }
            qualityLabel.text = qualityDescription
            accessibilityLabel = String.localizedStringWithFormat(
                LString.titlePasswordQualityTemplate,
                qualityDescription
            )
        }
    }

    var isBusy: Bool {
        didSet {
            if isBusy {
                UIView.animate(withDuration: 0.5, delay: 0, options: [.autoreverse, .repeat]) {
                    self.alpha = 0.2
                }
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState]) {
                    self.alpha = 1.0
                }
            }
        }
    }

    private lazy var indicatorViews: [UIView] = PasswordQuality.allCases.map { _ in
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 3)
        ])
        return view
    }

    private lazy var qualityLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .right
        label.text = " " 
        label.textColor = .secondaryLabel
        return label
    }()

    required init?(coder: NSCoder) {
        isBusy = false
        super.init(coder: coder)
        setup()
    }

    override init(frame: CGRect) {
        isBusy = false
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        let stackView = UIStackView(arrangedSubviews: indicatorViews)
        stackView.axis = .horizontal
        stackView.spacing = 2
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.distribution = .fillProportionally

        addSubview(stackView)
        addSubview(qualityLabel)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            qualityLabel.topAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 2),
            qualityLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            qualityLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isAccessibilityElement = true
        accessibilityTraits = [.staticText]
    }
}

extension LString {
    // swiftlint:disable line_length
    public static let passwordQualityWithEntropyTemplate = NSLocalizedString(
        "[PasswordQuality/LevelWithEntropy/description]",
        value: "%@ (%@ of entropy)",
        comment: "Password quality description. For example: `Very good (234 bits of entropy)`. [level: String, formattedBitCount: String]"
    )
    public static let titlePasswordQualityTemplate = NSLocalizedString(
        "[PasswordQuality/description]",
        value: "Password quality: %@",
        comment: "Password quality description. For example: `Password quality: Weak`. [level: String]"
    )
    // swiftlint:enable line_length
}
