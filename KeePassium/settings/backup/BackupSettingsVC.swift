//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class BackupSettingsVC: BaseSettingsViewController<BackupSettingsVC.Section> {
    protocol Delegate: AnyObject {
        func didChangeBackupEnabled(_ isOn: Bool, in viewController: BackupSettingsVC)
        func didChangeShowBackupFiles(_ isOn: Bool, in viewController: BackupSettingsVC)
        func didChangeExcludeFromSystemBackup(_ isExclude: Bool, in viewController: BackupSettingsVC)
        func didChangeCleanupInterval(
            _ interval: Settings.BackupKeepingDuration,
            in viewController: BackupSettingsVC)
        func didPressDeleteAllBackups(in viewController: BackupSettingsVC)
    }

    weak var delegate: (any Delegate)?

    var backupFilesCount: Int = 0
    var isBackupEnabled = false
    var isShowBackupFiles = false
    var isExcludeFromSystemBackup = false
    var cleanupInterval: Settings.BackupKeepingDuration = .forever

    override init() {
        super.init()
        title = LString.databaseBackupSettingsTitle
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    enum Section: SettingsSection {
        case general
        case view
        case systemBackup
        case cleanup

        var header: String? {
            switch self {
            case .general, .view:
                return nil
            case .systemBackup:
                return LString.systemBackupTitle
            case .cleanup:
                return LString.databaseBackupCleanupTitle
            }
        }

        var footer: String? {
            switch self {
            case .general:
                return LString.makeBackupCopiesDescription
            case .view:
                return LString.showBackupFilesDescription
            case .systemBackup:
                return LString.excludeFromSystemBackupDescription
            case .cleanup:
                return LString.databaseBackupCleanupDescription
            }
        }
    }

    override func refresh() {
        assert(_dataSource != nil)
        assert(_collectionView != nil)
        var snapshot = NSDiffableDataSourceSnapshot<Section, SettingsItem>()

        snapshot.appendSections([.general])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.makeBackupCopiesTitle,
                isOn: isBackupEnabled,
                handler: { [unowned self] itemConfig in
                    isBackupEnabled = itemConfig.isOn
                    refresh()
                    delegate?.didChangeBackupEnabled(isBackupEnabled, in: self)
                }
            ))
        ])

        snapshot.appendSections([.view])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.titleShowBackupFiles,
                isOn: isShowBackupFiles,
                handler: { [unowned self] itemConfig in
                    isShowBackupFiles = itemConfig.isOn
                    refresh()
                    delegate?.didChangeShowBackupFiles(isShowBackupFiles, in: self)
                }
            ))
        ])

        snapshot.appendSections([.systemBackup])
        snapshot.appendItems([
            .toggle(.init(
                title: LString.excludeFromSystemBackupTitle,
                isOn: isExcludeFromSystemBackup,
                handler: { [unowned self] itemConfig in
                    isExcludeFromSystemBackup = itemConfig.isOn
                    refresh()
                    delegate?.didChangeExcludeFromSystemBackup(isExcludeFromSystemBackup, in: self)
                }
            ))
        ])

        snapshot.appendSections([.cleanup])
        snapshot.appendItems([
            .picker(.init(
                title: LString.databaseBackupKeepingDurationTitle,
                value: cleanupInterval.title,
                menu: makeCleanupIntervalsMenu()
            ))
        ])

        let deleteAllItem: SettingsItem
        if backupFilesCount > 0 {
            deleteAllItem = .basic(.init(
                title: String.localizedStringWithFormat(
                    LString.actionDeleteAllBackupFilesTemplate,
                    backupFilesCount),
                decorators: [.destructive, .action],
                handler: { [unowned self] in
                    delegate?.didPressDeleteAllBackups(in: self)
                }
            ))
        } else {
            deleteAllItem = .basic(.init(
                title: LString.noBackupFilesFoundTitle,
                isEnabled: false,
                handler: nil
            ))
        }
        snapshot.appendItems([deleteAllItem])

        _dataSource.apply(snapshot, animatingDifferences: true)
    }

    private func makeCleanupIntervalsMenu() -> UIMenu {
        let children = Settings.BackupKeepingDuration.allValues.map { option in
            UIAction(
                title: option.title,
                state: option == self.cleanupInterval ? .on : .off,
                handler: { [unowned self] _ in
                    self.cleanupInterval = option
                    refresh()
                    delegate?.didChangeCleanupInterval(option, in: self)
                }
            )
        }
        return UIMenu(inlineChildren: children)
    }
}

extension BackupSettingsVC: BusyStateIndicating {
    func indicateState(isBusy: Bool) {
        if isBusy {
            view.makeToastActivity(.center)
        } else {
            view.hideToastActivity()
        }
    }
}
