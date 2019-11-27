//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol FirstSetupDelegate: class {
    func didPressCancel(in firstSetup: FirstSetupVC)
    func didPressAddDatabase(in firstSetup: FirstSetupVC, at popoverAnchor: PopoverAnchor)
}
class FirstSetupVC: UIViewController {
    
    private weak var delegate: FirstSetupDelegate?
    
    static func make(delegate: FirstSetupDelegate?=nil) -> FirstSetupVC {
        let vc = FirstSetupVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.setToolbarHidden(true, animated: true)
    }
    
    @IBAction func didPressCancelButton(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressAddDatabase(_ sender: UIButton) {
        let popoverAnchor = PopoverAnchor(sourceView: sender, sourceRect: sender.bounds)
        delegate?.didPressAddDatabase(in: self, at: popoverAnchor)
    }
}
