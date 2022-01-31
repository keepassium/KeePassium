//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class SwitchCell: UITableViewCell {
    public static let reuseIdentifier = "SwitchCell"
    
    typealias ToggleHandler = (UISwitch) -> Void
    var toggleHandler: ToggleHandler?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var theSwitch: UISwitch!
    
    @IBAction private func didToggleSwitch(_ sender: UISwitch) {
        toggleHandler?(theSwitch)
    }
}
