//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class AnnouncementCell: UITableViewCell {    
    lazy var announcementView: AnnouncementView = {
        let view = AnnouncementView(frame: .zero)
        return view
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .default, reuseIdentifier: reuseIdentifier)
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
        selectionStyle = .none
        
        backgroundColor = .systemBackground
        separatorInset = UIEdgeInsets(top: 0, left: self.bounds.width*2, bottom: 0, right: 0)
        
        contentView.addSubview(announcementView)
        announcementView.translatesAutoresizingMaskIntoConstraints = false
        announcementView.topAnchor
            .constraint(equalTo: contentView.topAnchor, constant: 8)
            .activate()
        announcementView.bottomAnchor
            .constraint(equalTo: contentView.bottomAnchor, constant: -8)
            .activate()
        announcementView.leadingAnchor
            .constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)
            .setPriority(.defaultHigh)
            .activate()
        announcementView.trailingAnchor
            .constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
            .setPriority(.defaultHigh)
            .activate()
        announcementView.widthAnchor
            .constraint(lessThanOrEqualTo: readableContentGuide.widthAnchor)
            .activate()
    }
}
