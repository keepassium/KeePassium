//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public final class SettingsMigrator {
    static let initialSettingsVersion = 4

    public static func processAppLaunch(with settings: Settings) {
        if settings.isFirstLaunch {
            Diag.info("Processing first launch.")
            settings.settingsVersion = Settings.latestVersion

            Keychain.shared.reset()
        } else {
            let latestVersion = Settings.latestVersion
            while settings.settingsVersion < latestVersion {
                upgrade(settings)
            }
        }
    }

    private static func upgrade(_ settings: Settings) {
        let fromVersion = settings.settingsVersion
        switch fromVersion {
        case 0: 
            assert(settings.isFirstLaunch)
            settings.settingsVersion = Settings.latestVersion
        case 3:
            upgradeVersion3toVersion4(settings)
        case 4:
            upgradeVersion4toVersion5(settings)
        case 5:
            break
        default:
            break
        }
    }

    private static func upgradeVersion3toVersion4(_ settings: Settings) {
        if settings.isBiometricAppLockEnabled {
            Keychain.shared.prepareBiometricAuth(true)
        }
        settings.settingsVersion = 4
    }

    private static func upgradeVersion4toVersion5(_ settings: Settings) {
        settings.migrateFileReferencesToKeychain()
        settings.migrateUserActivityTimestampToKeychain()
        FileKeeper.shared.migrateFileReferencesToKeychain()
        settings.settingsVersion = 5
    }
}
