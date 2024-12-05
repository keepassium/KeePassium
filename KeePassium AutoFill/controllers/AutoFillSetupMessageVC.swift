//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UIKit

final class AutoFillSetupMessageVC: UIViewController {
    var completionHanlder: (() -> Void)?

    @IBOutlet private weak var bodyLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var button: UIButton!
    private weak var keychainSwitch: UISwitch!

    private var systemAppName: String {
        if #available(iOS 18, *) {
            return LString.titleApplePasswordsApp
        }
        return LString.titleKeychain
    }

    private var systemAutoFillSetupHeader: String {
        if #available(iOS 18, *) {
            return LString.autoFillSetupSectionHeader_iOS18
        }
        return LString.autoFillSetupSectionHeader_iOS17
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction(handler: { [weak self] _ in
                self?.completionHanlder?()
            })
        )

        title = LString.callToActionUncheckKeychain
        bodyLabel.text = String.localizedStringWithFormat(
            LString.uncheckKeychainAutoFillMessageTemplate,
            systemAppName)

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.buttonSize = .large
        buttonConfig.cornerStyle = .large
        buttonConfig.title = LString.actionContinue
        buttonConfig.titleLineBreakMode = .byWordWrapping
        button.configuration = buttonConfig

        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isUserInteractionEnabled = false
    }

    @IBAction private func didPressOK(_ sender: Any) {
        completionHanlder?()
    }
}

extension AutoFillSetupMessageVC: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return systemAutoFillSetupHeader
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: SwitchCell.reuseIdentifier, for: indexPath)
            as! SwitchCell
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = systemAppName
            cell.theSwitch.isOn = false
        case 1:
            cell.textLabel?.text = "KeePassium"
            cell.theSwitch.isOn = true
        default:
            fatalError()
        }
        return cell
    }
}

// swiftlint:disable line_length
extension LString {
    public static let titleKeychain = NSLocalizedString(
        "[Generic/Keychain/title]",
        value: "Keychain",
        comment: "Apple Keychain software; is a glossary term."
    )
    public static let titleApplePasswordsApp = NSLocalizedString(
        "[Generic/ApplePasswordsApp/title]",
        value: "Passwords",
        comment: "Name of the Apple Passwords application, see https://support.apple.com/120758"
    )
    public static let callToActionUncheckKeychain = NSLocalizedString(
        "[AutoFill/Setup/UncheckKeychain/callToAction]",
        value: "Uncheck Keychain",
        comment: "Call to action: deselect the `Keychain` option. Keychain is a glossary term."
    )
    public static let uncheckKeychainAutoFillMessageTemplate = NSLocalizedString(
        "[AutoFill/Setup/UncheckKeychain/message]",
        value: "To make KeePassium your default password manager, uncheck \"%@\".",
        comment: "Instruction to deselect another app in the settings [appName: String]"
    )
    public static let autoFillSetupSectionHeader_iOS17 = NSLocalizedString(
        "[AutoFill/Setup/UncheckKeychain/usePasswordsAndPasskeysFrom]",
        value: "Use passwords and passkeys from:",
        comment: "Must match Apple's translation, as found in iOS 17 Settings → Passwords → Password Options. If unsure, leave untranslated."
    )
    public static let autoFillSetupSectionHeader_iOS18 = NSLocalizedString(
        "[AutoFill/Setup/UncheckKeychain/autofillFrom]",
        value: "AutoFill from:",
        comment: "Must match Apple's translation, as found in iOS 18 Settings → General → AutoFill & Passwords. If unsure, leave untranslated."
    )
}
// swiftlint:enable line_length
