//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import LocalAuthentication
import KeePassiumLib

class SettingsAppLockVC: UITableViewController, Refreshable {
    @IBOutlet weak var appLockEnabledSwitch: UISwitch!
    
    @IBOutlet weak var changePasscodeCell: UITableViewCell!
    @IBOutlet weak var appLockTimeoutCell: UITableViewCell!
    @IBOutlet weak var lockDatabasesOnFailedPasscodeCell: UITableViewCell!
    @IBOutlet weak var lockDatabasesOnFailedPasscodeSwitch: UISwitch!
    @IBOutlet weak var biometricsCell: UITableViewCell!
    @IBOutlet weak var biometricsIcon: UIImageView!
    @IBOutlet weak var allowBiometricsLabel: UILabel!
    @IBOutlet weak var biometricsSwitch: UISwitch!

    private var settingsNotifications: SettingsNotifications!
    private var isBiometricsSupported = false
    private var passcodeInputVC: PasscodeInputVC?
    private var isInitialPasscodeSetup = true
    
    private var premiumUpgradeHelper = PremiumUpgradeHelper()
    
    private enum Sections: Int {
        static let allValues: [Sections] = [.passcode, .biometrics, .timeout, .protectDatabases]
        case passcode = 0
        case biometrics = 1
        case timeout = 2
        case protectDatabases = 3
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        changePasscodeCell.textLabel?.text = LString.actionChangePasscode
        
        settingsNotifications = SettingsNotifications(observer: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPremiumStatus),
            name: PremiumManager.statusUpdateNotification,
            object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsNotifications.startObserving()

        refreshBiometricsSupport()
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }
    
    
    private func refreshBiometricsSupport() {
        let context = LAContext()
        isBiometricsSupported = context.canEvaluatePolicy(
            LAPolicy.deviceOwnerAuthenticationWithBiometrics,
            error: nil)
        if !isBiometricsSupported {
            Settings.current.isBiometricAppLockEnabled = false
        }
        
        let biometryTypeName = context.biometryType.name ?? "Touch ID/Face ID"
        allowBiometricsLabel.text = String.localizedStringWithFormat(
            NSLocalizedString(
                "[Settings/AppLock/Biometric/title] Use %@",
                value: "Use %@",
                comment: "Settings switch: whether AppLock is allowed to use Touch ID/Face ID. Example: 'Use Touch ID'. [biometryTypeName: String]"),
            biometryTypeName)
        biometricsIcon.image = context.biometryType.icon
    }
    
    func refresh() {
        let settings = Settings.current
        let isAppLockEnabled = settings.isAppLockEnabled
        appLockEnabledSwitch.isOn = isAppLockEnabled
        changePasscodeCell.setEnabled(isAppLockEnabled)
        appLockTimeoutCell.detailTextLabel?.text = settings.appLockTimeout.shortTitle
        lockDatabasesOnFailedPasscodeSwitch.isOn = settings.isLockAllDatabasesOnFailedPasscode
        biometricsSwitch.isOn = settings.premiumIsBiometricAppLockEnabled
        
        appLockTimeoutCell.setEnabled(isAppLockEnabled)
        lockDatabasesOnFailedPasscodeCell.setEnabled(isAppLockEnabled)
        biometricsCell.setEnabled(isAppLockEnabled && isBiometricsSupported)
        biometricsSwitch.isEnabled = isAppLockEnabled && isBiometricsSupported
    }

    @objc func refreshPremiumStatus() {
        refresh()
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case changePasscodeCell:
            showChangePasscode(isInitialSetup: false)
        case appLockTimeoutCell:
            let timeoutVC = SettingsAppTimeoutVC.make()
            show(timeoutVC, sender: self)
        default:
            break
        }
    }
    
    
    @IBAction func didChangeAppLockEnabledSwitch(_ sender: Any) {
        if !appLockEnabledSwitch.isOn {
            do {
                try Keychain.shared.removeAppPasscode() 
            } catch {
                Diag.error(error.localizedDescription)
                showErrorAlert(error, title: LString.titleKeychainError)
            }
        } else {
            showChangePasscode(isInitialSetup: true)
        }
    }
    
    @IBAction func didPressChangePasscode(_ sender: UIButton) {
        showChangePasscode(isInitialSetup: false)
    }
    
    @IBAction func didChangeLockDatabasesOnFailedPasscodeSwitch(_ sender: UISwitch) {
        Settings.current.isLockAllDatabasesOnFailedPasscode = lockDatabasesOnFailedPasscodeSwitch.isOn
    }
    
    @IBAction func didToggleBiometricsSwitch(_ sender: UISwitch) {
        let isSwitchOn = sender.isOn
        Settings.current.isBiometricAppLockEnabled = isSwitchOn
        refresh()
    }
    
    private func showChangePasscode(isInitialSetup: Bool) {
        self.isInitialPasscodeSetup = isInitialSetup
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .setup
        passcodeInputVC.modalPresentationStyle = .formSheet
        passcodeInputVC.isCancelAllowed = true
        present(passcodeInputVC, animated: true, completion: nil)
        self.passcodeInputVC = passcodeInputVC
    }
}

extension SettingsAppLockVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

extension SettingsAppLockVC: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        if isInitialPasscodeSetup {
            do {
                try Keychain.shared.removeAppPasscode()
            } catch {
                Diag.error(error.localizedDescription)
                showErrorAlert(error, title: LString.titleKeychainError)
                return
            }
        }
        refresh()
        passcodeInputVC?.dismiss(animated: true, completion: nil)
    }
    
    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }
    
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        passcodeInputVC?.dismiss(animated: true) {
            [weak self] in
            guard let self = self else { return }
            do {
                try Keychain.shared.setAppPasscode(passcode)
                if !self.isInitialPasscodeSetup {
                    self.showNotification(LString.titleNewPasscodeSaved)
                }
            } catch {
                Diag.error(error.localizedDescription)
                self.showErrorAlert(error, title: LString.titleKeychainError)
            }
        }
    }
}
