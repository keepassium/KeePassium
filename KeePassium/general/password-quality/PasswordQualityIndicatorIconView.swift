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

final class PasswordQualityIndicatorIconView: UIView {
    var quality: PasswordQuality? {
        didSet {
            guard let iconColor = quality?.iconColor,
                  let symbolName = quality?.symbolName
            else {
                isHidden = true
                return
            }

            iconImageView.tintColor = iconColor
            iconImageView.image = .symbol(symbolName)
            iconImageView.preferredSymbolConfiguration = .init(textStyle: .body)
            if let qualityTitle = quality?.title {
                accessibilityLabel = String.localizedStringWithFormat(
                    LString.titlePasswordQualityTemplate,
                    qualityTitle
                )
            } else {
                accessibilityLabel = nil
            }
        }
    }

    public var onTap: ((PasswordQualityIndicatorIconView) -> Void)?

    private lazy var iconImageView: UIImageView = {
        let iconImageView = UIImageView()
        iconImageView.contentMode = .center
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        return iconImageView
    }()

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconImageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            iconImageView.topAnchor.constraint(equalTo: topAnchor),
            iconImageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        isAccessibilityElement = true
        accessibilityTraits = [.staticText]

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(didRecognizeTapGesture))
        self.addGestureRecognizer(tapGestureRecognizer)
    }

    @objc
    private func didRecognizeTapGesture(_ sender: Any) {
        onTap?(self)
    }
}
