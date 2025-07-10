//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

final class AnnouncementCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "AnnouncementCollectionCell"

    lazy var announcementView: AnnouncementView = {
        let view = AnnouncementView(frame: .zero)
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    private func setupView() {
        backgroundColor = .systemBackground

        contentView.addSubview(announcementView)
        announcementView.translatesAutoresizingMaskIntoConstraints = false
        announcementView.topAnchor
            .constraint(equalTo: contentView.topAnchor, constant: 8)
            .activate()
        announcementView.bottomAnchor
            .constraint(equalTo: contentView.bottomAnchor, constant: -8)
            .activate()
        announcementView.leadingAnchor
            .constraint(equalTo: contentView.leadingAnchor)
            .activate()
        announcementView.trailingAnchor
            .constraint(equalTo: contentView.trailingAnchor)
            .activate()
    }

    public func configure(with announcement: AnnouncementItem) {
        announcementView.apply(announcement)
    }
}
