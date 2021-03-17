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
    @IBOutlet weak var backupDeletionSpinner: UIActivityIndicatorView!
    @IBOutlet weak var excludeFromSystemBackupSwitch: UISwitch!
    
    private var settingsNotifications: SettingsNotifications!
    private var fileKeeperNotifications: FileKeeperNotifications!
    
    static func create() -> SettingsBackupVC {
        let vc = SettingsBackupVC.instantiateFromStoryboard()
        return vc
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsNotifications = SettingsNotifications(observer: self)
        fileKeeperNotifications = FileKeeperNotifications(observer: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsNotifications.startObserving()
        fileKeeperNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        fileKeeperNotifications.stopObserving()
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }

    
    func refresh() {
        let settings = Settings.current
        let backupFileCount = FileKeeper.shared.getBackupFiles().count
        enableDatabaseBackupSwitch.isOn = settings.isBackupDatabaseOnSave
        showBackupFilesSwitch.isOn = settings.isBackupFilesVisible
        excludeFromSystemBackupSwitch.isOn = settings.isExcludeBackupFilesFromSystemBackup
        backupDurationCell.detailTextLabel?.text = settings.backupKeepingDuration.shortTitle
        if backupFileCount > 0 {
            deleteAllBackupsButton.isEnabled = true
            let buttonTitle = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Settings/Backup] Delete ALL Backup Files (%d)",
                    value: "Delete ALL Backup Files (%d)",
                    comment: "Action to delete all backup files from the app. `ALL` is in capitals as a highlight. [backupFileCount: Int]"),
                backupFileCount)
            deleteAllBackupsButton.setTitle(buttonTitle, for: .normal)
        } else {
            deleteAllBackupsButton.isEnabled = false
            deleteAllBackupsButton.setTitle(
                NSLocalizedString(
                    "[Settings/Backup] No Backup Files Found",
                    value: "No Backup Files Found",
                    comment: "Status message: there are no backup files to delete"),
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

    @IBAction func didToggleExcludeFromSystemBackup(_ sender: UISwitch) {
        let isExclude = excludeFromSystemBackupSwitch.isOn
        Settings.current.isExcludeBackupFilesFromSystemBackup = isExclude
        
        excludeFromSystemBackupSwitch.isEnabled = false
        DispatchQueue.main.async { [weak self] in
            self?.applyExcludeFromSystemBackup(isExclude)
            self?.excludeFromSystemBackupSwitch.isEnabled = true
        }
    }
    
    @IBAction func didPressDeleteAllBackupFiles(_ sender: Any) {
        let confirmationAlert = UIAlertController.make(
            title: NSLocalizedString(
                "[Settings/Backup/Delete/title] Delete all backup files?",
                value: "Delete all backup files?",
                comment: "Confirmation dialog message to delete all backup files"),
            message: nil,
            dismissButtonTitle: LString.actionCancel)
        let deleteAction = UIAlertAction(
            title: LString.actionDelete,
            style: .destructive,
            handler: { [weak self] (action) in
                self?.deleteAllBackupFiles()
            }
        )
        confirmationAlert.addAction(deleteAction)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    private func deleteAllBackupFiles() {
        backupDeletionSpinner.isHidden = false
        DispatchQueue.main.async { [self] in 
            FileKeeper.shared.deleteBackupFiles(
                olderThan: -TimeInterval.infinity,
                keepLatest: false) 
            self.backupDeletionSpinner.isHidden = true
            self.refresh()
        }
    }
    
    private func applyExcludeFromSystemBackup(_ isExclude: Bool) {
        let backupFileRefs = FileKeeper.shared.getBackupFiles()
        var successCounter = 0
        for ref in backupFileRefs {
            guard var url = try? ref.resolveSync() else {
                continue
            }
            guard url.setExcludedFromBackup(isExclude) else {
                Diag.debug("Failed to exclude backup file from backup [file: \(url.lastPathComponent)]")
                continue
            }
            successCounter += 1
        }
        Diag.info("Backup files \(isExclude ? "excluded from" : "included to") system backup [total: \(backupFileRefs.count), changed: \(successCounter)]")
    }
}


extension SettingsBackupVC: FileKeeperObserver {
    func fileKeeper(didRemoveFile urlRef: URLReference, fileType: FileType) {
        refresh()
    }
    func fileKeeper(didAddFile urlRef: URLReference, fileType: FileType) {
        refresh()
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
