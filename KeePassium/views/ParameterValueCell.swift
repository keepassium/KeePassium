//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class ParameterValueCell: UITableViewCell {
    public static let reuseIdentifier = "ParameterValueCell"

    var menu: UIMenu? {
        didSet {
            theButton?.menu = menu
            (accessoryView as? UIButton)?.menu = menu
        }
    }
    private var theButton: UIButton!

    override func awakeFromNib() {
        super.awakeFromNib()
        theButton = UIButton(frame: self.bounds)
        contentView.addSubview(theButton)
        theButton.isAccessibilityElement = false 
        theButton.backgroundColor = .clear
        theButton.showsMenuAsPrimaryAction = true
        theButton.menu = menu
        setupAccessory()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        theButton.frame = contentView.bounds
    }

    private func setupAccessory() {
        let button = UIButton(type: .detailDisclosure)
        button.tintColor = .secondaryLabel
        button.setImage(.symbol(.chevronForward), for: .normal)
        button.accessibilityLabel = LString.actionEdit
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        accessoryView = button
    }
}
