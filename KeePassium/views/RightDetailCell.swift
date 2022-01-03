//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class RightDetailCell: UITableViewCell {
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
        selectionStyle = .none
        
        textLabel?.font = .preferredFont(forTextStyle: .body)
        textLabel?.textColor = .label
        textLabel?.numberOfLines = 0
        textLabel?.lineBreakMode = .byWordWrapping
        
        detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        detailTextLabel?.textColor = .secondaryLabel
        detailTextLabel?.numberOfLines = 0
        detailTextLabel?.lineBreakMode = .byWordWrapping
    }
}
