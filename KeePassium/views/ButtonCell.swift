//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class ButtonCell: UITableViewCell {
    var button: MultilineButton! 
    var buttonPressHandler: ((UIButton) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCell()
    }
    
    private func setupCell() {
        button = MultilineButton(frame: .zero)
        button.setTitleColor(.actionTint, for: .normal)
        contentView.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.topAnchor
            .constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor, constant: 0)
            .activate()
        button.bottomAnchor
            .constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor, constant: 0)
            .activate()
        button.leadingAnchor
            .constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor)
            .activate()
        button.trailingAnchor
            .constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor)
            .activate()
        button.centerXAnchor
            .constraint(equalTo: layoutMarginsGuide.centerXAnchor)
            .setPriority(.defaultLow)
            .activate()
        button.centerYAnchor
            .constraint(equalTo: layoutMarginsGuide.centerYAnchor)
            .setPriority(.defaultHigh)
            .activate()
        contentView.heightAnchor
            .constraint(greaterThanOrEqualToConstant: 44)
            .setPriority(.defaultLow)
            .activate()

        selectionStyle = .none
        
        button.addTarget(self, action: #selector(didTouchUpInsideButton), for: .touchUpInside)
    }
    
    @objc
    private func didTouchUpInsideButton() {
        buttonPressHandler?(button)
    }
}

