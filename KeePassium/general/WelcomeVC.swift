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
    
    @IBOutlet weak var infoLabel: UILabel!
    
    static func make(delegate: WelcomeDelegate) -> WelcomeVC {
        let vc = WelcomeVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        prettifyInfoText()
    }

    private func prettifyInfoText() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = 1.2
        paragraphStyle.paragraphSpacing = 6.0
        paragraphStyle.paragraphSpacingBefore = 6.0
        
        let font = UIFont.preferredFont(forTextStyle: .body)
        
        let attributedInfoText = NSMutableAttributedString(
            string: infoLabel.text ?? "",
            attributes: [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )
        infoLabel.attributedText = attributedInfoText
    }
    
    @IBAction func didPressCreateDatabase(_ sender: Any) {
        delegate?.didPressCreateDatabase(in: self)
    }
    
    @IBAction func didPressOpenDatabase(_ sender: Any) {
        delegate?.didPressAddExistingDatabase(in: self)
    }
}
