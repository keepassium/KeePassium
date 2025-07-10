//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension AppProtectionSettingsCoordinator {

    internal func _showChangePasscode(isInitialSetup: Bool) {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = isInitialSetup ? .setup : .change
        passcodeInputVC.modalPresentationStyle = .formSheet
        passcodeInputVC.isCancelAllowed = true
        _appProtectionSettingsVC.present(passcodeInputVC, animated: true, completion: nil)
    }
}

extension AppProtectionSettingsCoordinator: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        refresh()
        sender.dismiss(animated: true) { [weak self] in
            guard let self else { return }
            if sender.mode == .setup {
                do {
                    try Keychain.shared.removeAppPasscode()
                } catch {
                    Diag.error(error.localizedDescription)
                    _appProtectionSettingsVC.showErrorAlert(error, title: LString.titleKeychainError)
                    return
                }
            }
        }
    }

    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }

    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        sender.dismiss(animated: true) { [weak self] in
            guard let self else { return }

            do {
                try Keychain.shared.setAppPasscode(passcode)
                if sender.mode == .change {
                    _appProtectionSettingsVC.showNotification(LString.titleNewPasscodeSaved)
                }
            } catch {
                Diag.error(error.localizedDescription)
                _appProtectionSettingsVC.showErrorAlert(error, title: LString.titleKeychainError)
            }
        }
    }
}
