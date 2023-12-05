//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class DatabaseItemTitleView: UIView {
    let imageSide: CGFloat = 29.0

    lazy var iconView: UIImageView = {
        let iconView = UIImageView()
        iconView.image = nil
        iconView.tintColor = .primaryText
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: imageSide).activate()
        iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor, multiplier: 1).activate()
        return iconView
    }()

    lazy var titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .primaryText
        titleLabel.text = nil
        titleLabel.lineBreakMode = .byTruncatingTail
        return titleLabel
    }()

    lazy var subtitleLabel: UILabel = {
        let subtitleLabel = UILabel()
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .auxiliaryText
        subtitleLabel.text = nil
        subtitleLabel.lineBreakMode = .byTruncatingTail
        return subtitleLabel
    }()

    private lazy var verticalStack: UIStackView = {
        let verticalStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        verticalStack.axis = .vertical
        verticalStack.alignment = .fill
        verticalStack.distribution = .fill
        verticalStack.translatesAutoresizingMaskIntoConstraints = false
        return verticalStack
    }()

    override init(frame: CGRect) {
      super.init(frame: frame)
      setupView()
    }

    required init?(coder aDecoder: NSCoder) {
      super.init(coder: aDecoder)
      setupView()
    }

    private func setupView() {
        addSubview(iconView)
        addSubview(verticalStack)
        setupLayout()
    }

    private func setupLayout() {
        iconView.leadingAnchor
            .constraint(greaterThanOrEqualTo: self.leadingAnchor, constant: 0.0)
            .activate()
        iconView.centerYAnchor
            .anchorWithOffset(to: verticalStack.centerYAnchor)
            .constraint(equalToConstant: 0)
            .activate()
        verticalStack.topAnchor
            .constraint(greaterThanOrEqualTo: self.topAnchor, constant: 0)
            .activate()
        verticalStack.leadingAnchor
            .constraint(equalTo: iconView.trailingAnchor, constant: 8.0)
            .activate()
        verticalStack.centerYAnchor
            .anchorWithOffset(to: self.centerYAnchor)
            .constraint(equalToConstant: 0)
            .activate()
        verticalStack.centerXAnchor
            .anchorWithOffset(to: self.centerXAnchor)
            .constraint(equalToConstant: -imageSide / 2) 
            .activate()
        verticalStack.trailingAnchor
            .constraint(lessThanOrEqualTo: self.trailingAnchor, constant: 0)
            .activate()
    }
}
