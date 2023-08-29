//  KeePassium Password Manager
//  Copyright © 2018-2023 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

protocol PasswordAuditVCDelegate: AnyObject {
    func userDidDismiss()
    func userDidRequestStartPasswordAudit()
}

final class PasswordAuditVC: UIViewController {
    @IBOutlet private weak var introTextView: UITextView!
    @IBOutlet private weak var startButton: UIButton!
    

    private lazy var closeButton = UIBarButtonItem(
        barButtonSystemItem: .close,
        target: self,
        action: #selector(didPressDismiss))

    weak var delegate: PasswordAuditVCDelegate?


    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.titlePasswordAudit
        navigationItem.leftBarButtonItem = closeButton
        
        startButton.setTitle(LString.actionStartPasswordAudit, for: .normal)
        introTextView.attributedText = getIntroText()
    }
    
    private func getIntroText() -> NSAttributedString {
        let introText = try! NSMutableAttributedString(
            markdown: String.localizedStringWithFormat(
                LString.passwordAuditIntroTemplate,
                URL.AppHelp.hibpMoreInfoURLString),
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        introText.addAttributes([
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label,
            ],
            range: NSRange(0..<introText.length)
        )
        return introText
    }


    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        delegate?.userDidDismiss()
    }

    @IBAction private func didPressStartAudit(_ sender: Any) {
        requestNetworkAccessPermission { [weak self] in
            self?.delegate?.userDidRequestStartPasswordAudit()
        }
    }
}
