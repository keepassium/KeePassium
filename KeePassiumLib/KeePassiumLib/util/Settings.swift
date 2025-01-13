//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public protocol SettingsObserver: AnyObject {
    func settingsDidChange(key: Settings.Keys)
}

public class SettingsNotifications {
    public weak var observer: SettingsObserver?

    public init(observer: SettingsObserver? = nil) {
        self.observer = observer
    }

    public func startObserving() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange(_:)),
            name: Settings.Notifications.settingsChanged,
            object: nil)
    }

    public func stopObserving() {
        NotificationCenter.default.removeObserver(
            self,
            name: Settings.Notifications.settingsChanged,
            object: nil)
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyString = userInfo[Settings.Notifications.userInfoKey] as? String
        else { return }

        guard let key = Settings.Keys(rawValue: keyString) else {
            assertionFailure("Unknown Settings.Keys value: \(keyString)")
            return
        }
        observer?.settingsDidChange(key: key)
    }
}

public class Settings {
    public static let latestVersion = 5
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
        case databaseLockTimeout
        case lockDatabasesOnTimeout
        case lockDatabasesOnReboot
        case passcodeKeyboardType

        case clipboardTimeout
        case universalClipboardEnabled

        case shakeGestureAction
        case confirmShakeGestureAction

        case databaseIconSet
        case groupSortOrder
        case entryListDetail
        case entryViewerPage
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

        case hapticFeedbackEnabled

        case passwordGeneratorConfig

        case networkAccessAllowed

        case hideAppLockSetupReminder
        case textScale
        case entryTextFontDescriptor

        case keyFileEntryProtected
    }

    fileprivate enum Notifications {
        static let settingsChanged = Notification.Name("com.keepassium.SettingsChanged")
        static let userInfoKey = "changedKey" 
    }


    public enum AppLockTimeout: Int {
        public enum TriggerMode {
            case userIdle
            case appMinimized
        }

        public static let allValues = [
            immediately,
            after3seconds, after15seconds, after30seconds,
            after1minute, after2minutes, after5minutes]

        case never = -1 
        case immediately = 0
        case almostImmediately = 2 /* workaround for some bugs with `immediately` */
        case after3seconds = 3
        case after15seconds = 15
        case after30seconds = 30
        case after1minute = 60
        case after2minutes = 120
        case after5minutes = 300

        public var seconds: Int {
            return self.rawValue
        }

        static func nearest(forSeconds seconds: Int) -> AppLockTimeout {
            let result = Self.allValues.min(by: { item1, item2 in
                return abs(item1.seconds - seconds) < abs(item2.seconds - seconds)
            })
            return result! 
        }

        public var triggerMode: TriggerMode {
            switch self {
            case .never,
                 .immediately,
                 .almostImmediately,
                 .after3seconds:
                return .appMinimized
            default:
                return .userIdle
            }
        }

        public var fullTitle: String {
            switch self {
            case .never:
                return LString.appProtectionTimeoutNeverFull
            case .immediately:
                return LString.appProtectionTimeoutImmediatelyFull
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var shortTitle: String {
            switch self {
            case .never:
                return LString.appProtectionTimeoutNeverShort
            case .immediately:
                return LString.appProtectionTimeoutImmediatelyShort
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .brief
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var description: String? {
            switch triggerMode {
            case .appMinimized:
                return LString.appProtectionTimeoutAfterLeavingApp
            case .userIdle:
                return LString.appProtectionTimeoutAfterLastInteraction
            }
        }
    }

    public enum DatabaseLockTimeout: Int, Comparable {
        public static let allValues = [
            immediately, /*after5seconds, after15seconds, */after30seconds,
            after1minute, after2minutes, after5minutes, after10minutes,
            after30minutes, after1hour, after2hours, after4hours, after8hours,
            after24hours, after48hours, after7days, never]
        case never = -1
        case immediately = 0
        case after5seconds = 5
        case after15seconds = 15
        case after30seconds = 30
        case after1minute = 60
        case after2minutes = 120
        case after5minutes = 300
        case after10minutes = 600
        case after30minutes = 1800
        case after1hour = 3600
        case after2hours = 7200
        case after4hours = 14400
        case after8hours = 28800
        case after24hours = 86400
        case after48hours = 172800
        case after7days = 604800

        public var seconds: Int {
            return self.rawValue
        }

        static func nearest(forSeconds seconds: Int) -> DatabaseLockTimeout {
            let result = Self.allValues.min(by: { item1, item2 in
                return abs(item1.seconds - seconds) < abs(item2.seconds - seconds)
            })
            return result! 
        }

        public static func < (a: DatabaseLockTimeout, b: DatabaseLockTimeout) -> Bool {
            return a.seconds < b.seconds
        }

        public var fullTitle: String {
            switch self {
            case .never:
                return LString.databaseLockTimeoutNeverFull
            case .immediately:
                return LString.databaseLockTimeoutImmediatelyFull
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.weekOfMonth, .day, .hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var shortTitle: String {
            switch self {
            case .never:
                return LString.databaseLockTimeoutNeverShort
            case .immediately:
                return LString.databaseLockTimeoutImmediatelyShort
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.weekOfMonth, .day, .hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .brief
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var description: String? {
            switch self {
            case .immediately:
                return LString.databaseLockTimeoutWhenLeavingApp
            default:
                return nil
            }
        }
    }

    public enum ClipboardTimeout: Int, CaseIterable {
        public static let visibleValues = [
            after10seconds, after20seconds, after30seconds, after1minute, after2minutes,
            after3minutes, after5minutes, after10minutes, after20minutes, never]
        case never = -1
        case immediately = 0
        case after10seconds = 10
        case after20seconds = 20
        case after30seconds = 30
        case after1minute = 60
        case after2minutes = 120
        case after3minutes = 180
        case after5minutes = 300
        case after10minutes = 600
        case after20minutes = 1200

        public var seconds: Int {
            return self.rawValue
        }

        static func nearest(forSeconds seconds: Int) -> ClipboardTimeout {
            let result = Self.allCases.min(by: { item1, item2 in
                return abs(item1.seconds - seconds) < abs(item2.seconds - seconds)
            })
            return result! 
        }

        public var fullTitle: String {
            switch self {
            case .never:
                return NSLocalizedString(
                    "[Settings/ClipboardTimeout/fullTitle] Never",
                    bundle: Bundle.framework,
                    value: "Never",
                    comment: "An option in Settings. Will be shown as 'Clipboard Timeout: Never'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .full
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
        public var shortTitle: String {
            switch self {
            case .never:
                return NSLocalizedString(
                    "[Settings/ClipboardTimeout/shortTitle] Never",
                    bundle: Bundle.framework,
                    value: "Never",
                    comment: "An option in Settings. Will be shown as 'Clipboard Timeout: Never'")
            default:
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.collapsesLargestUnit = true
                formatter.maximumUnitCount = 2
                formatter.unitsStyle = .brief
                guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                    assertionFailure()
                    return "?"
                }
                return result
            }
        }
    }

    public enum BackupKeepingDuration: Int {
        public static let allValues: [BackupKeepingDuration] = [
            .forever, _1year, _6months, _2months, _4weeks, _1week, _1day, _4hours, _1hour
        ]
        case _1hour = 3600
        case _4hours = 14400
        case _1day = 86400
        case _1week = 604_800
        case _4weeks = 2_419_200
        case _2months = 5_270_400
        case _6months = 15_552_000
        case _1year = 31_536_000
        case forever

        public var seconds: TimeInterval {
            switch self {
            case .forever:
                return TimeInterval.infinity
            default:
                return TimeInterval(self.rawValue)
            }
        }

        static func nearest(forSeconds seconds: Int) -> BackupKeepingDuration {
            let result = Self.allValues.min(by: { item1, item2 in
                return abs(item1.rawValue - seconds) < abs(item2.rawValue - seconds)
            })
            return result! 
        }

        public var shortTitle: String {
            switch self {
            case .forever:
                return NSLocalizedString(
                    "[Settings/BackupKeepingDuration/shortTitle] Forever",
                    bundle: Bundle.framework,
                    value: "Forever",
                    comment: "An option in Settings. Please keep it short. Will be shown as 'Keep Backup Files: Forever'")
                    // swiftlint:disable:previous line_length
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

        public var fullTitle: String {
            return shortTitle
        }
    }

    public enum EntryListDetail: Int {
        public static let allValues = [`none`, userName, password, url, notes, tags, lastModifiedDate]

        case none
        case userName
        case password
        case url
        case notes
        case lastModifiedDate
        case tags

        public var title: String {
            // swiftlint:disable line_length
            switch self {
            case .none:
                return NSLocalizedString(
                    "[Settings/EntryListDetail/longTitle] None",
                    bundle: Bundle.framework,
                    value: "None",
                    comment: "An option in Group Viewer settings. Will be shown as 'Entry Subtitle: None', meanining that no entry details will be shown in any lists.")
            case .userName:
                return LString.fieldUserName
            case .password:
                return LString.fieldPassword
            case .url:
                return LString.fieldURL
            case .notes:
                return LString.fieldNotes
            case .lastModifiedDate:
                return LString.itemLastModificationDate
            case .tags:
                return LString.fieldTags
            }
            // swiftlint:enable line_length
        }
    }

    public enum GroupSortOrder: Int {
        public static let allValues = [
            noSorting,
            nameAsc, nameDesc,
            creationTimeDesc, creationTimeAsc,
            modificationTimeDesc, modificationTimeAsc]

        case noSorting
        case nameAsc
        case nameDesc
        case creationTimeAsc
        case creationTimeDesc
        case modificationTimeAsc
        case modificationTimeDesc

        public var isAscending: Bool? {
            switch self {
            case .noSorting:
                return nil
            case .nameAsc, .creationTimeAsc, .modificationTimeAsc:
                return true
            case .nameDesc, .creationTimeDesc, .modificationTimeDesc:
                return false
            }
        }

        public var title: String {
            switch self {
            case .noSorting:
                return LString.titleSortOrderCustom
            case .nameAsc, .nameDesc:
                return LString.fieldTitle
            case .creationTimeAsc, .creationTimeDesc:
                return LString.itemCreationDate
            case .modificationTimeAsc, .modificationTimeDesc:
                return LString.itemLastModificationDate
            }
        }
        public func compare(_ group1: Group, _ group2: Group) -> Bool {
            switch self {
            case .noSorting:
                return false
            case .nameAsc:
                return group1.name.localizedStandardCompare(group2.name) == .orderedAscending
            case .nameDesc:
                return group1.name.localizedStandardCompare(group2.name) == .orderedDescending
            case .creationTimeAsc:
                return group1.creationTime.compare(group2.creationTime) == .orderedAscending
            case .creationTimeDesc:
                return group1.creationTime.compare(group2.creationTime) == .orderedDescending
            case .modificationTimeAsc:
                return group1.lastModificationTime.compare(group2.lastModificationTime) == .orderedAscending
            case .modificationTimeDesc:
                return group1.lastModificationTime.compare(group2.lastModificationTime) == .orderedDescending
            }
        }
        public func compare(_ entry1: Entry, _ entry2: Entry) -> Bool {
            switch self {
            case .noSorting:
                return false
            case .nameAsc:
                return entry1.resolvedTitle.localizedStandardCompare(entry2.resolvedTitle) == .orderedAscending
            case .nameDesc:
                return entry1.resolvedTitle.localizedStandardCompare(entry2.resolvedTitle) == .orderedDescending
            case .creationTimeAsc:
                return entry1.creationTime.compare(entry2.creationTime) == .orderedAscending
            case .creationTimeDesc:
                return entry1.creationTime.compare(entry2.creationTime) == .orderedDescending
            case .modificationTimeAsc:
                return entry1.lastModificationTime.compare(entry2.lastModificationTime) == .orderedAscending
            case .modificationTimeDesc:
                return entry1.lastModificationTime.compare(entry2.lastModificationTime) == .orderedDescending
            }
        }
    }

    public enum FilesSortOrder: Int {
        public static let allValues = [
            noSorting,
            nameAsc, nameDesc,
            creationTimeDesc, creationTimeAsc,
            modificationTimeDesc, modificationTimeAsc]

        case noSorting
        case nameAsc
        case nameDesc
        case creationTimeAsc
        case creationTimeDesc
        case modificationTimeAsc
        case modificationTimeDesc

        public var isAscending: Bool? {
            switch self {
            case .noSorting:
                return nil
            case .nameAsc, .creationTimeAsc, .modificationTimeAsc:
                return true
            case .nameDesc, .creationTimeDesc, .modificationTimeDesc:
                return false
            }
        }

        public var title: String {
            switch self {
            case .noSorting:
                return LString.titleSortByNone
            case .nameAsc, .nameDesc:
                return LString.titleSortByFileName
            case .creationTimeAsc, .creationTimeDesc:
                return LString.itemCreationDate
            case .modificationTimeAsc, .modificationTimeDesc:
                return LString.itemLastModificationDate
            }
        }

        public func compare(_ lhs: URLReference, _ rhs: URLReference) -> Bool {
            switch self {
            case .noSorting:
                return false
            case .nameAsc:
                return compareFileNames(lhs, rhs, criteria: .orderedAscending)
            case .nameDesc:
                return compareFileNames(lhs, rhs, criteria: .orderedDescending)
            case .creationTimeAsc:
                return compareCreationTimes(lhs, rhs, criteria: .orderedAscending)
            case .creationTimeDesc:
                return compareCreationTimes(lhs, rhs, criteria: .orderedDescending)
            case .modificationTimeAsc:
                return compareModificationTimes(lhs, rhs, criteria: .orderedAscending)
            case .modificationTimeDesc:
                return compareModificationTimes(lhs, rhs, criteria: .orderedDescending)
            }
        }

        private func compareFileNames(_ lhs: URLReference, _ rhs: URLReference, criteria: ComparisonResult) -> Bool {
            let lhsInfo = lhs.getCachedInfoSync(canFetch: false)
            guard let lhsName = lhsInfo?.fileName ?? lhs.url?.lastPathComponent else {
                return false
            }
            let rhsInfo = rhs.getCachedInfoSync(canFetch: false)
            guard let rhsName = rhsInfo?.fileName ?? rhs.url?.lastPathComponent else {
                return true
            }
            return lhsName.localizedCaseInsensitiveCompare(rhsName) == criteria
        }

        private func compareCreationTimes(
            _ lhs: URLReference,
            _ rhs: URLReference,
            criteria: ComparisonResult
        ) -> Bool {
            guard let lhsInfo = lhs.getCachedInfoSync(canFetch: false) else { return false }
            guard let rhsInfo = rhs.getCachedInfoSync(canFetch: false) else { return true }
            guard let lhsDate = lhsInfo.creationDate else { return true }
            guard let rhsDate = rhsInfo.creationDate else { return false }
            return lhsDate.compare(rhsDate) == criteria
        }

        private func compareModificationTimes(
            _ lhs: URLReference,
            _ rhs: URLReference,
            criteria: ComparisonResult
        ) -> Bool {
            guard let lhsInfo = lhs.getCachedInfoSync(canFetch: false) else { return false }
            guard let rhsInfo = rhs.getCachedInfoSync(canFetch: false) else { return true }
            guard let lhsDate = lhsInfo.modificationDate else { return true }
            guard let rhsDate = rhsInfo.modificationDate else { return false }
            return lhsDate.compare(rhsDate) == criteria
        }
    }

    public enum PasscodeKeyboardType: Int {
        public static let allValues = [numeric, alphanumeric]
        case numeric
        case alphanumeric
        public var title: String {
            switch self {
            case .numeric:
                return NSLocalizedString(
                    "[AppLock/Passcode/KeyboardType/title] Numeric",
                    bundle: Bundle.framework,
                    value: "Numeric",
                    comment: "Type of keyboard to show for App Lock passcode: digits only (PIN code).")
            case .alphanumeric:
                return NSLocalizedString(
                    "[AppLock/Passcode/KeyboardType/title] Alphanumeric",
                    bundle: Bundle.framework,
                    value: "Alphanumeric",
                    comment: "Type of keyboard to show for App Lock passcode: letters and digits.")
            }
        }
    }

    public enum ShakeGestureAction: Int {
        case nothing
        case lockApp
        case lockAllDatabases
        case quitApp

        public static func getVisibleValues() -> [Self] {
            var result: [Self] = [.nothing]
            if ManagedAppConfig.shared.isAppProtectionAllowed {
                result.append(.lockApp)
            }
            result.append(.lockAllDatabases)
            result.append(.quitApp)
            return result
        }

        public var shortTitle: String {
            switch self {
            case .nothing:
                return NSLocalizedString(
                    "[Settings/ShakeGestureAction/Nothing/shortTitle]",
                    bundle: Bundle.framework,
                    value: "Do Nothing",
                    comment: "An option in Settings. Will be shown as 'When Shaken: Do Nothing'")
            case .lockApp:
                return NSLocalizedString(
                    "[Settings/ShakeGestureAction/LockApp/shortTitle]",
                    bundle: Bundle.framework,
                    value: "Lock App",
                    comment: "An option in Settings. Will be shown as 'When Shaken: Lock App'")
            case .lockAllDatabases:
                return NSLocalizedString(
                    "[Settings/ShakeGestureAction/LockDatabases/shortTitle]",
                    bundle: Bundle.framework,
                    value: "Lock All Databases",
                    comment: "An option in Settings. Will be shown as 'When Shaken: Lock All Databases'")
            case .quitApp:
                return NSLocalizedString(
                    "[Settings/ShakeGestureAction/QuitApp/shortTitle]",
                    bundle: Bundle.framework,
                    value: "Quit App",
                    comment: "An option in Settings. Will be shown as 'When Shaken: Quit App'")

            }
        }

        public var disabledSubtitle: String? {
            switch self {
            case .lockApp:
                return NSLocalizedString(
                    "[Settings/ShakeGestureAction/LockApp/disabledTitle]",
                    bundle: Bundle.framework,
                    value: "Activate app protection first",
                    comment: "Call to action (explains why a setting is disabled)")
            default:
                return nil
            }
        }
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
                postChangeNotification(changedKey: Keys.settingsVersion)
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


    public var filesSortOrder: FilesSortOrder {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.filesSortOrder.rawValue) as? Int,
               let sortOrder = FilesSortOrder(rawValue: rawValue)
            {
                return sortOrder
            }
            return FilesSortOrder.noSorting
        }
        set {
            let oldValue = filesSortOrder
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.filesSortOrder.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.filesSortOrder)
            }
        }
    }

    public var isBackupFilesVisible: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.showBackupFiles) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.backupFilesVisible.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isBackupFilesVisible,
                newValue: newValue,
                key: .backupFilesVisible)
        }
    }


    public var startupDatabase: URLReference? {
        get {
            try? Keychain.shared.getFileReference(of: .startDatabase)
        }
        set {
            let oldValue = startupDatabase
            try? Keychain.shared.setFileReference(newValue, for: .startDatabase)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.startupDatabase)
            }
        }
    }

    public var isAutoUnlockStartupDatabase: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.autoUnlockLastDatabase) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoUnlockStartupDatabase.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isAutoUnlockStartupDatabase,
                newValue: newValue,
                key: .autoUnlockStartupDatabase)
        }
    }

    public var isRememberDatabaseKey: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.rememberDatabaseKey) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.rememberDatabaseKey.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isRememberDatabaseKey,
                newValue: newValue,
                key: .rememberDatabaseKey)
        }
    }

    public var isRememberDatabaseFinalKey: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.rememberDatabaseFinalKey) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.rememberDatabaseFinalKey.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isRememberDatabaseFinalKey,
                newValue: newValue,
                key: .rememberDatabaseFinalKey)
        }
    }

    public var isKeepKeyFileAssociations: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.keepKeyFileAssociations) {
                return managedValue
            }
            if contains(key: Keys.keepKeyFileAssociations) {
                return UserDefaults.appGroupShared.bool(forKey: Keys.keepKeyFileAssociations.rawValue)
            } else {
                return true
            }
        }
        set {
            let oldValue = isKeepKeyFileAssociations
            UserDefaults.appGroupShared.set(newValue, forKey: Keys.keepKeyFileAssociations.rawValue)
            if !newValue {
                DatabaseSettingsManager.shared.forgetAllKeyFiles()
            }
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.keepKeyFileAssociations)
            }
        }
    }

    public var isKeepHardwareKeyAssociations: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.keepHardwareKeyAssociations) {
                return managedValue
            }
            if contains(key: Keys.keepHardwareKeyAssociations) {
                return UserDefaults.appGroupShared.bool(forKey: Keys.keepHardwareKeyAssociations.rawValue)
            } else {
                return true
            }
        }
        set {
            let oldValue = isKeepHardwareKeyAssociations
            UserDefaults.appGroupShared.set(newValue, forKey: Keys.keepHardwareKeyAssociations.rawValue)
            if !newValue {
                DatabaseSettingsManager.shared.forgetAllHardwareKeys()
            }
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.keepHardwareKeyAssociations)
            }
        }
    }


    public var isAppLockEnabled: Bool {
      let hasPasscode = try? Keychain.shared.isAppPasscodeSet() 
      return hasPasscode ?? false
    }

    internal func notifyAppLockEnabledChanged() {
        postChangeNotification(changedKey: .appLockEnabled)
    }

    public var isBiometricAppLockEnabled: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.biometricAppLockEnabled.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isBiometricAppLockEnabled,
                newValue: newValue,
                key: .biometricAppLockEnabled)
        }
    }

    public var isLockAllDatabasesOnFailedPasscode: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.lockAllDatabasesOnFailedPasscode) {
                return managedValue
            }
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.lockAllDatabasesOnFailedPasscode) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.lockAllDatabasesOnFailedPasscode.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isLockAllDatabasesOnFailedPasscode,
                newValue: newValue,
                key: .lockAllDatabasesOnFailedPasscode)
        }
    }

    private var cachedUserActivityTimestamp: Date?
    private let timestampCacheValidityInterval = 1.0

    public var recentUserActivityTimestamp: Date {
        get {
            if let cachedUserActivityTimestamp,
               abs(cachedUserActivityTimestamp.timeIntervalSinceNow) < timestampCacheValidityInterval
            {
                return cachedUserActivityTimestamp
            }

            do {
                let storedTimestamp = try Keychain.shared.getUserActivityTimestamp()
                cachedUserActivityTimestamp = storedTimestamp
                return storedTimestamp ?? Date.distantPast
            } catch {
                Diag.error("Failed to get user activity timestamp [message: \(error.localizedDescription)]")
                return Date.distantPast
            }
        }
        set {
            if let cachedUserActivityTimestamp,
               abs(cachedUserActivityTimestamp.timeIntervalSinceNow) < timestampCacheValidityInterval
            {
                return
            }
            do {
                try Keychain.shared.setUserActivityTimestamp(newValue)
                cachedUserActivityTimestamp = newValue
                postChangeNotification(changedKey: Keys.recentUserActivityTimestamp)
            } catch {
                Diag.error("Failed to set user activity timestamp [message: \(error.localizedDescription)]")
            }
        }
    }

    private func maybeFixAutoFillBiometricIDLoop(_ timeout: AppLockTimeout) -> AppLockTimeout {
        if timeout == .immediately && AppGroup.isAppExtension {
            return .almostImmediately
        } else {
            return timeout
        }
    }

    public var appLockTimeout: AppLockTimeout {
        get {
            if let managedValue = ManagedAppConfig.shared.getIntIfLicensed(.appLockTimeout) {
                let nearestTimeout = AppLockTimeout.nearest(forSeconds: managedValue)
                return maybeFixAutoFillBiometricIDLoop(nearestTimeout)
            }

            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.appLockTimeout.rawValue) as? Int,
               let timeout = AppLockTimeout(rawValue: rawValue)
            {
                return maybeFixAutoFillBiometricIDLoop(timeout)
            }
            return maybeFixAutoFillBiometricIDLoop(AppLockTimeout.immediately)
        }
        set {
            let oldValue = appLockTimeout
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.appLockTimeout.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.appLockTimeout)
            }
        }
    }

    public var isLockAppOnLaunch: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.lockAppOnLaunch) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.lockAppOnLaunch.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isLockAppOnLaunch,
                newValue: newValue,
                key: .lockAppOnLaunch)
        }
    }

    public var databaseLockTimeout: DatabaseLockTimeout {
        get {
            if let managedValue = ManagedAppConfig.shared.getIntIfLicensed(.databaseLockTimeout) {
                let nearestTimeout = DatabaseLockTimeout.nearest(forSeconds: managedValue)
                return nearestTimeout
            }

            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.databaseLockTimeout.rawValue) as? Int,
               let timeout = DatabaseLockTimeout(rawValue: rawValue)
            {
                return timeout
            }
            return DatabaseLockTimeout.never
        }
        set {
            let oldValue = databaseLockTimeout
            UserDefaults.appGroupShared.set(
                newValue.rawValue,
                forKey: Keys.databaseLockTimeout.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.databaseLockTimeout)
            }
        }
    }

    public var isLockDatabasesOnTimeout: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.lockDatabasesOnTimeout) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.lockDatabasesOnTimeout.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isLockDatabasesOnTimeout,
                newValue: newValue,
                key: .lockDatabasesOnTimeout)
        }
    }

    public var isLockDatabasesOnReboot: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.lockDatabasesOnReboot) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.lockDatabasesOnReboot.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isLockDatabasesOnReboot,
                newValue: newValue,
                key: .lockDatabasesOnReboot)
        }
    }

    public var clipboardTimeout: ClipboardTimeout {
        get {
            if let managedValue = ManagedAppConfig.shared.getIntIfLicensed(.clipboardTimeout) {
                let nearestTimeout = ClipboardTimeout.nearest(forSeconds: managedValue)
                return nearestTimeout
            }

            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.clipboardTimeout.rawValue) as? Int,
               let timeout = ClipboardTimeout(rawValue: rawValue)
            {
                return timeout
            }
            return ClipboardTimeout.after1minute
        }
        set {
            let oldValue = clipboardTimeout
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.clipboardTimeout.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.clipboardTimeout)
            }
        }
    }

    public var isUniversalClipboardEnabled: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.useUniversalClipboard) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.universalClipboardEnabled.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isUniversalClipboardEnabled,
                newValue: newValue,
                key: .universalClipboardEnabled)
        }
    }

    public var shakeGestureAction: ShakeGestureAction {
        get {
            if let rawValue = UserDefaults.appGroupShared
                   .object(forKey: Keys.shakeGestureAction.rawValue) as? Int,
               let action = ShakeGestureAction(rawValue: rawValue)
            {
                if action == .lockApp && !ManagedAppConfig.shared.isAppProtectionAllowed {
                    return .nothing
                }
                return action
            }
            return ShakeGestureAction.nothing
        }
        set {
            let oldValue = shakeGestureAction
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.shakeGestureAction.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.shakeGestureAction)
            }
        }
    }

    public var isConfirmShakeGestureAction: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.confirmShakeGestureAction.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isConfirmShakeGestureAction,
                newValue: newValue,
                key: .confirmShakeGestureAction)
        }
    }

    public var databaseIconSet: DatabaseIconSet {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.databaseIconSet.rawValue) as? Int,
               let iconSet = DatabaseIconSet(rawValue: rawValue)
            {
                return iconSet
            }
            return DatabaseIconSet.keepassium
        }
        set {
            updateAndNotify(oldValue: databaseIconSet.rawValue, newValue: newValue.rawValue, key: .databaseIconSet)
        }
    }

    public var groupSortOrder: GroupSortOrder {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.groupSortOrder.rawValue) as? Int,
               let sortOrder = GroupSortOrder(rawValue: rawValue)
            {
                return sortOrder
            }
            return GroupSortOrder.noSorting
        }
        set {
            let oldValue = groupSortOrder
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.groupSortOrder.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.groupSortOrder)
            }
        }
    }

    public var entryListDetail: EntryListDetail {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.entryListDetail.rawValue) as? Int,
               let detail = EntryListDetail(rawValue: rawValue)
            {
                return detail
            }
            return EntryListDetail.userName
        }
        set {
            let oldValue = entryListDetail
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.entryListDetail.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.entryListDetail)
            }
        }
    }

    public var entryViewerPage: Int {
        get {
            let storedPage = UserDefaults.appGroupShared
                .object(forKey: Keys.entryViewerPage.rawValue) as? Int
            return storedPage ?? 0
        }
        set {
            updateAndNotify(
                oldValue: entryViewerPage,
                newValue: newValue,
                key: Keys.entryViewerPage)
        }
    }

    public var isHideProtectedFields: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.hideProtectedFields) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.hideProtectedFields.rawValue) as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isHideProtectedFields,
                newValue: newValue,
                key: Keys.hideProtectedFields)
        }
    }

    public var isCollapseNotesField: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.collapseNotesField.rawValue) as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isCollapseNotesField,
                newValue: newValue,
                key: Keys.collapseNotesField)
        }
    }


    public var isStartWithSearch: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.startWithSearch.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isStartWithSearch,
                newValue: newValue,
                key: .startWithSearch)
        }
    }

    public var isSearchFieldNames: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.searchFieldNames.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isSearchFieldNames,
                newValue: newValue,
                key: .searchFieldNames)
        }
    }

    public var isSearchProtectedValues: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.searchProtectedValues.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isSearchProtectedValues,
                newValue: newValue,
                key: .searchProtectedValues)
        }
    }

    public var isSearchPasswords: Bool {
        get {
            guard isSearchProtectedValues else {
                return false
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.searchPasswords.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isSearchPasswords,
                newValue: newValue,
                key: .searchPasswords)
        }
    }


    public var isBackupDatabaseOnLoad: Bool {
      return isBackupDatabaseOnSave
    }

    public var isBackupDatabaseOnSave: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.backupDatabaseOnSave) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.backupDatabaseOnSave.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isBackupDatabaseOnSave,
                newValue: newValue,
                key: .backupDatabaseOnSave)
        }
    }

    public var backupKeepingDuration: BackupKeepingDuration {
        get {
            if let managedValue = ManagedAppConfig.shared.getIntIfLicensed(.backupKeepingDuration) {
                let nearestDuration = BackupKeepingDuration.nearest(forSeconds: managedValue)
                return nearestDuration
            }

            if let stored = UserDefaults.appGroupShared
                    .object(forKey: Keys.backupKeepingDuration.rawValue) as? Int,
               let timeout = BackupKeepingDuration(rawValue: stored)
            {
                return timeout
            }
            return BackupKeepingDuration._2months
        }
        set {
            let oldValue = backupKeepingDuration
            UserDefaults.appGroupShared.set(
                newValue.rawValue,
                forKey: Keys.backupKeepingDuration.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.backupKeepingDuration)
            }
        }
    }

    public var isExcludeBackupFilesFromSystemBackup: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.excludeBackupFilesFromSystemBackup) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.excludeBackupFilesFromSystemBackup.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isExcludeBackupFilesFromSystemBackup,
                newValue: newValue,
                key: .excludeBackupFilesFromSystemBackup)
        }
    }


    public var isAutoFillFinishedOK: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillFinishedOK.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isAutoFillFinishedOK,
                newValue: newValue,
                key: Keys.autoFillFinishedOK)

            UserDefaults.appGroupShared.synchronize()
        }
    }

    public var isCopyTOTPOnAutoFill: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.copyTOTPOnAutoFill.rawValue)
                as? Bool

            if #available(iOS 18, *) {
                return stored ?? false
            } else {
                return stored ?? true
            }
        }
        set {
            updateAndNotify(
                oldValue: isCopyTOTPOnAutoFill,
                newValue: newValue,
                key: .copyTOTPOnAutoFill)
        }
    }

    public var autoFillPerfectMatch: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillPerfectMatch.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: autoFillPerfectMatch,
                newValue: newValue,
                key: .autoFillPerfectMatch)
        }
    }

    public var acceptAutoFillInput: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.acceptAutoFillInput.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: acceptAutoFillInput,
                newValue: newValue,
                key: .acceptAutoFillInput)
        }
    }

    public var isQuickTypeEnabled: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.enableQuickTypeAutoFill) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.quickTypeEnabled.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isQuickTypeEnabled,
                newValue: newValue,
                key: .quickTypeEnabled)
        }
    }


    public var isHapticFeedbackEnabled: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.hapticFeedbackEnabled.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isHapticFeedbackEnabled,
                newValue: newValue,
                key: .hapticFeedbackEnabled)
        }
    }

    public var isHideAppLockSetupReminder: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.isHideAppProtectionReminder {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.hideAppLockSetupReminder.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isHideAppLockSetupReminder,
                newValue: newValue,
                key: .hideAppLockSetupReminder)
        }
    }

    public let textScaleAllowedRange: ClosedRange<CGFloat> = 0.5...2.0

    public var textScale: CGFloat {
        get {
            let storedValueOrNil = UserDefaults.appGroupShared
                .object(forKey: Keys.textScale.rawValue)
                as? CGFloat
            if let value = storedValueOrNil {
                return value.clamped(to: textScaleAllowedRange)
            } else {
                return 1.0
            }
        }
        set {
            updateAndNotify(
                oldValue: textScale,
                newValue: newValue.clamped(to: textScaleAllowedRange),
                key: .textScale)
        }
    }

    public var entryTextFontDescriptor: UIFontDescriptor? {
        get {
            guard let data = UserDefaults.appGroupShared.data(forKey: .entryTextFontDescriptor) else {
                return nil
            }
            return UIFontDescriptor.deserialize(data)
        }
        set {
            let newData = newValue?.serialize()
            let oldData = UserDefaults.appGroupShared.data(forKey: .entryTextFontDescriptor)
            if newData != oldData {
                UserDefaults.appGroupShared.set(newData, forKey: .entryTextFontDescriptor)
                postChangeNotification(changedKey: .entryTextFontDescriptor)
            }
        }
    }


    public var passwordGeneratorConfig: PasswordGeneratorParams {
        get {
            let storedData = UserDefaults.appGroupShared
                .object(forKey: Keys.passwordGeneratorConfig.rawValue)
                as? Data
            let storedConfig = PasswordGeneratorParams.deserialize(from: storedData)
            return storedConfig ?? PasswordGeneratorParams()
        }
        set {
            let hasChanged = newValue != passwordGeneratorConfig
            UserDefaults.appGroupShared.set(
                newValue.serialize(),
                forKey: Keys.passwordGeneratorConfig.rawValue
            )
            if hasChanged {
                postChangeNotification(changedKey: Keys.passwordGeneratorConfig)
            }
        }

    }

    public var passcodeKeyboardType: PasscodeKeyboardType {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .object(forKey: Keys.passcodeKeyboardType.rawValue) as? Int,
               let keyboardType = PasscodeKeyboardType(rawValue: rawValue)
            {
                return keyboardType
            }
            return PasscodeKeyboardType.numeric
        }
        set {
            let oldValue = passcodeKeyboardType
            UserDefaults.appGroupShared.set(newValue.rawValue, forKey: Keys.passcodeKeyboardType.rawValue)
            if newValue != oldValue {
                postChangeNotification(changedKey: Keys.passcodeKeyboardType)
            }
        }
    }


    public var isNetworkAccessAllowed: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.allowNetworkAccess) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.networkAccessAllowed.rawValue) as? Bool
            return stored ?? false
        }
        set {
            updateAndNotify(
                oldValue: isNetworkAccessAllowed,
                newValue: newValue,
                key: .networkAccessAllowed
            )
        }
    }

    public var isKeyFileInputProtected: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.protectKeyFileInput) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.keyFileEntryProtected.rawValue) as? Bool
            return stored ?? true
        }
        set {
            updateAndNotify(
                oldValue: isKeyFileInputProtected,
                newValue: newValue,
                key: .keyFileEntryProtected
            )
        }
    }

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


    private func updateAndNotify(oldValue: Bool, newValue: Bool, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            postChangeNotification(changedKey: key)
        }
    }

    private func updateAndNotify<T: SignedNumeric>(oldValue: T, newValue: T, key: Keys) {
        UserDefaults.appGroupShared.set(newValue, forKey: key.rawValue)
        if newValue != oldValue {
            postChangeNotification(changedKey: key)
        }
    }

    private func contains(key: Keys) -> Bool {
        return UserDefaults.appGroupShared.object(forKey: key) != nil
    }

    fileprivate func postChangeNotification(changedKey: Settings.Keys) {
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

extension Settings.Keys {
    internal var managedKeyMapping: ManagedAppConfig.Key? {
        switch self {
        case .backupFilesVisible:
            return .showBackupFiles
        case .autoUnlockStartupDatabase:
            return .autoUnlockLastDatabase
        case .rememberDatabaseKey:
            return .rememberDatabaseKey
        case .rememberDatabaseFinalKey:
            return .rememberDatabaseFinalKey
        case .keepKeyFileAssociations:
            return .keepKeyFileAssociations
        case .keepHardwareKeyAssociations:
            return .keepHardwareKeyAssociations
        case .lockAllDatabasesOnFailedPasscode:
            return .lockAllDatabasesOnFailedPasscode
        case .appLockTimeout:
            return .appLockTimeout
        case .lockAppOnLaunch:
            return .lockAppOnLaunch
        case .databaseLockTimeout:
            return .databaseLockTimeout
        case .lockDatabasesOnTimeout:
            return .lockDatabasesOnTimeout
        case .lockDatabasesOnReboot:
            return .lockDatabasesOnReboot
        case .clipboardTimeout:
            return .clipboardTimeout
        case .universalClipboardEnabled:
            return .useUniversalClipboard
        case .hideProtectedFields:
            return .hideProtectedFields
        case .backupDatabaseOnSave:
            return .backupDatabaseOnSave
        case .backupKeepingDuration:
            return .backupKeepingDuration
        case .excludeBackupFilesFromSystemBackup:
            return .excludeBackupFilesFromSystemBackup
        case .quickTypeEnabled:
            return .enableQuickTypeAutoFill
        case .networkAccessAllowed:
            return .allowNetworkAccess
        case .hideAppLockSetupReminder:
            return .hideAppLockSetupReminder
        default:
            return nil
        }
    }
}

extension Settings {
    public func isManaged(key: Keys) -> Bool {
        guard let managedKey = key.managedKeyMapping else {
            return false
        }
        return ManagedAppConfig.shared.isManaged(key: managedKey)
    }
}

fileprivate extension UserDefaults {
    func set(_ value: Any?, forKey key: Settings.Keys) {
        set(value, forKey: key.rawValue)
    }
    func object(forKey key: Settings.Keys) -> Any? {
        return object(forKey: key.rawValue)
    }
    func data(forKey key: Settings.Keys) -> Data? {
        return data(forKey: key.rawValue)
    }
}
