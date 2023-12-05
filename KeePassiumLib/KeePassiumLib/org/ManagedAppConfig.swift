//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public final class ManagedAppConfig: NSObject {
    public static let shared = ManagedAppConfig()

    public enum Key: String, CaseIterable {
        static let managedConfig = "com.apple.configuration.managed"

        case license
        case autoUnlockLastDatabase 
        case rememberDatabaseKey 
        case rememberDatabaseFinalKey 
        case keepKeyFileAssociations 
        case keepHardwareKeyAssociations 
        case lockAllDatabasesOnFailedPasscode 
        case appLockTimeout 
        case lockAppOnLaunch 
        case databaseLockTimeout 
        case lockDatabasesOnTimeout 
        case clipboardTimeout 
        case useUniversalClipboard 
        case hideProtectedFields 
        case showBackupFiles 
        case backupDatabaseOnSave 
        case backupKeepingDuration 
        case excludeBackupFilesFromSystemBackup 
        case enableQuickTypeAutoFill 
        case allowNetworkAccess 
        case hideAppLockSetupReminder 
    }

    private var currentConfig: [String: Any]? {
        guard let rawObject = UserDefaults.standard.object(forKey: Key.managedConfig),
              let config = rawObject as? [String: Any]
        else {
            return nil
        }
        return config
    }
    private var intuneConfig: [String: Any]?
    private var previousLicenseValue: String?
    private var hasWarnedAboutMissingLicense = false

    override private init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: nil,
            using: userDefaultsDidChange)
    }

    public func isManaged() -> Bool {
        let isForced = UserDefaults.standard.objectIsForced(forKey: Key.managedConfig)
        return isForced
    }

    private func userDefaultsDidChange(_ notification: Notification) {
        let newLicense = license
        guard newLicense != previousLicenseValue else {
            return
        }
        previousLicenseValue = newLicense
        Diag.debug("License key changed, reloading")
        hasWarnedAboutMissingLicense = false
        LicenseManager.shared.checkBusinessLicense()
    }
}

extension ManagedAppConfig {
    public func setIntuneAppConfig(_ config: [[AnyHashable: Any]]?) {
        guard let config = config,
              let firstConfig = config.first 
        else {
            intuneConfig = nil
            Diag.info("No app config provided by Intune")
            return
        }

        var newIntuneConfig = intuneConfig ?? [:]
        Key.allCases.forEach { key in
            newIntuneConfig[key.rawValue] = firstConfig[key.rawValue] as? String
        }
        intuneConfig = newIntuneConfig
    }
}

extension ManagedAppConfig {
    internal var license: String? {
        let licenseValue = getString(.license)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if licenseValue == nil && BusinessModel.isIntuneEdition {
            Diag.warning("Business license is not configured")
        }
        return licenseValue
    }

    public func isManaged(key: Key) -> Bool {
        switch key {
        case .license:
            return getString(key) != nil
        case .autoUnlockLastDatabase,
             .rememberDatabaseKey,
             .rememberDatabaseFinalKey,
             .keepKeyFileAssociations,
             .keepHardwareKeyAssociations,
             .lockAllDatabasesOnFailedPasscode,
             .lockAppOnLaunch,
             .lockDatabasesOnTimeout,
             .useUniversalClipboard,
             .hideProtectedFields,
             .showBackupFiles,
             .backupDatabaseOnSave,
             .excludeBackupFilesFromSystemBackup,
             .enableQuickTypeAutoFill,
             .allowNetworkAccess,
             .hideAppLockSetupReminder:
            return getBool(key) != nil
        case .appLockTimeout,
             .databaseLockTimeout,
             .clipboardTimeout,
             .backupKeepingDuration:
            return getInt(key) != nil
        }
    }

    public func getBoolIfLicensed(_ key: Key) -> Bool? {
        let result: Bool?
        switch key {
        case .autoUnlockLastDatabase,
             .rememberDatabaseKey,
             .rememberDatabaseFinalKey,
             .keepKeyFileAssociations,
             .keepHardwareKeyAssociations,
             .lockAllDatabasesOnFailedPasscode,
             .lockAppOnLaunch,
             .lockDatabasesOnTimeout,
             .useUniversalClipboard,
             .hideProtectedFields,
             .showBackupFiles,
             .backupDatabaseOnSave,
             .excludeBackupFilesFromSystemBackup,
             .enableQuickTypeAutoFill,
             .allowNetworkAccess,
             .hideAppLockSetupReminder:
            result = getBool(key)
        case .license,
             .appLockTimeout,
             .databaseLockTimeout,
             .clipboardTimeout,
             .backupKeepingDuration:
            Diag.error("Key `\(key.rawValue)` is not boolean, ignoring")
            assertionFailure()
            return nil
        }

        guard result != nil else {
            return nil
        }

        if LicenseManager.shared.hasActiveBusinessLicense() {
            return result
        }

        if !hasWarnedAboutMissingLicense {
            Diag.warning("Could not find active business license, managed configuration won't apply.")
            hasWarnedAboutMissingLicense = true
        }
        return nil
    }

    public func getIntIfLicensed(_ key: Key) -> Int? {
        var result: Int?
        switch key {
        case .appLockTimeout,
             .databaseLockTimeout,
             .clipboardTimeout,
             .backupKeepingDuration:
            result = getInt(key)
        case .license,
             .autoUnlockLastDatabase,
             .rememberDatabaseKey,
             .rememberDatabaseFinalKey,
             .keepKeyFileAssociations,
             .keepHardwareKeyAssociations,
             .lockAllDatabasesOnFailedPasscode,
             .lockAppOnLaunch,
             .lockDatabasesOnTimeout,
             .useUniversalClipboard,
             .hideProtectedFields,
             .showBackupFiles,
             .backupDatabaseOnSave,
             .excludeBackupFilesFromSystemBackup,
             .enableQuickTypeAutoFill,
             .allowNetworkAccess,
             .hideAppLockSetupReminder:
            Diag.error("Key `\(key.rawValue)` is not an integer, ignoring.")
            assertionFailure()
            return nil
        }

        guard result != nil else {
            return nil
        }

        if LicenseManager.shared.hasActiveBusinessLicense() {
            return result
        }

        if !hasWarnedAboutMissingLicense {
            Diag.warning("Could not find active business license, managed configuration won't apply.")
            hasWarnedAboutMissingLicense = true
        }
        return nil
    }
}

extension ManagedAppConfig {
    private func getObject(_ key: Key) -> Any? {
        let intuneConfigValue = intuneConfig?[key.rawValue]
        let appleConfigValue = currentConfig?[key.rawValue]
        let anyValue = intuneConfigValue ?? appleConfigValue
        return anyValue
    }

    private func getString(_ key: Key) -> String? {
        return getObject(key) as? String
    }

    private func getBool(_ key: Key) -> Bool? {
        let valueString = getString(key)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch valueString {
        case "true", "on", "1":
            return true
        case "false", "off", "0":
            return false
        default:
            return nil
        }
    }

    private func getInt(_ key: Key) -> Int? {
        guard let valueString = getString(key)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        else {
            return nil
        }
        guard let result = Int(valueString) else {
            Diag.warning("Managed value `\(key.rawValue)` is not an Int, ignoring it.")
            return nil
        }
        return result
    }
}
