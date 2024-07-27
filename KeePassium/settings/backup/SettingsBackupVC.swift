//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

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
        title = LString.titleDatabaseBackupSettings
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
                LString.actionDeleteAllBackupFilesTemplate,
                backupFileCount)
            deleteAllBackupsButton.setTitle(buttonTitle, for: .normal)
        } else {
            deleteAllBackupsButton.isEnabled = false
            deleteAllBackupsButton.setTitle(
                LString.noBackupFilesFound,
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


    @IBAction private func didToggleEnableDatabaseBackup(_ sender: UISwitch) {
        Settings.current.isBackupDatabaseOnSave = enableDatabaseBackupSwitch.isOn
        refresh()
        showNotificationIfManaged(setting: .backupDatabaseOnSave)
    }

    @IBAction private func didToggleShowBackupFiles(_ sender: UISwitch) {
        Settings.current.isBackupFilesVisible = showBackupFilesSwitch.isOn
        refresh()
        showNotificationIfManaged(setting: .backupFilesVisible)
    }

    func didPressBackupDuration() {
        let durationPicker = SettingsBackupTimeoutPickerVC.create(delegate: self)
        show(durationPicker, sender: self)
    }

    @IBAction private func didToggleExcludeFromSystemBackup(_ sender: UISwitch) {
        Settings.current.isExcludeBackupFilesFromSystemBackup = excludeFromSystemBackupSwitch.isOn
        let isExclude = Settings.current.isExcludeBackupFilesFromSystemBackup
        showNotificationIfManaged(setting: .excludeBackupFilesFromSystemBackup)

        excludeFromSystemBackupSwitch.isEnabled = false
        DispatchQueue.main.async { [weak self] in
            self?.applyExcludeFromSystemBackup(isExclude)
            self?.excludeFromSystemBackupSwitch.isEnabled = true
        }
    }

    @IBAction private func didPressDeleteAllBackupFiles(_ sender: Any) {
        let confirmationAlert = UIAlertController.make(
            title: LString.confirmDeleteAllBackupFiles,
            message: nil,
            dismissButtonTitle: LString.actionCancel)
        let deleteAction = UIAlertAction(
            title: LString.actionDelete,
            style: .destructive,
            handler: { [weak self] _ in
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
                keepLatest: false, 
                completionQueue: .main,
                completion: { [weak self] in
                    self?.backupDeletionSpinner.isHidden = true
                    self?.refresh()
                }
            )
        }
    }

    private func applyExcludeFromSystemBackup(_ isExclude: Bool) {
        let backupFileRefs = FileKeeper.shared.getBackupFiles()
        var successCounter = 0
        for ref in backupFileRefs {
            guard var url = try? ref.resolveSync() else {
                continue
            }
            guard url.setFileAttribute(.excludedFromBackup, to: isExclude) else {
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
