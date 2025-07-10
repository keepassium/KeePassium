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
    public static let dataProtectionSettingsSubtitle = NSLocalizedString(
        "[Settings/DataProtection/subtitle]",
        value: "Master keys, key files",
        comment: "Subtitle for `Data Protection` section in settings")

    public static let quickUnlockTitle = NSLocalizedString(
        "[Settings/QuickUnlock/title]",
        value: "Quick Unlock",
        comment: "Title of a section in settings")
    public static let rememberMasterKeysLongDescription = NSLocalizedString(
        "[Settings/MasterKeys/Remember/longDescription]",
        value: "Once you unlock a database, its master key can be stored in device's secure keychain. The next time, KeePassium will use that key so you won't have to type your full master password again. \n\n(Master keys are automatically cleared on database timeout.)",
        comment: "Description of the 'Remember Master Keys' setting.")
    public static let rememberMasterKeysDescription = NSLocalizedString(
        "[Settings/MasterKeys/Remember/description]",
        value: "Once you unlock a database, its master key can be stored in device's secure keychain. The next time, KeePassium will use that key so you won't have to type your full master password again.",
        comment: "Description of the 'Remember Master Keys' setting.")
    public static let clearMasterKeysAction = NSLocalizedString(
        "[Settings/MasterKeys/Clear/action]",
        value: "Clear Master Keys",
        comment: "Action: clear/erase/delete stored master keys")
    public static let masterKeysClearedTitle = NSLocalizedString(
        "[Settings/ClearMasterKeys/Cleared/title]",
        value: "Cleared",
        comment: "Title of the success message for `Clear Master Keys` button")

    public static let dataProtectionAutomaticLockTitle = NSLocalizedString(
        "[Settings/DataProtection/AutomaticLock/title]",
        value: "Automatic Lock",
        comment: "Title of a section in settings")
    public static let databaseTimeoutTitle = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/title]",
        value: "Database Timeout",
        comment: "Title of a setting: the time after which databases will be locked.")
    public static let databaseTimeoutDescription = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/description]",
        value: "If you are not interacting with the app for some time, the database will be closed for your safety. To open it, you will need to enter its master password again.",
        comment: "Description of the `Database Timeout` setting")
    public static let lockDatabasesOnRebootTitle = NSLocalizedString(
        "[Settings/DataProtection/LockOnReboot/title]",
        value: "Lock on Device Restart",
        comment: "Setting switch: whether to lock databases after device reboot.")
    public static let lockDatabasesOnScreenLockTitle = NSLocalizedString(
        "[Settings/DataProtection/LockOnScreenLock/title]",
        value: "Lock on macOS Screen Lock",
        comment: "Title of a yes/no setting: whether to lock databases when computer screen is locked (see https://support.apple.com/en-gb/guide/mac-help/mchl8e8b6a34/mac)")
    public static let clearMasterKeysOnTimeoutTitle = NSLocalizedString(
        "[Settings/MasterKeys/ClearOnTimeout/title]",
        value: "Clear Master Keys on Timeout",
        comment: "Title of a yes/no setting.")

    public static let databaseTimeoutNeverTitle = NSLocalizedString(
        "[Settings/DatabaseTimeout/Never/title]",
        value: "Never",
        comment: "An option in Settings. Will be shown as 'Database Timeout: Never'")
    public static let databaseTimeoutImmediatelyTitle = NSLocalizedString(
        "[Settings/DatabaseTimeout/Immediately/title",
        value: "Immediately",
        comment: "An option in Settings. Will be shown as 'Database Timeout: Immediately'")
    public static let databaseTimeoutImmediatelyDescription = NSLocalizedString(
        "[Settings/DatabaseTimeout/Immediately/description]",
        value: "When leaving the app",
        comment: "A description/subtitle for the 'Database Timeout: Immediately'.")

    public static let clipboardTitle = NSLocalizedString(
        "[Settings/Clipboard/title]",
        value: "Clipboard",
        comment: "Section title in Settings")
    public static let clipboardTimeoutTitle = NSLocalizedString(
        "[Settings/Clipboard/Timeout/title]",
        value: "Clipboard Timeout",
        comment: "Title of a setting: time after which clipboard will be cleared")
    public static let clipboardTimeoutDescription = NSLocalizedString(
        "[Settings/ClipboardTimeout/description]",
        value: "When you copy anything, KeePassium will automatically clear your clipboard after some time.",
        comment: "Description of the 'Clipboard Timeout' setting.")
    public static let clipboardTimeoutNeverTitle = NSLocalizedString(
        "[Settings/ClipboardTimeout/Never/title]",
        value: "Never",
        comment: "An option in Settings. Will be shown as 'Clipboard Timeout: Never'")

    public static let universalClipboardTitle = NSLocalizedString(
        "[Settings/UniversalClipboard/title]",
        value: "Universal Clipboard",
        comment: "Apple's term: https://support.apple.com/102430")
    public static let universalClipboardDescription = NSLocalizedString(
        "[Settings/UniversalClipboard/description]",
        value: "Use Universal Clipboard to copy and paste between your Apple devices. On external devices, this clipboard is cleared after two minutes.",
        comment: "Description of the 'Universal Clipboard' setting.")

    public static let shakeGestureActionTitle = NSLocalizedString(
        "[Settings/ShakeGestureAction/title]",
        value: "When Shaken",
        comment: "Title for a setting: what the app should do when the user shakes the device")
    public static let shakeGestureConfirmationTitle = NSLocalizedString(
        "[Settings/ShakeGestureAction/Confirm/title]",
        value: "Ask for Confirmation",
        comment: "Title for a setting: whether the app should show an 'Are you sure?' before continuing")
    public static let shakeGestureConfirmationDescription = NSLocalizedString(
        "[Settings/ShakeGestureAction/Confirm/description]",
        value: "If the app is locked, it acts without confirmation.",
        comment: "Description of the 'Ask for Confirmation' setting.")

    public static let protectedFieldsTitle = NSLocalizedString(
        "[Settings/ProtectedFields/title]",
        value: "Protected Fields",
        comment: "Title of a section in Settings")
    public static let hidePasswordsTitle = NSLocalizedString(
        "[Settings/HidePasswords/title]",
        value: "Hide Passwords",
        comment: "Title of a yes/no setting")
    public static let hidePasswordsDescription = NSLocalizedString(
        "[Settings/HidePasswords/description]",
        value: "Hide passwords and other protected fields behind asterisks (recommended).",
        comment: "Description of the 'Hide Passwords' setting.")

    public static let keyFilesTitle = NSLocalizedString(
        "[Settings/KeyFiles/title]",
        value: "Key Files",
        comment: "Title of a section in Settings")
    public static let rememberKeyFilesDescription = NSLocalizedString(
        "[Settings/KeyFiles/Remember/description]",
        value: "Remember and automatically select the last used key file for each database. Clearing the associations does not affect the files.",
        comment: "Description of the 'Remember Key Files' setting")
    public static let clearKeyFileAssociationsAction = NSLocalizedString(
        "[Settings/ClearKeyFileAssociations/action]",
        value: "Clear Key File Associations",
        comment: "Action to clear/erase info about which database uses which key file")
    public static let keyFileAssociationsClearedTitle = NSLocalizedString(
        "[Settings/ClearKeyFileAssociations/Cleared/title]",
        value: "Cleared",
        comment: "Title of the success message for `Clear Key File Associations` button")

    public static let dataProtectionAdvancedTitle = NSLocalizedString(
        "[Settings/DataProtection/Advanced/title]",
        value: "Advanced",
        comment: "Section title: advanced/expert settings")
    public static let cacheDerivedKeysDescription = NSLocalizedString(
        "[Settings/MasterKeys/CacheDerived/description]",
        value: "Cached keys allow KeePassium to skip key derivation and YubiKey scans whenever possible.",
        comment: "Description of the 'Cache Derived Encryption Keys' setting")

    // swiftlint:enable line_length
}

extension Settings.DatabaseLockTimeout {
    public var title: String {
        switch self {
        case .never:
            return LString.databaseTimeoutNeverTitle
        case .immediately:
            return LString.databaseTimeoutImmediatelyTitle
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
            return LString.databaseTimeoutNeverTitle
        case .immediately:
            return LString.databaseTimeoutImmediatelyTitle
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
            return LString.databaseTimeoutImmediatelyDescription
        default:
            return nil
        }
    }
}

extension Settings.ClipboardTimeout {
    public var fullTitle: String {
        switch self {
        case .never:
            return LString.clipboardTimeoutNeverTitle
        default:
            let interval = TimeInterval(self.rawValue)
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = (interval < 120) ? [.second] : [.minute, .second]
            formatter.collapsesLargestUnit = true
            formatter.maximumUnitCount = 2
            formatter.unitsStyle = .full
            guard let result = formatter.string(from: interval) else {
                assertionFailure()
                return "?"
            }
            return result
        }
    }
    public var shortTitle: String {
        switch self {
        case .never:
            return LString.clipboardTimeoutNeverTitle
        default:
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.collapsesLargestUnit = true
            formatter.maximumUnitCount = 2
            formatter.unitsStyle = .abbreviated
            guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                assertionFailure()
                return "?"
            }
            return result
        }
    }
}
