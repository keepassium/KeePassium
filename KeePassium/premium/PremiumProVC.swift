//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol PremiumProDelegate: class {
    func didPressOpenInAppStore(_ sender: PremiumProVC)
}

class PremiumProVC: UIViewController {
    
    weak var delegate: PremiumProDelegate?
    @IBOutlet weak var contactSupportButton: MultilineButton!
    
    public static func create(delegate: PremiumProDelegate?=nil) -> PremiumProVC {
        let vc = PremiumProVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let product = PremiumManager.shared.getPremiumProduct(),
            product == .forever {
            contactSupportButton.isHidden = false
        } else {
            contactSupportButton.isHidden = true
        }
        contactSupportButton.titleLabel?.textAlignment = .center
    }
    
    @IBAction func didPressOpenInAppStore(_ sender: UIButton) {
        delegate?.didPressOpenInAppStore(self)
    }
    @IBAction func didPressContactSupport(_ sender: Any) {
        SupportEmailComposer.show(subject: .proUpgrade)
    }
}
