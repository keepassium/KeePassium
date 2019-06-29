//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsDataProtectionVC: UITableViewController, Refreshable {

    @IBOutlet weak var rememberMasterKeysSwitch: UISwitch!
    @IBOutlet weak var clearMasterKeysButton: UIButton!
    
    @IBOutlet weak var rememberUsedKeyFiles: UISwitch!
    @IBOutlet weak var clearKeyFileAssociationsButton: UIButton!
    
    @IBOutlet weak var databaseTimeoutCell: UITableViewCell!
    @IBOutlet weak var lockDatabaseOnFailedPasscodeSwitch: UISwitch!
    
    @IBOutlet weak var clipboardTimeoutCell: UITableViewCell!
    
    private var settingsNotifications: SettingsNotifications!
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        settingsNotifications = SettingsNotifications(observer: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        rememberUsedKeyFiles.isOn = settings.isKeepKeyFileAssociations
        databaseTimeoutCell.detailTextLabel?.text = settings.databaseLockTimeout.shortTitle
        lockDatabaseOnFailedPasscodeSwitch.isOn = settings.isLockAllDatabasesOnFailedPasscode
        clipboardTimeoutCell.detailTextLabel?.text = settings.clipboardTimeout.shortTitle
    }
    
    
    @IBAction func didToggleRememberMasterKeys(_ sender: UISwitch) {
        Settings.current.isRememberDatabaseKey = rememberMasterKeysSwitch.isOn
        refresh()
    }
    
    @IBAction func didPressClearMasterKeys(_ sender: Any) {
        do {
            try Keychain.shared.removeAllDatabaseKeys() 
            let confirmationAlert = UIAlertController.make(
                title: NSLocalizedString("Cleared", comment: "Title of the success message for `Remove Master Keys` button"),
                message: NSLocalizedString("All master keys have been removed.", comment: "Success message for `Remove Master Keys` button"),
                cancelButtonTitle: LString.actionOK)
            present(confirmationAlert, animated: true, completion: nil)
        } catch {
            let errorAlert = UIAlertController.make(
                title: LString.titleKeychainError,
                message: error.localizedDescription,
                cancelButtonTitle: LString.actionDismiss)
            present(errorAlert, animated: true, completion: nil)
        }
    }
    
    @IBAction func didToggleRememberUsedKeyFiles(_ sender: UISwitch) {
        Settings.current.isKeepKeyFileAssociations = rememberUsedKeyFiles.isOn
        refresh()
    }
    
    @IBAction func didPressClearKeyFileAssociations(_ sender: Any) {
        Settings.current.removeAllKeyFileAssociations()
        let confirmationAlert = UIAlertController.make(
            title: NSLocalizedString("Cleared", comment: "Title of the success message for `Clear Key File Associations` button"),
            message: NSLocalizedString("Associations between key files and databases have been removed.", comment: "Success message for `Clear Key File Associations` button"),
            cancelButtonTitle: LString.actionOK)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    @objc func didPressDatabaseTimeout(_ sender: Any) {
        let databaseTimeoutVC = SettingsDatabaseTimeoutVC.make()
        show(databaseTimeoutVC, sender: self)
    }

    @IBAction func didToggleLockDatabaseOnFailedPasscode(_ sender: UISwitch) {
        Settings.current.isLockAllDatabasesOnFailedPasscode = lockDatabaseOnFailedPasscodeSwitch.isOn
        refresh()
    }
    
    func didPressClipboardTimeout(_ sender: Any) {
        let clipboardTimeoutVC = SettingsClipboardTimeoutVC.make()
        show(clipboardTimeoutVC, sender: self)
    }

    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case databaseTimeoutCell:
            didPressDatabaseTimeout(selectedCell)
        case clipboardTimeoutCell:
            didPressClipboardTimeout(selectedCell)
        default:
            break
        }
    }
}

extension SettingsDataProtectionVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        refresh()
    }
}
