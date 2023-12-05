//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol WelcomeDelegate: AnyObject {
    func didPressCreateDatabase(in welcomeVC: WelcomeVC)
    func didPressAddExistingDatabase(in welcomeVC: WelcomeVC)
    func didPressConnectToServer(in welcomeVC: WelcomeVC)
}

class WelcomeVC: UIViewController {
    private weak var delegate: WelcomeDelegate?

    @IBOutlet private weak var infoLabel: UILabel!
    @IBOutlet private weak var connectToServerButton: UIButton!

    static func make(delegate: WelcomeDelegate) -> WelcomeVC {
        let vc = WelcomeVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        connectToServerButton.setTitle(LString.actionConnectToServer, for: .normal)
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

    @IBAction private func didPressCreateDatabase(_ sender: Any) {
        delegate?.didPressCreateDatabase(in: self)
    }

    @IBAction private func didPressOpenDatabase(_ sender: Any) {
        delegate?.didPressAddExistingDatabase(in: self)
    }

    @IBAction private func didPressConnectToServer(_ sender: Any) {
        delegate?.didPressConnectToServer(in: self)
    }
}
