//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsBackupVC: UITableViewController {

    @IBOutlet weak var enableDatabaseBackupSwitch: UISwitch!
    @IBOutlet weak var showBackupFilesSwitch: UISwitch!
    @IBOutlet weak var backupDurationCell: UITableViewCell!
    @IBOutlet weak var deleteAllBackupsButton: UIButton!
    
    private var settingsNotifications: SettingsNotifications!
    
    static func create() -> SettingsBackupVC {
        let vc = SettingsBackupVC.instantiateFromStoryboard()
        return vc
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
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
        let backupFileCount = FileKeeper.shared.getBackupFiles().count
        enableDatabaseBackupSwitch.isOn = settings.isBackupDatabaseOnSave
        showBackupFilesSwitch.isOn = settings.isBackupFilesVisible
        backupDurationCell.detailTextLabel?.text = settings.backupKeepingDuration.shortTitle
        if backupFileCount > 0 {
            deleteAllBackupsButton.isEnabled = true
            deleteAllBackupsButton.setTitle(
                "Delete ALL Backup Files (\(backupFileCount))".localized(comment: "Action to delete all backup files from the app. `ALL` is in capitals as a highlight."),
                for: .normal)
        } else {
            deleteAllBackupsButton.isEnabled = false
            deleteAllBackupsButton.setTitle(
                "No Backup Files Found".localized(comment: "Status message: there are no backup files to delete"),
                for: .normal)
        }
    }

    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case backupDurationCell:
            didPressBackupDuration()
        default:
            break
        }
    }
    
    
    @IBAction func didToggleEnableDatabaseBackup(_ sender: UISwitch) {
        Settings.current.isBackupDatabaseOnSave = enableDatabaseBackupSwitch.isOn
        refresh()
    }
    
    @IBAction func didToggleShowBackupFiles(_ sender: UISwitch) {
        Settings.current.isBackupFilesVisible = showBackupFilesSwitch.isOn
        refresh()
    }

    func didPressBackupDuration() {
        let durationPicker = SettingsBackupTimeoutPickerVC.create(delegate: self)
        show(durationPicker, sender: self)
    }
    
    @IBAction func didPressDeleteAllBackupFiles(_ sender: Any) {
        let confirmationAlert = UIAlertController.make(
            title: "Delete all backup files?".localized(comment: "Confirmation dialog message to delete all backup files"),
            message: nil,
            cancelButtonTitle: LString.actionCancel)
        let deleteAction = UIAlertAction(
            title: LString.actionDelete,
            style: .destructive,
            handler: { [weak self] (action) in
                FileKeeper.shared.deleteBackupFiles(olderThan: -TimeInterval.infinity) 
                self?.refresh()
            }
        )
        confirmationAlert.addAction(deleteAction)
        present(confirmationAlert, animated: true, completion: nil)
    }
}

extension SettingsBackupVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

extension SettingsBackupVC: SettingsBackupTimeoutPickerDelegate {
    func didFinish(_ viewController: SettingsBackupTimeoutPickerVC) {
        navigationController?.popViewController(animated: true)
    }
}
