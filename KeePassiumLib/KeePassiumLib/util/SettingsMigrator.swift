//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

open class SettingsMigrator {
    
    public static func processAppLaunch(with settings: Settings) {
        if settings.isFirstLaunch {
            Diag.info("Processing first launch.")
            settings.settingsVersion = Settings.latestVersion
            
            cleanupKeychain()
        } else {
            let latestVersion = Settings.latestVersion
            while settings.settingsVersion < latestVersion {
                upgrade(settings)
            }
        }
    }

    
    private static func cleanupKeychain() {
        do {
            try Keychain.shared.removeAll() 
        } catch {
            Diag.error("Failed to clean up keychain [message: \(error.localizedDescription)]")
        }
    }
    
    private static func upgrade(_ settings: Settings) {
        let fromVersion = settings.settingsVersion
        switch fromVersion {
        case 0: 
            assert(settings.isFirstLaunch)
            settings.settingsVersion = Settings.latestVersion
        case 3:
            break
        default:
            break
        }
    }
    
    
}
