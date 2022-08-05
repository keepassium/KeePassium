//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


open class SettingsMigrator {
    
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
            break
        case 4: 
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
}
