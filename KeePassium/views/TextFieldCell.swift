//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class TextFieldCell: UITableViewCell {
    var textField: ValidatingTextField! 
    
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
        textField = ValidatingTextField(frame: .zero)
        textField.font = .preferredFont(forTextStyle: .body)
        textField.textColor = .label
        
        contentView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.topAnchor
            .constraint(equalTo: contentView.topAnchor, constant: 0)
            .activate()
        textField.bottomAnchor
            .constraint(equalTo: contentView.bottomAnchor, constant: 0)
            .activate()
        textField.leadingAnchor
            .constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor)
            .activate()
        textField.trailingAnchor
            .constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
            .activate()
        textField.heightAnchor
            .constraint(equalToConstant: 44)
            .setPriority(.defaultHigh)
            .activate()
        selectionStyle = .none
    }
}

