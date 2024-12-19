//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UIKit

protocol PasskeyCreatorDelegate: AnyObject {
    func didPressCreatePasskey(with params: PasskeyRegistrationParams, in viewController: PasskeyCreatorVC)
    func didPressAddPasskeyToEntry(
        with params: PasskeyRegistrationParams,
        in viewController: PasskeyCreatorVC)
}

final class PasskeyCreatorVC: UIViewController {
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var relyingPartyLabel: UILabel!
    @IBOutlet private weak var usernameLabel: UILabel!
    @IBOutlet private weak var primaryButton: UIButton!
    @IBOutlet private weak var secondaryButton: UIButton!

    weak var delegate: PasskeyCreatorDelegate?

    private var params: PasskeyRegistrationParams!

    public static func make(with params: PasskeyRegistrationParams) -> PasskeyCreatorVC {
        let vc = PasskeyCreatorVC.instantiateFromStoryboard()
        vc.params = params
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.titleCreatePasskey
        titleLabel.text = title
        relyingPartyLabel.text = params.identity.relyingPartyIdentifier
        usernameLabel.text = params.identity.userName

        var secondaryConfig = UIButton.Configuration.plain()
        secondaryConfig.title = LString.actionAddPasskeyToExistingEntry
        secondaryConfig.titleLineBreakMode = .byWordWrapping
        var primaryConfig = UIButton.Configuration.filled()
        primaryConfig.title = LString.actionContinue
        primaryConfig.titleLineBreakMode = .byWordWrapping

        primaryButton.configuration = primaryConfig
        secondaryButton.configuration = secondaryConfig
        secondaryButton.isEnabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    func detents() -> [UISheetPresentationController.Detent] {
        let customDetent = UISheetPresentationController.Detent.custom(identifier: .init("detent")) { _ in
            self.secondaryButton.frame.maxY + 16
        }
        return [customDetent]
    }

    @IBAction private func didPressPrimary(_ sender: Any) {
        delegate?.didPressCreatePasskey(with: params, in: self)
    }

    @IBAction private func didPressSecondary(_ sender: Any) {
        delegate?.didPressAddPasskeyToEntry(with: params, in: self)
    }
}

extension LString {
    public static let titleCreatePasskey = NSLocalizedString(
        "[Database/Passkey/Create/title]",
        value: "Create a Passkey?",
        comment: "Title of an optional dialog for creating new passkeys"
    )
    public static let actionAddPasskeyToExistingEntry = NSLocalizedString(
        "[Database/Passkey/AddToExisting/action]",
        value: "Add Passkey to Existing Entry",
        comment: "Action: create a passkey and add it to existing entry"
    )
    public static let titleConfirmReplacingExistingPasskey = NSLocalizedString(
        "[Database/Passkey/AddToExisting/confirm]",
        value: "This entry already has a passkey. Replace it?",
        comment: "Confirmation message before replacing an existing passkey."
    )
}
