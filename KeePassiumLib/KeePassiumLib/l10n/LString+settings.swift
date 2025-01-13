//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length
extension LString {
    public static let titleSettings = NSLocalizedString(
        "[Settings/title]",
        bundle: Bundle.framework,
        value: "Settings",
        comment: "Title of the app settings screen")
    public static let menuSettingsMacOS = NSLocalizedString(
        "[Menu/Settings/title]",
        bundle: Bundle.framework,
        value: "Settings…",
        comment: "Menu title: app settings")

    public static let actionRestoreDefaults = NSLocalizedString(
        "[Settings/RestoreDefaults/action]",
        bundle: Bundle.framework,
        value: "Restore Defaults",
        comment: "Action/button which resets some settings to their default state.")

    public static let appLockWithBiometricsSubtitleTemplate = NSLocalizedString(
        "[Settings/AppLock/subtitle] App Lock, %@, timeout",
        bundle: Bundle.framework,
        value: "App Lock, %@, timeout",
        comment: "Settings: subtitle of the `App Protection` section. biometryTypeName will be either 'Touch ID' or 'Face ID'. [biometryTypeName: String]")
    public static let appLockWithPasscodeSubtitle = NSLocalizedString(
        "[Settings/AppLock/subtitle] App Lock, passcode, timeout",
        bundle: Bundle.framework,
        value: "App Lock, passcode, timeout",
        comment: "Settings: subtitle of the `App Protection` section when biometric auth is not available.")

    public static let premiumVersion = NSLocalizedString(
        "[Premium/Status/title]",
        bundle: Bundle.framework,
        value: "Premium Version",
        comment: "Status when the user has a premium version")
    public static let premiumStatusBetaTesting = NSLocalizedString(
        "[Premium/status] Beta testing",
        bundle: Bundle.framework,
        value: "Beta testing",
        comment: "Status: special premium for beta-testing environment is active")
    public static let premiumStatusValidForever = NSLocalizedString(
        "[Premium/status] Valid forever",
        bundle: Bundle.framework,
        value: "Valid forever",
        comment: "Status: validity period of once-and-forever premium")
    public static let premiumStatusNextRenewalTemplate = NSLocalizedString(
        "[Premium/status] Next renewal on %@",
        bundle: Bundle.framework,
        value: "Next renewal on %@",
        comment: "Status: scheduled renewal date of a premium subscription. For example: `Next renewal on 1 Jan 2050`. [expiryDateString: String]")
    public static let premiumStatusExpiredTemplate = NSLocalizedString(
        "[Premium/status] Expired %@ ago. Please renew.",
        bundle: Bundle.framework,
        value: "Expired %@ ago. Please renew.",
        comment: "Status: premium subscription has expired. For example: `Expired 1 day ago`. [timeFormatted: String, includes the time unit (day, hour, minute)]")
    public static let premiumStatusLicensedVersionTemplate = NSLocalizedString(
        "[Premium/status] Licensed version: %@",
        bundle: Bundle.framework,
        value: "Licensed version: %@",
        comment: "Status: licensed premium version of the app. For example: `Licensed version: 1.23`. [version: String]")
    public static let premiumStatusCurrentVersionTemplate = NSLocalizedString(
        "[Premium/status] Current version: %@",
        bundle: Bundle.framework,
        value: "Current version: %@",
        comment: "Status: current version of the app. For example: `Current version: 1.23`. Should be similar to the `Licensed version` string. [version: String]")

    public static let appBeingUsefulTemplate = NSLocalizedString(
        "[Premium/usage] App being useful: %@/month, that is around %@/year.",
        bundle: Bundle.framework,
        value: "App being useful: %@/month, that is around %@/year.",
        comment: "Status: how long the app has been used during some time period. For example: `App being useful: 1hr/month, about 12hr/year`. [monthlyUsage: String, annualUsage: String — already include the time unit (hours, minutes)]")


    public static let autoOpenPreviousDatabase = NSLocalizedString(
        "[Settings/AutoOpenPreviousDatabase/title]",
        bundle: Bundle.framework,
        value: "Auto-Open Previous Database",
        comment: "Option in settings: whether to open the last used database automatically on start.")


    public static let titleAppearanceSettings = NSLocalizedString(
        "[Appearance/title]",
        bundle: Bundle.framework,
        value: "Appearance",
        comment: "Group of settings for user interface appearance (text size, icons, etc)")

    public static let titleAppIcon = NSLocalizedString(
        "[Appearance/AppIcon/title]",
        bundle: Bundle.framework,
        value: "App Icon",
        comment: "Section in settings: icon for the app")
    public static let titleDatabaseIcons = NSLocalizedString(
        "[Appearance/DatabaseIcons/title]",
        bundle: Bundle.framework,
        value: "Database Icons",
        comment: "Section in settings: icons for database")

    public static let titleTextSize = NSLocalizedString(
        "[Appearance/TextSize/title]",
        bundle: Bundle.framework,
        value: "Text Size",
        comment: "Title of a setting option: font size")

    public static let titleTextFont = NSLocalizedString(
        "[Appearance/Font/title]",
        bundle: Bundle.framework,
        value: "Font",
        comment: "Title of a setting option: font")

    public static let titleDefaultFont = NSLocalizedString(
        "[Appearance/DefaultFont/shortTitle]",
        bundle: Bundle.framework,
        value: "Default",
        comment: "Short name of the default/system font. For example: `Font: Default`")


    public static let titleAutoFillSettings = NSLocalizedString(
        "[Settings/AutoFill/title]",
        bundle: Bundle.framework,
        value: "AutoFill Passwords",
        comment: "Title of AutoFill settings screen")

    public static let actionActivateAutoFill = NSLocalizedString(
        "[Settings/AutoFill/Activate/action]",
        bundle: Bundle.framework,
        value: "Activate AutoFill",
        comment: "Action that opens system settings or instructions")
    public static let titleAutoFillSetupGuide = NSLocalizedString(
        "[Settings/AutoFill/Setup Guide/title]",
        bundle: Bundle.framework,
        value: "AutoFill Setup Guide",
        comment: "Title of a help article on how to activate AutoFill.")
    public static let howToActivateAutoFillDescription = NSLocalizedString(
        "[Settings/AutoFill/Activate/description]",
        bundle: Bundle.framework,
        value: "Before first use, you need to activate AutoFill in system settings.",
        comment: "Description for the AutoFill setup instructions")
    public static let autoFillUnavailableInIntuneDescription = NSLocalizedString(
        "[Settings/AutoFill/UnavailableInIntune/description]",
        bundle: Bundle.framework,
        value: "AutoFill is not available in KeePassium for Intune.",
        comment: "")

    public static let titleQuickAutoFill = NSLocalizedString(
        "[QuickAutoFill/title]",
        bundle: Bundle.framework,
        value: "Quick AutoFill",
        comment: "Name of a feature that shows relevant entries directly next to the login/password forms.")
    public static let quickAutoFillDescription = NSLocalizedString(
        "[QuickAutoFill/description]",
        bundle: Bundle.framework,
        value: "Quick AutoFill shows relevant entries right next to the password field, without opening KeePassium.",
        comment: "Description of the Quick AutoFill feature.")

    public static let titleAutoFillPerfectMatch = NSLocalizedString(
        "[Settings/AutoFill/UsePerfectMatch/title]",
        bundle: Bundle.framework,
        value: "Fill-In Perfect Result Automatically",
        comment: "Title of an option: automatically use the single best match found by AutoFill search")
    public static let titleCopyOTPtoClipboard = NSLocalizedString(
        "[Settings/AutoFill/CopyOTP/title]",
        bundle: Bundle.framework,
        value: "Copy OTP to Clipboard",
        comment: "Title of an option: copy one-time password to clipboard when using AutoFill")


    public static let titleSearchSettings = NSLocalizedString(
        "[Settings/Search/title]",
        bundle: Bundle.framework,
        value: "Search",
        comment: "Section title in settings")


    public static let titleAppProtection = titleAppProtectionSettings
    public static let titleAppProtectionSettings = NSLocalizedString(
        "[Settings/AppLock/title]",
        bundle: Bundle.framework,
        value: "App Protection",
        comment: "Settings section: protection of the app from unauthorized access")
    public static let callToActionActivateAppProtection = NSLocalizedString(
        "[Settings/AppLoc/Activate/callToAction]",
        bundle: Bundle.framework,
        value: "Activate App Protection",
        comment: "Call to action (protect the app from unauthorized access)")
    public static let appProtectionDescription = NSLocalizedString(
        "[Settings/AppLock/Activate/description]",
        bundle: Bundle.framework,
        value: "Protect KeePassium from unauthorized access.",
        comment: "Description of `Activate app protection` call to action.")
    public static let titleUseBiometryTypeTemplate = NSLocalizedString(
        "[Settings/AppLock/Biometric/title] Use %@",
        bundle: Bundle.framework,
        value: "Use %@",
        comment: "Settings switch: whether AppLock is allowed to use Touch ID/Face ID. Example: 'Use Touch ID'. [biometryTypeName: String]")

    public static let lockAppOnLaunchTitle = NSLocalizedString(
        "[Settings/AppLock/LockOnLaunch/title]",
        bundle: Bundle.framework,
        value: "Lock on App Launch",
        comment: "Setting switch: whether to lock the app after it was terminated and relaunched.")
    public static let lockAppOnLaunchDescription = NSLocalizedString(
        "[Settings/AppLock/LockOnLaunch/description]",
        bundle: Bundle.framework,
        value: "Ensures KeePassium is locked after you force-close the app or restart the device.",
        comment: "Explanation for the `Lock on App Launch` setting")
    public static let appProtectionTimeoutNeverFull = NSLocalizedString(
        "[Settings/AppLockTimeout/fullTitle] Never",
        bundle: Bundle.framework,
        value: "Never",
        comment: "An option in Settings. Will be shown as 'App Lock: Timeout: Never'")
    public static let appProtectionTimeoutNeverShort = NSLocalizedString(
        "[Settings/AppLockTimeout/shortTitle] Never",
        bundle: Bundle.framework,
        value: "Never",
        comment: "An option in Settings. Will be shown as 'App Lock: Timeout: Never'")
    public static let appProtectionTimeoutImmediatelyFull = NSLocalizedString(
        "[Settings/AppLockTimeout/fullTitle] Immediately",
        bundle: Bundle.framework,
        value: "Immediately",
        comment: "An option in Settings. Will be shown as 'App Lock: Timeout: Immediately'")
    public static let appProtectionTimeoutImmediatelyShort = NSLocalizedString(
        "[Settings/AppLockTimeout/shortTitle] Immediately",
        bundle: Bundle.framework,
        value: "Immediately",
        comment: "An option in Settings. Will be shown as 'App Lock: Timeout: Immediately'")
    public static let appProtectionTimeoutAfterLeavingApp = NSLocalizedString(
        "[Settings/AppLockTimeout/description] After leaving the app",
        bundle: Bundle.framework,
        value: "After leaving the app",
        comment: "A description/subtitle for Settings/AppLock/Timeout options that trigger when the app is minimized. For example: 'AppLock Timeout: 3 seconds (After leaving the app)")
    public static let appProtectionTimeoutAfterLastInteraction = NSLocalizedString(
        "[Settings/AppLockTimeout/description] After last interaction",
        bundle: Bundle.framework,
        value: "After last interaction",
        comment: "A description/subtitle for Settings/AppLockTimeout options that trigger when the user has been idle for a while. For example: 'AppLock Timeout: 3 seconds (After last interaction)")


    public static let titleDataProtectionSettings = NSLocalizedString(
        "[Settings/DataProtection/title]",
        bundle: Bundle.framework,
        value: "Data Protection",
        comment: "Settings section: protection of databases, their keys and data inside them")
    public static let subtitleDataProtectionSettings = NSLocalizedString(
        "[Settings/DataProtection/subtitle]",
        bundle: Bundle.framework,
        value: "Master keys, key files",
        comment: "Subtitle for `Data Protection` section in settings")

    public static let masterKeysClearedTitle = NSLocalizedString(
        "[Settings/ClearMasterKeys/Cleared/title] Cleared",
        bundle: Bundle.framework,
        value: "Cleared",
        comment: "Title of the success message for `Clear Master Keys` button")
    public static let masterKeysClearedMessage = NSLocalizedString(
        "[Settings/ClearMasterKeys/Cleared/text] All master keys have been deleted.",
        bundle: Bundle.framework,
        value: "All master keys have been deleted.",
        comment: "Text of the success message for `Clear Master Keys` button")

    public static let keyFileAssociationsClearedTitle = NSLocalizedString(
        "[Settings/ClearKeyFileAssociations/Cleared/title] Cleared",
        bundle: Bundle.framework,
        value: "Cleared",
        comment: "Title of the success message for `Clear Key File Associations` button")
    public static let keyFileAssociationsClearedMessage = NSLocalizedString(
        "[Settings/ClearKeyFileAssociations/Cleared/text] Associations between key files and databases have been removed.",
        bundle: Bundle.framework,
        value: "Associations between key files and databases have been removed.",
        comment: "Text of the success message for `Clear Key File Associations` button")

    public static let lockDatabasesOnRebootTitle = NSLocalizedString(
        "[Settings/DataProtection/LockOnReboot/title]",
        bundle: Bundle.framework,
        value: "Lock on Device Restart",
        comment: "Setting switch: whether to lock databases after device reboot.")
    public static let databaseTimeoutTitle = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/title]",
        bundle: Bundle.framework,
        value: "Database Timeout",
        comment: "Title of a setting: the time after which databases will be locked.")
    public static let databaseTimeoutDescription = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/description] If you are not interacting with the app for some time, the database will be closed for your safety. To open it, you will need to enter its master password again.",
        bundle: Bundle.framework,
        value: "If you are not interacting with the app for some time, the database will be closed for your safety. To open it, you will need to enter its master password again.",
        comment: "Description of the Database Lock Timeout")

    public static let clipboardTimeoutDescription = NSLocalizedString(
        "[Settings/ClipboardTimeout/description] When you copy some text from an entry, the app will automatically clear your clipboard (pasteboard) after this time.",
        bundle: Bundle.framework,
        value: "When you copy some text from an entry, the app will automatically clear your clipboard (pasteboard) after this time.",
        comment: "Description of the clipboard/pasteboard timeout.")

    public static let databaseLockTimeoutNeverFull = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/fullTitle] Never",
        bundle: Bundle.framework,
        value: "Never",
        comment: "An option in Settings. Will be shown as 'Database Lock: Timeout: Never'")
    public static let databaseLockTimeoutNeverShort = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/shortTitle] Never",
        bundle: Bundle.framework,
        value: "Never",
        comment: "An option in Settings. Will be shown as 'Database Lock: Timeout: Never'")
    public static let databaseLockTimeoutImmediatelyFull = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/fullTitle] Immediately",
        bundle: Bundle.framework,
        value: "Immediately",
        comment: "An option in Settings. Will be shown as 'Database Lock: Timeout: Immediately'")
    public static let databaseLockTimeoutImmediatelyShort = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/shortTitle] Immediately",
        bundle: Bundle.framework,
        value: "Immediately",
        comment: "An option in Settings. Will be shown as 'Database Lock: Timeout: Immediately'")
    public static let databaseLockTimeoutWhenLeavingApp = NSLocalizedString(
        "[Settings/DatabaseLockTimeout/description] When leaving the app",
        bundle: Bundle.framework,
        value: "When leaving the app",
        comment: "A description/subtitle for the 'DatabaseLockTimeout: Immediately'.")

    public static let titleNetworkAccessSettings = NSLocalizedString(
        "[Settings/NetworkAccess/title]",
        bundle: Bundle.framework,
        value: "Network Access",
        comment: "Settings section: how/whether the app is allowed to use networks/Internet")
    public static let titleStayOffline = NSLocalizedString(
        "[Settings/NetworkAccessMode/Offline/title]",
        bundle: Bundle.framework,
        value: "Stay Offline",
        comment: "Setting option: the app should work offline")
    public static let titleAllowNetworkAccess = NSLocalizedString(
        "[Settings/NetworkAccessMode/Online/title]",
        bundle: Bundle.framework,
        value: "Allow Network Access",
        comment: "Setting option: the app is permitted to use online features")
    public static let titleMaximumPrivacy = NSLocalizedString(
        "[Settings/NetworkAccessMode/Offline/description]",
        bundle: Bundle.framework,
        value: "Maximum privacy",
        comment: "Description of the `Stay Offline` mode.")
    public static let titleMaximumFunctionality = NSLocalizedString(
        "[Settings/NetworkAccessMode/Online/description]",
        bundle: Bundle.framework,
        value: "Maximum functionality",
        comment: "Description of the `Allow Network Access` mode.")
    public static let allowNetwokAccessQuestionText = NSLocalizedString(
        "[Settings/NetworkAccess/Confirmation/text]",
        bundle: Bundle.framework,
        value: "Allow KeePassium to make network connections to external services?",
        comment: "Confirmation dialog message")


    public static let titleDatabaseBackupSettings = NSLocalizedString(
        "[Settings/DatabaseBackup/title]",
        bundle: Bundle.framework,
        value: "Database Backup",
        comment: "Title of a settings section: backup of databases")
    public static let actionDeleteAllBackupFilesTemplate = NSLocalizedString(
        "[Settings/Backup] Delete ALL Backup Files (%d)",
        bundle: Bundle.framework,
        value: "Delete ALL Backup Files (%d)",
        comment: "Action to delete all backup files from the app. `ALL` is in capitals as a highlight. [backupFileCount: Int]")
    public static let noBackupFilesFound = NSLocalizedString(
        "[Settings/Backup] No Backup Files Found",
        bundle: Bundle.framework,
        value: "No Backup Files Found",
        comment: "Status message: there are no backup files to delete")

    public static let confirmDeleteAllBackupFiles = NSLocalizedString(
        "[Settings/Backup/Delete/title] Delete all backup files?",
        bundle: Bundle.framework,
        value: "Delete all backup files?",
        comment: "Confirmation dialog message to delete all backup files")


    public static let subtitleContactUs = NSLocalizedString(
        "[ContactUs/subtitle]",
        bundle: Bundle.framework,
        value: "Suggestions? Problems? Let us know!",
        comment: "Subtitle for `Contact Us`. Keep it short.")
    public static let titleDiagnosticLog = NSLocalizedString(
        "[DiagLog/title]",
        bundle: Bundle.framework,
        value: "Diagnostic Log",
        comment: "Title of the diagnostic info screen")
    public static let subtitleDiagnosticLog = NSLocalizedString(
        "[DiagLog/subtitle]",
        bundle: Bundle.framework,
        value: "For expert troubleshooting",
        comment: "Subtitle for `Diagnostic Log`. Keep it short.")

    public static let titleAboutKeePassium = NSLocalizedString(
        "[About/altTitle]",
        bundle: Bundle.framework,
        value: "About KeePassium",
        comment: "Menu item that shows info about KeePassium app")

    public static let actionResetApp = NSLocalizedString(
        "[App/ResetEverything/action]",
        bundle: Bundle.framework,
        value: "Reset",
        comment: "Action which resets the app as if it was just installed.")
    public static let confirmAppReset = NSLocalizedString(
        "[App/ResetEverything/title]",
        bundle: Bundle.framework,
        value: "Reset the app?",
        comment: "Confirmation message before resetting the app to just-installed state.")

    public static let thisSettingIsManaged = NSLocalizedString(
        "[Settings/Managed/notification]",
        bundle: Bundle.framework,
        value: "This setting is managed by your organization.",
        comment: "Notification when corporate user tries to change an app setting controlled by organization's IT department.")
    public static let thisFeatureIsBlockedByOrg = NSLocalizedString(
        "[Settings/Managed/BlockedFeature/notification]",
        bundle: Bundle.framework,
        value: "This feature is blocked by your organization.",
        comment: "Notification when corporate user tries to use a feature forbidden by organization's IT department.")
}
// swiftlint:enable line_length
