//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension LString {
    // swiftlint:disable line_length
    public static let databaseBackupSettingsTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/title]",
        value: "Database Backup",
        comment: "Title of a settings section: backup of databases")
    public static let makeBackupCopiesTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/Active/title]",
        value: "Make Backup Copies",
        comment: "Title of a yes/no setting: whether to back up databases before saving them")
    public static let makeBackupCopiesDescription = NSLocalizedString(
        "[Settings/DatabaseBackup/Active/description]",
        value: "Before saving a database, KeePassium will automatically make a copy, just in case.",
        comment: "Description of the 'Make Backup Copies' setting")

    public static let showBackupFilesDescription = NSLocalizedString(
        "[Settings/DatabaseBackup/ShowBackupFiles/description]",
        value: "Backup copies will appear along with the original files.",
        comment: "Description of the 'Show Backup Files' setting")

    public static let systemBackupTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/SystemBackup/title]",
        value: "iTunes and iCloud Backup",
        comment: "Section header, refers to Apple's backup services (https://support.apple.com/HT203977)")
    public static let excludeFromSystemBackupTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/ExcludeFromSystemBackup/title]",
        value: "Exclude Backup Files from System Backup",
        comment: "Title of a yes/no setting: whether app's internal backup copies should be excluded from global system backup")
    public static let excludeFromSystemBackupDescription = NSLocalizedString(
        "[Settings/DatabaseBackup/ExcludeFromSystemBackup/description]",
        value: "Defines whether backup databases created by KeePassium should be excluded from iCloud/iTunes backup. Applies to all the existing and future backup files.",
        comment: "Description of the 'Exclude Backup Files from System Backup' setting")

    public static let databaseBackupCleanupTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/PeriodicCleanup/title]",
        value: "Periodic Cleanup",
        comment: "Settings section: automatic deletion of old backup files")
    public static let databaseBackupCleanupDescription = NSLocalizedString(
        "[Settings/DatabaseBackup/PeriodicCleanup/description]",
        value: "KeePassium can automatically delete old backup files to free up some storage space.",
        comment: "Description of the `Periodic Cleanup` settings")
    public static let databaseBackupKeepingDurationTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/KeepingDuration/title]",
        value: "Keep Backup Files",
        comment: "Setting title: how long to keep backup copies. For example: `Keep Backup Files: 3 days`")

    public static let actionDeleteAllBackupFilesTemplate = NSLocalizedString(
        "[Settings/DatabaseBackup/DeleteAll/title]",
        value: "Delete ALL Backup Files (%d)",
        comment: "Action to delete all backup files from the app. `ALL` is in capitals as a highlight. [backupFileCount: Int]")
    public static let confirmDeleteAllBackupFiles = NSLocalizedString(
        "[Settings/DatabaseBackup/DeleteAll/confirm]",
        value: "Delete all backup files?",
        comment: "Confirmation dialog message to delete all backup files")
    public static let noBackupFilesFoundTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/NoFiles/title]",
        value: "No Backup Files Found",
        comment: "Status message: there are no backup files to delete")

    public static let databaseBackupKeepingDurationForeverTitle = NSLocalizedString(
        "[Settings/DatabaseBackup/KeepingDuration/Forever/title]",
        value: "Forever",
        comment: "Setting title: how long to keep backup copies. Example: 'Keep Backup Files: Forever'")
    // swiftlint:enable line_length
}

extension Settings.BackupKeepingDuration {
    public var title: String {
        switch self {
        case .forever:
            return LString.databaseBackupKeepingDurationForeverTitle
        default:
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.year, .month, .day, .hour]
            formatter.collapsesLargestUnit = true
            formatter.maximumUnitCount = 1
            formatter.unitsStyle = .full
            guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                assertionFailure()
                return "?"
            }
            return result
        }
    }
}
