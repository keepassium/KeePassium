//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol SettingsDataProtectionViewCoordinatorDelegate: AnyObject {
    func didPressDatabaseTimeout(in viewController: SettingsDataProtectionVC)
    func didPressClipboardTimeout(in viewController: SettingsDataProtectionVC)
    func didToggleLockDatabasesOnTimeout(newValue: Bool, in viewController: SettingsDataProtectionVC)
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
    
    weak var delegate: SettingsDataProtectionViewCoordinatorDelegate?
    
    private var settingsNotifications: SettingsNotifications!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        settingsNotifications = SettingsNotifications(observer: self)
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
        
        rememberUsedKeyFiles.isOn = settings.premiumIsKeepKeyFileAssociations
        universalClipboardSwitch.isOn = settings.isUniversalClipboardEnabled
        hideProtectedFieldsSwitch.isOn = settings.isHideProtectedFields
        databaseTimeoutCell.detailTextLabel?.text = settings.premiumDatabaseLockTimeout.shortTitle
        
        lockDatabaseOnTimeoutSwitch.isOn = settings.premiumIsLockDatabasesOnTimeout
        let canKeepMasterKeyOnDatabaseTimeout =
            PremiumManager.shared.isAvailable(feature: .canKeepMasterKeyOnDatabaseTimeout)
        lockDatabaseOnTimeoutPremiumBadge.isHidden = canKeepMasterKeyOnDatabaseTimeout
        lockDatabaseOnTimeoutLabel.accessibilityLabel =
            AccessibilityHelper.decorateAccessibilityLabel(
                premiumFeature: lockDatabaseOnTimeoutLabel.text,
                isEnabled: canKeepMasterKeyOnDatabaseTimeout
            )
        
        clipboardTimeoutCell.detailTextLabel?.text = settings.clipboardTimeout.shortTitle
    }
    
    
    @IBAction func didToggleRememberMasterKeys(_ sender: UISwitch) {
        let isRemember = rememberMasterKeysSwitch.isOn
        Settings.current.isRememberDatabaseKey = isRemember
        refresh()
        if !isRemember {
            didPressClearMasterKeys(self)
        }
    }
    
    @IBAction func didToggleRememberFinalKeys(_ sender: UISwitch) {
        let isRemember = rememberFinalKeysSwitch.isOn
        Settings.current.isRememberDatabaseFinalKey = isRemember
        refresh()
        if !isRemember {
            rememberFinalKeysLabel.flashColor(to: .destructiveTint, duration: 0.7)
            DatabaseSettingsManager.shared.eraseAllFinalKeys()
            Diag.info("Final keys erased successfully")
        }
    }
    
    @IBAction func didPressClearMasterKeys(_ sender: Any) {
        DatabaseSettingsManager.shared.eraseAllMasterKeys()
        let confirmationAlert = UIAlertController.make(
            title: LString.masterKeysClearedTitle,
            message: LString.masterKeysClearedMessage,
            dismissButtonTitle: LString.actionOK)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    @IBAction func didToggleRememberUsedKeyFiles(_ sender: UISwitch) {
        Settings.current.isKeepKeyFileAssociations = sender.isOn
        refresh()
    }
    
    @IBAction func didPressClearKeyFileAssociations(_ sender: Any) {
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
    
    @IBAction func didToggleLockDatabasesOnTimeoutSwitch(_ sender: UISwitch) {
        assert(delegate != nil, "This won't work without a delegate")
        delegate?.didToggleLockDatabasesOnTimeout(newValue: sender.isOn, in: self)
        refresh()
    }
    
    func didPressClipboardTimeout(_ sender: Any) {
        delegate?.didPressClipboardTimeout(in: self)
    }

    @IBAction func didToggleUniversalClipboardSwitch(_ sender: UISwitch) {
        Settings.current.isUniversalClipboardEnabled = sender.isOn
        refresh()
    }
    
    @IBAction func didToggleHideProtectedFieldsSwitch(_ sender: UISwitch) {
        Settings.current.isHideProtectedFields = sender.isOn
        refresh()
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case databaseTimeoutCell:
            delegate?.didPressDatabaseTimeout(in: self)
        case clipboardTimeoutCell:
            delegate?.didPressClipboardTimeout(in: self)
        default:
            break
        }
    }
}

extension SettingsDataProtectionVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}
