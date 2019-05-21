//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol WelcomeDelegate: class {
    func didPressCreateDatabase(in welcomeVC: WelcomeVC)
    func didPressAddExistingDatabase(in welcomeVC: WelcomeVC)
}

class WelcomeVC: UIViewController {
    private weak var delegate: WelcomeDelegate?

    static func make(delegate: WelcomeDelegate) -> WelcomeVC {
        let vc = WelcomeVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    @IBAction func didPressCreateDatabase(_ sender: Any) {
        delegate?.didPressCreateDatabase(in: self)
    }
    
    @IBAction func didPressOpenDatabase(_ sender: Any) {
        delegate?.didPressAddExistingDatabase(in: self)
    }
}
