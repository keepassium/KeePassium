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
    
    @IBOutlet weak var clipboardTimeoutCell: UITableViewCell!
    
    private var settingsNotifications: SettingsNotifications!
    private var premiumUpgradeHelper = PremiumUpgradeHelper()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
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
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }

    func refresh() {
        let settings = Settings.current
        rememberMasterKeysSwitch.isOn = settings.isRememberDatabaseKey
        rememberUsedKeyFiles.isOn = settings.premiumIsKeepKeyFileAssociations
        databaseTimeoutCell.detailTextLabel?.text = settings.premiumDatabaseLockTimeout.shortTitle
        clipboardTimeoutCell.detailTextLabel?.text = settings.clipboardTimeout.shortTitle
    }
    
    @objc func refreshPremiumStatus() {
        refresh()
    }
    
    
    @IBAction func didToggleRememberMasterKeys(_ sender: UISwitch) {
        Settings.current.isRememberDatabaseKey = rememberMasterKeysSwitch.isOn
        refresh()
    }
    
    @IBAction func didPressClearMasterKeys(_ sender: Any) {
        DatabaseSettingsManager.shared.eraseAllMasterKeys()
        let confirmationAlert = UIAlertController.make(
            title: NSLocalizedString(
                "[Settings/ClearMasterKeys/Cleared/title] Cleared",
                value: "Cleared",
                comment: "Title of the success message for `Clear Master Keys` button"),
            message: NSLocalizedString(
                "[Settings/ClearMasterKeys/Cleared/text] All master keys have been deleted.",
                value: "All master keys have been deleted.",
                comment: "Text of the success message for `Clear Master Keys` button"),
            cancelButtonTitle: LString.actionOK)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    @IBAction func didToggleRememberUsedKeyFiles(_ sender: UISwitch) {
        Settings.current.isKeepKeyFileAssociations = sender.isOn
        refresh()
    }
    
    @IBAction func didPressClearKeyFileAssociations(_ sender: Any) {
        DatabaseSettingsManager.shared.forgetAllKeyFiles()
        let confirmationAlert = UIAlertController.make(
            title: NSLocalizedString(
                "[Settings/ClearKeyFileAssociations/Cleared/title] Cleared",
                value: "Cleared",
                comment: "Title of the success message for `Clear Key File Associations` button"),
            message: NSLocalizedString(
                "[Settings/ClearKeyFileAssociations/Cleared/text] Associations between key files and databases have been removed.",
                value: "Associations between key files and databases have been removed.",
                comment: "Text of the success message for `Clear Key File Associations` button"),
            cancelButtonTitle: LString.actionOK)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    @objc func didPressDatabaseTimeout(_ sender: Any) {
        let databaseTimeoutVC = SettingsDatabaseTimeoutVC.make()
        show(databaseTimeoutVC, sender: self)
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
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}
