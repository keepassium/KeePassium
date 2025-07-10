//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

final class TableFooterLabelView: UIView {
    private let hPadding = 16.0
    private let vPadding = 8.0

    var text: String = "" {
        didSet {
            label.text = text
            setNeedsLayout()
        }
    }

    private let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail

        label.textColor = .secondaryLabel
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.adjustsFontForContentSizeCategory = true

        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init() {
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.topAnchor, constant: vPadding),
            label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: hPadding),
            label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -hPadding),
            label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -vPadding)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let targetSize = CGSize(width: bounds.width, height: UIView.layoutFittingCompressedSize.height)
        let newHeight = systemLayoutSizeFitting(targetSize).height

        frame.size.height = newHeight
    }
}
