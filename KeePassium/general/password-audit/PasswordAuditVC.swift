//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

protocol PasswordAuditVCDelegate: AnyObject {
    func didPressDismiss(in viewController: PasswordAuditVC)
    func didPressStartAudit(in viewController: PasswordAuditVC)
}

final class PasswordAuditVC: UIViewController, Refreshable {
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

        introTextView.attributedText = getIntroText()
        refresh()
    }

    private func getIntroText() -> NSAttributedString {
        let introText = try! NSMutableAttributedString(
            markdown: String.localizedStringWithFormat(
                LString.passwordAuditIntroTemplate,
                URL.AppHelp.hibpMoreInfoURLString),
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        introText.addAttributes(
            [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .foregroundColor: UIColor.label
            ],
            range: NSRange(0..<introText.length)
        )
        return introText
    }

    func refresh() {
        var buttonConfig = UIButton.Configuration.plain()
        buttonConfig.title = LString.actionStartPasswordAudit

        let needsPremium = !PremiumManager.shared.isAvailable(feature: .canAuditPasswords)
        if needsPremium {
            buttonConfig.image = .premiumBadge
            buttonConfig.imagePadding = 8
            buttonConfig.imagePlacement = .trailing
        }
        startButton.configuration = buttonConfig
    }


    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        delegate?.didPressDismiss(in: self)
    }

    @IBAction private func didPressStartAudit(_ sender: Any) {
        delegate?.didPressStartAudit(in: self)
    }
}
