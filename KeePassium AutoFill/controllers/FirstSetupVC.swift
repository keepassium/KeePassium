//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class FirstSetupVC: UIViewController {
    
    private weak var coordinator: MainCoordinator?
    
    static func make(coordinator: MainCoordinator) -> FirstSetupVC {
        let vc = FirstSetupVC.instantiateFromStoryboard()
        vc.coordinator = coordinator
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    @IBAction func didPressCancelButton(_ sender: Any) {
        coordinator?.dismissAndQuit()
    }
    
    @IBAction func didPressAddDatabase(_ sender: Any) {
        coordinator?.addDatabase()
    }
}
