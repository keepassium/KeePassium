//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class Settings {
    public static let latestVersion = 6
    public static let current = Settings()

    public enum Keys: String {
        case testEnvironment
        case settingsVersion
        case bundleCreationTimestamp
        case bundleModificationTimestamp
        case firstLaunchTimestamp

        case filesSortOrder
        case backupFilesVisible

        case startupDatabase
        case autoUnlockStartupDatabase
        case rememberDatabaseKey
        case rememberDatabaseFinalKey
        case keepKeyFileAssociations
        case keepHardwareKeyAssociations
        case hardwareKeyAssociations

        case appLockEnabled
        case biometricAppLockEnabled
        case lockAllDatabasesOnFailedPasscode
        case recentUserActivityTimestamp
        case appLockTimeout
        case lockAppOnLaunch
        case lockAppOnScreenLock
        case databaseLockTimeout
        case lockDatabasesOnTimeout
        case lockDatabasesOnReboot
        case lockDatabasesOnScreenLock
        case passcodeAttemptsBeforeAppReset
        case passcodeKeyboardType

        case clipboardTimeout
        case universalClipboardEnabled

        case shakeGestureAction
        case confirmShakeGestureAction

        case databaseIconSet
        case groupSortOrder
        case entryListDetail
        case entryViewerPage
        case rememberEntryViewerPage
        case hideProtectedFields
        case collapseNotesField

        case startWithSearch
        case searchFieldNames
        case searchProtectedValues
        case searchPasswords

        case backupDatabaseOnSave
        case backupKeepingDuration
        case excludeBackupFilesFromSystemBackup

        case autoFillFinishedOK
        case copyTOTPOnAutoFill
        case autoFillPerfectMatch
        case acceptAutoFillInput
        case quickTypeEnabled
        case autoFillContextSavingMode
        case autoFillContextSavingModeChosenTimestamp
        case autoFillIncludeExpiredEntries
        case autoFillIncludeEntriesWithAutoFillDisabled
        case autoFillIncludeGroupsWithAutoFillDisabled

        case hapticFeedbackEnabled

        case passwordGeneratorConfig

        case networkAccessAllowed

        case autoDownloadFaviconsEnabled

        case hideAppLockSetupReminder
        case textScale
        case entryTextFontDescriptor
        case fieldMenuMode
        case primaryPaneWidthFraction

        case keyFileEntryProtected
    }

    internal enum Notifications {
        static let settingsChanged = Notification.Name("com.keepassium.SettingsChanged")
        static let userInfoKey = "changedKey" 
    }

    public private(set) var isTestEnvironment: Bool

    public private(set) var isFirstLaunch: Bool

    public var settingsVersion: Int {
        get {
            let storedVersion = UserDefaults.appGroupShared
                .object(forKey: Keys.settingsVersion.rawValue)
                as? Int
            return storedVersion ?? SettingsMigrator.initialSettingsVersion
        }
        set {
            let oldValue = settingsVersion
            UserDefaults.appGroupShared.set(newValue, forKey: Keys.settingsVersion.rawValue)
            if newValue != oldValue {
                _postChangeNotification(changedKey: Keys.settingsVersion)
            }
        }
    }

    public var firstLaunchTimestamp: Date {
        if let storedTimestamp = UserDefaults.appGroupShared
                .object(forKey: Keys.firstLaunchTimestamp.rawValue) as? Date
        {
            return storedTimestamp
        } else {
            let firstLaunchTimestamp = Date.now
            UserDefaults.appGroupShared.set(
                firstLaunchTimestamp,
                forKey: Keys.firstLaunchTimestamp.rawValue)
            return firstLaunchTimestamp
        }
    }

#if DEBUG
    public func resetFirstLaunchTimestampToNow() {
        UserDefaults.appGroupShared.set(
            Date.now,
            forKey: Keys.firstLaunchTimestamp.rawValue)
    }
#endif

    internal var _cachedUserActivityTimestamp: Date?
    internal let _timestampCacheValidityInterval = 1.0

    private init() {
        #if DEBUG
        isTestEnvironment = true
        #else
        if AppGroup.isMainApp {
            isTestEnvironment = ProcessInfo.isTestFlightApp
            UserDefaults.appGroupShared.set(isTestEnvironment, forKey: Keys.testEnvironment.rawValue)
        } else {
            isTestEnvironment = UserDefaults.appGroupShared
                .object(forKey: Keys.testEnvironment.rawValue) as? Bool
                ?? false
        }
        #endif

        isFirstLaunch = Settings.maybeHandleFirstLaunch()
    }

    private static func maybeHandleFirstLaunch() -> Bool {
        guard ProcessInfo.isRunningOnMac else {
            let versionInfo = UserDefaults.appGroupShared
                .object(forKey: Keys.settingsVersion.rawValue) as? Int
            return (versionInfo == nil)
        }

        #if DEBUG
        return false
        #endif


        guard let bundleAttributes = try? FileManager.default
                .attributesOfItem(atPath: Bundle.mainAppURL.path),
              let bundleCreationDate = bundleAttributes[.creationDate] as? Date,
              let bundleModificationDate = bundleAttributes[.modificationDate] as? Date
        else {
            Diag.warning("Failed to read app bundle creation/modification date, ignoring")
            UserDefaults.eraseAppGroupShared()
            return true
        }

        let storedCreationDate: Date? = UserDefaults.appGroupShared
            .object(forKey: Keys.bundleCreationTimestamp.rawValue)
            as? Date
        let storedModificationDate: Date? = UserDefaults.appGroupShared
            .object(forKey: Keys.bundleModificationTimestamp.rawValue)
            as? Date
        let hasStoredDate = storedCreationDate != nil
        let isCreationDateChanged =
            (storedCreationDate != nil) &&
            abs(bundleCreationDate.timeIntervalSince(storedCreationDate!)) > 1.0
        let isModificationDateChanged =
            (storedModificationDate != nil) &&
            abs(bundleModificationDate.timeIntervalSince(storedModificationDate!)) > 1.0

        defer {
            UserDefaults.appGroupShared.set(
                bundleCreationDate,
                forKey: Keys.bundleCreationTimestamp.rawValue)
            UserDefaults.appGroupShared.set(
                bundleModificationDate,
                forKey: Keys.bundleModificationTimestamp.rawValue)
        }

        switch (hasStoredDate, isCreationDateChanged, isModificationDateChanged) {
        case (false, _, _):
            Diag.debug("First launch ever")
        case (true, true, _): 
            Diag.debug("App version updated")
            return false
        case (true, false, true): 
            Diag.debug("App reinstall detected, handling as first launch")
        case (true, false, false): 
            return false
        }

        UserDefaults.eraseAppGroupShared()
        return true
    }


    internal func _updateAndNotify(oldValue: Bool, newValue: Bool, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            _postChangeNotification(changedKey: key)
        }
    }

    internal func _updateAndNotify<T: SignedNumeric>(oldValue: T, newValue: T, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            _postChangeNotification(changedKey: key)
        }
    }

    internal func _updateAndNotify(oldValue: String, newValue: String, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            _postChangeNotification(changedKey: key)
        }
    }

    internal func _contains(key: Keys) -> Bool {
        return UserDefaults.appGroupShared.object(forKey: key) != nil
    }

    internal func _postChangeNotification(changedKey: Settings.Keys) {
        NotificationCenter.default.post(
            name: Notifications.settingsChanged,
            object: self,
            userInfo: [
                Notifications.userInfoKey: changedKey.rawValue
            ]
        )
    }
}

internal extension Settings {
    func migrateFileReferencesToKeychain() {
        Diag.debug("Migrating file references to keychain")
        if let startDatabaseRefData = UserDefaults.appGroupShared.data(forKey: .startupDatabase) {
            let startDatabaseRef = URLReference.deserialize(from: startDatabaseRefData)
            self.startupDatabase = startDatabaseRef
            UserDefaults.appGroupShared.removeObject(forKey: Keys.startupDatabase.rawValue)
        }
    }

    func migrateUserActivityTimestampToKeychain() {
        let defaults = UserDefaults.appGroupShared
        guard let storedTimestamp = defaults.object(forKey: Keys.recentUserActivityTimestamp.rawValue) as? Date
        else {
            return
        }
        defaults.removeObject(forKey: Keys.recentUserActivityTimestamp.rawValue)
        recentUserActivityTimestamp = storedTimestamp
    }
}
