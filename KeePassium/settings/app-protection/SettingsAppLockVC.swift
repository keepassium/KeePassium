//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import LocalAuthentication
import KeePassiumLib

protocol SettingsAppLockViewControllerDelegate: AnyObject {
    func didPressChangePasscode(isInitialSetup: Bool, in viewController: SettingsAppLockVC)
    func didPressAppTimeout(in viewController: SettingsAppLockVC)
}

final class SettingsAppLockVC: UITableViewController, Refreshable {
    @IBOutlet private weak var appLockEnabledSwitch: UISwitch!
    
    @IBOutlet private weak var changePasscodeCell: UITableViewCell!
    @IBOutlet private weak var appLockTimeoutCell: UITableViewCell!
    @IBOutlet private weak var lockDatabasesOnFailedPasscodeCell: UITableViewCell!
    @IBOutlet private weak var lockDatabasesOnFailedPasscodeSwitch: UISwitch!
    @IBOutlet private weak var biometricsCell: UITableViewCell!
    @IBOutlet private weak var biometricsIcon: UIImageView!
    @IBOutlet private weak var allowBiometricsLabel: UILabel!
    @IBOutlet private weak var biometricsSwitch: UISwitch!

    weak var delegate: SettingsAppLockViewControllerDelegate?
    
    private var settingsNotifications: SettingsNotifications!
    private var isBiometricsSupported = false
    
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = LString.titleAppProtectionSettings
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
            LString.titleUseBiometryTypeTemplate,
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
        biometricsSwitch.isOn = settings.isBiometricAppLockEnabled
        
        appLockTimeoutCell.setEnabled(isAppLockEnabled)
        lockDatabasesOnFailedPasscodeCell.setEnabled(isAppLockEnabled)
        biometricsCell.setEnabled(isAppLockEnabled && isBiometricsSupported)
        biometricsSwitch.isEnabled = isAppLockEnabled && isBiometricsSupported
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case changePasscodeCell:
            delegate?.didPressChangePasscode(isInitialSetup: false, in: self)
        case appLockTimeoutCell:
            delegate?.didPressAppTimeout(in: self)
        default:
            break
        }
    }
    
    
    @IBAction func didChangeAppLockEnabledSwitch(_ sender: Any) {
        if !appLockEnabledSwitch.isOn {
            Settings.current.isHideAppLockSetupReminder = false
            do {
                try Keychain.shared.removeAppPasscode() 
            } catch {
                Diag.error(error.localizedDescription)
                showErrorAlert(error, title: LString.titleKeychainError)
            }
        } else {
            delegate?.didPressChangePasscode(isInitialSetup: true, in: self)
        }
    }
    
    @IBAction func didPressChangePasscode(_ sender: UIButton) {
        delegate?.didPressChangePasscode(isInitialSetup: false, in: self)
    }
    
    @IBAction func didChangeLockDatabasesOnFailedPasscodeSwitch(_ sender: UISwitch) {
        Settings.current.isLockAllDatabasesOnFailedPasscode = lockDatabasesOnFailedPasscodeSwitch.isOn
    }
    
    @IBAction func didToggleBiometricsSwitch(_ sender: UISwitch) {
        let isSwitchOn = sender.isOn
        let keychain = Keychain.shared
        if keychain.prepareBiometricAuth(isSwitchOn) {
            Settings.current.isBiometricAppLockEnabled = isSwitchOn
        } else {
            Settings.current.isBiometricAppLockEnabled = keychain.isBiometricAuthPrepared()
        }
        refresh()
    }
}

extension SettingsAppLockVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

