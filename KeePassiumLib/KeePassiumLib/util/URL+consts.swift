//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension URL {
    public enum Prefs {
        private static let autoFillPreferencesURL_macOS =
            URL(string: "x-apple.systempreferences:com.apple.Passwords-Settings.extension?Options")!

        private static let autoFillPreferencesURL_iOS = URL(string: "App-prefs:PASSWORDS&path=PASSWORD_OPTIONS")!

        public static var autoFillPreferences: URL {
            if ProcessInfo.isRunningOnMac {
                return autoFillPreferencesURL_macOS
            } else {
                return autoFillPreferencesURL_iOS
            }
        }
    }
    public enum AppHelp {
        public static let helpIndex = URL(string: "https://keepassium.com/apphelp/")!

        public static let termsAndConditions = URL(string: "https://keepassium.com/terms/app")!
        public static let privacyPolicyOfflineMode = URL(string: "https://keepassium.com/privacy/app")!
        public static let privacyPolicyOnlineMode = URL(string: "https://keepassium.com/privacy/app")!
        public static var currentPrivacyPolicy: URL {
            if Settings.current.isNetworkAccessAllowed {
                return privacyPolicyOnlineMode
            } else {
                return privacyPolicyOfflineMode
            }
        }

        public static let quickAutoFillIntro = URL(string: "https://keepassium.com/apphelp/quick-autofill/")!
        public static let autoFillMemoryLimits = URL(string: "https://keepassium.com/apphelp/autofill-memory-limits/")!
        public static let autoFillSetupGuide_iOS = URL(string: "https://keepassium.com/apphelp/how-to-set-up-autofill-ios/")!
        public static let autoFillSetupGuide_macOS = URL(string: "https://keepassium.com/apphelp/how-to-set-up-autofill-macos/")!
        public static var autoFillSetupGuide: URL {
            if ProcessInfo.isRunningOnMac {
                return autoFillSetupGuide_macOS
            } else {
                return autoFillSetupGuide_iOS
            }
        }

        public static let perpetualFallback = URL(string: "https://keepassium.com/apphelp/perpetual-fallback-license/")!
        public static let familySharing = URL(string: "https://keepassium.com/apphelp/family-sharing/")!

        public static let yubikeySetup = URL(string: "https://keepassium.com/apphelp/yubikey-setup/")!

        public static let databaseFileIsInTrashWarning = URL(string: "https://keepassium.com/apphelp/database-recently-deleted-warning/")!
        public static let temporaryBackupDatabaseWarning = URL(string: "https://keepassium.com/apphelp/temporary-backup-database-warning/")!

        public static let hibpMoreInfoURLString = "https://www.troyhunt.com/ive-just-launched-pwned-passwords-version-2/#cloudflareprivacyandkanonymity"

        public static let smartGroups = URL(string: "https://keepassium.com/apphelp/smart-groups/")!

        public static let linkedDatabases = URL(string: "https://keepassium.com/apphelp/linked-databases/")!

        public static let invalidDatabasePassword = URL(string: "https://keepassium.com/apphelp/invalid-database-password/")!
        public static let fileDoesNotExist = URL(string: "https://keepassium.com/apphelp/does-not-exist/")!
        public static let fileProviderUnresponsive = URL(string: "https://keepassium.com/apphelp/file-provider-unresponsive/")!
    }

}
