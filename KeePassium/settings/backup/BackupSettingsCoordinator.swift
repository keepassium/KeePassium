//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class BackupSettingsCoordinator: BaseCoordinator {
    internal let _backupSettingsVC: BackupSettingsVC

    override init(router: NavigationRouter) {
        _backupSettingsVC = BackupSettingsVC()
        super.init(router: router)
        _backupSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(_backupSettingsVC, animated: true)
        applySettingsToVC()
    }

    override func refresh() {
        super.refresh()
        applySettingsToVC()
        _backupSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        let s = Settings.current
        _backupSettingsVC.backupFilesCount = FileKeeper.shared.getBackupFiles().count
        _backupSettingsVC.isBackupEnabled = s.isBackupDatabaseOnSave
        _backupSettingsVC.isShowBackupFiles = s.isBackupFilesVisible
        _backupSettingsVC.isExcludeFromSystemBackup = s.isExcludeBackupFilesFromSystemBackup
        _backupSettingsVC.cleanupInterval = s.backupKeepingDuration
    }
}

extension BackupSettingsCoordinator {
    private func confirmAndDeleteAllBackupFiles(presenter: UIViewController) {
        let confirmationAlert = UIAlertController.make(
            title: LString.confirmDeleteAllBackupFiles,
            message: nil,
            dismissButtonTitle: LString.actionCancel)
        let deleteAction = UIAlertAction(
            title: LString.actionDelete,
            style: .destructive,
            handler: { [unowned self] _ in
                deleteAllBackupFiles()
            }
        )
        confirmationAlert.addAction(deleteAction)
        presenter.present(confirmationAlert, animated: true, completion: nil)
    }

    private func deleteAllBackupFiles() {
        _backupSettingsVC.indicateState(isBusy: true)
        FileKeeper.shared.deleteBackupFiles(
            olderThan: -TimeInterval.infinity,
            keepLatest: false,
            completionQueue: .main,
            completion: { [weak self] in
                self?._backupSettingsVC.indicateState(isBusy: false)
                self?.refresh()
            }
        )
    }
}

extension BackupSettingsCoordinator: BackupSettingsVC.Delegate {
    func didChangeBackupEnabled(_ isOn: Bool, in viewController: BackupSettingsVC) {
        Settings.current.isBackupDatabaseOnSave = isOn
        viewController.showNotificationIfManaged(setting: .backupDatabaseOnSave)
        refresh()
    }

    func didChangeShowBackupFiles(_ isOn: Bool, in viewController: BackupSettingsVC) {
        Settings.current.isBackupFilesVisible = isOn
        viewController.showNotificationIfManaged(setting: .backupFilesVisible)
        refresh()
    }

    func didChangeExcludeFromSystemBackup(_ isExclude: Bool, in viewController: BackupSettingsVC) {
        Settings.current.isExcludeBackupFilesFromSystemBackup = isExclude
        viewController.showNotificationIfManaged(setting: .excludeBackupFilesFromSystemBackup)
        refresh()
    }

    func didChangeCleanupInterval(
        _ interval: Settings.BackupKeepingDuration,
        in viewController: BackupSettingsVC
    ) {
        Settings.current.backupKeepingDuration = interval
        viewController.showNotificationIfManaged(setting: .backupKeepingDuration)
        refresh()
    }

    func didPressDeleteAllBackups(in viewController: BackupSettingsVC) {
        confirmAndDeleteAllBackupFiles(presenter: viewController)
    }
}
