//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol SettingsDataProtectionViewCoordinatorDelegate: AnyObject {
    func didPressDatabaseTimeout(in viewController: SettingsDataProtectionVC)
    func didPressClipboardTimeout(in viewController: SettingsDataProtectionVC)
    func didToggleLockDatabasesOnTimeout(newValue: Bool, in viewController: SettingsDataProtectionVC)
    func didPressShakeGestureAction(in viewController: SettingsDataProtectionVC)
}

final class SettingsDataProtectionVC: UITableViewController, Refreshable {

    @IBOutlet private weak var rememberMasterKeysSwitch: UISwitch!
    @IBOutlet private weak var clearMasterKeysButton: UIButton!
    @IBOutlet private weak var rememberFinalKeysSwitch: UISwitch!
    @IBOutlet private weak var rememberFinalKeysLabel: UILabel!
    @IBOutlet private weak var rememberFinalKeysCell: UITableViewCell!

    @IBOutlet private weak var rememberUsedKeyFiles: UISwitch!
    @IBOutlet private weak var clearKeyFileAssociationsButton: UIButton!

    @IBOutlet private weak var databaseTimeoutCell: UITableViewCell!
    @IBOutlet private weak var lockDatabaseOnTimeoutLabel: UILabel!
    @IBOutlet private weak var lockDatabaseOnTimeoutSwitch: UISwitch!
    @IBOutlet private weak var lockDatabaseOnTimeoutPremiumBadge: UIImageView!

    @IBOutlet private weak var clipboardTimeoutCell: UITableViewCell!
    @IBOutlet private weak var universalClipboardSwitch: UISwitch!

    @IBOutlet private weak var hideProtectedFieldsSwitch: UISwitch!

    @IBOutlet private weak var shakeGestureCell: UITableViewCell!

    weak var delegate: SettingsDataProtectionViewCoordinatorDelegate?

    private var settingsNotifications: SettingsNotifications!


    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        settingsNotifications = SettingsNotifications(observer: self)

        shakeGestureCell.textLabel?.text = LString.shakeGestureActionTitle
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = LString.titleDataProtectionSettings
        settingsNotifications.startObserving()
        refresh()
    }

    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }

    func refresh() {
        let settings = Settings.current
        rememberMasterKeysSwitch.isOn = settings.isRememberDatabaseKey
        rememberFinalKeysCell.setEnabled(settings.isRememberDatabaseKey)
        rememberFinalKeysSwitch.isEnabled = settings.isRememberDatabaseKey
        rememberFinalKeysSwitch.isOn = settings.isRememberDatabaseFinalKey

        rememberUsedKeyFiles.isOn = settings.isKeepKeyFileAssociations
        universalClipboardSwitch.isOn = settings.isUniversalClipboardEnabled
        hideProtectedFieldsSwitch.isOn = settings.isHideProtectedFields
        databaseTimeoutCell.detailTextLabel?.text = settings.databaseLockTimeout.shortTitle

        lockDatabaseOnTimeoutSwitch.isOn = settings.isLockDatabasesOnTimeout
        lockDatabaseOnTimeoutPremiumBadge.isHidden = true
        lockDatabaseOnTimeoutLabel.accessibilityLabel =
            AccessibilityHelper.decorateAccessibilityLabel(
                premiumFeature: lockDatabaseOnTimeoutLabel.text,
                isEnabled: true
            )

        clipboardTimeoutCell.detailTextLabel?.text = settings.clipboardTimeout.shortTitle

        shakeGestureCell.detailTextLabel?.text = settings.shakeGestureAction.shortTitle
    }


    @IBAction private func didToggleRememberMasterKeys(_ sender: UISwitch) {
        Settings.current.isRememberDatabaseKey = rememberMasterKeysSwitch.isOn
        let isRemember = Settings.current.isRememberDatabaseKey
        refresh()
        showNotificationIfManaged(setting: .rememberDatabaseKey)
        if !isRemember {
            didPressClearMasterKeys(self)
        }
    }

    @IBAction private func didToggleRememberFinalKeys(_ sender: UISwitch) {
        Settings.current.isRememberDatabaseFinalKey = rememberFinalKeysSwitch.isOn
        let isRemember = Settings.current.isRememberDatabaseFinalKey
        refresh()
        showNotificationIfManaged(setting: .rememberDatabaseFinalKey)
        if !isRemember {
            rememberFinalKeysLabel.flashColor(to: .destructiveTint, duration: 0.7)
            DatabaseSettingsManager.shared.eraseAllFinalKeys()
            Diag.info("Final keys erased successfully")
        }
    }

    @IBAction private func didPressClearMasterKeys(_ sender: Any) {
        DatabaseSettingsManager.shared.eraseAllMasterKeys()
        let confirmationAlert = UIAlertController.make(
            title: LString.masterKeysClearedTitle,
            message: LString.masterKeysClearedMessage,
            dismissButtonTitle: LString.actionOK)
        present(confirmationAlert, animated: true, completion: nil)
    }

    @IBAction private func didToggleRememberUsedKeyFiles(_ sender: UISwitch) {
        Settings.current.isKeepKeyFileAssociations = sender.isOn
        showNotificationIfManaged(setting: .keepKeyFileAssociations)
        refresh()
    }

    @IBAction private func didPressClearKeyFileAssociations(_ sender: Any) {
        DatabaseSettingsManager.shared.forgetAllKeyFiles()
        let confirmationAlert = UIAlertController.make(
            title: LString.keyFileAssociationsClearedTitle,
            message: LString.keyFileAssociationsClearedMessage,
            dismissButtonTitle: LString.actionOK)
        present(confirmationAlert, animated: true, completion: nil)
    }

    @objc func didPressDatabaseTimeout(_ sender: Any) {
        delegate?.didPressDatabaseTimeout(in: self)
    }

    @IBAction private func didToggleLockDatabasesOnTimeoutSwitch(_ sender: UISwitch) {
        assert(delegate != nil, "This won't work without a delegate")
        delegate?.didToggleLockDatabasesOnTimeout(newValue: sender.isOn, in: self)
        refresh()
        showNotificationIfManaged(setting: .lockDatabasesOnTimeout)
    }

    func didPressClipboardTimeout(_ sender: Any) {
        delegate?.didPressClipboardTimeout(in: self)
    }

    @IBAction private func didToggleUniversalClipboardSwitch(_ sender: UISwitch) {
        Settings.current.isUniversalClipboardEnabled = sender.isOn
        refresh()
        showNotificationIfManaged(setting: .universalClipboardEnabled)
    }

    @IBAction private func didToggleHideProtectedFieldsSwitch(_ sender: UISwitch) {
        Settings.current.isHideProtectedFields = sender.isOn
        refresh()
        showNotificationIfManaged(setting: .hideProtectedFields)
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case databaseTimeoutCell:
            delegate?.didPressDatabaseTimeout(in: self)
        case clipboardTimeoutCell:
            delegate?.didPressClipboardTimeout(in: self)
        case shakeGestureCell:
            delegate?.didPressShakeGestureAction(in: self)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let number = super.tableView(tableView, numberOfRowsInSection: section)
        if section == 1 && ProcessInfo.isRunningOnMac { // Hide "When shaken" on macOS
            return number - 1
        } else {
            return number
        }

    }
}

extension SettingsDataProtectionVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}
