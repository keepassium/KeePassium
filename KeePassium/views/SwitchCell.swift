//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class SwitchCell: UITableViewCell {
    public static let reuseIdentifier = "SwitchCell"
    
    typealias ToggleHandler = (UISwitch) -> Void
    var didToggleSwitch: ToggleHandler?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var theSwitch: UISwitch!
    
    @IBAction func didToggleSwitch(_ sender: UISwitch) {
        didToggleSwitch?(theSwitch)
    }
}
