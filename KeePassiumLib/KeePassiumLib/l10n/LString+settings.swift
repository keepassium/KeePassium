//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length
extension LString {
    public static let titleYes = NSLocalizedString(
        "[Settings/Value/Yes/title]",
        bundle: Bundle.framework,
        value: "Yes",
        comment: "Title of a settings value. For example: `Remember Master Keys: Yes`")
    public static let titleNo = NSLocalizedString(
        "[Settings/Value/No/title]",
        bundle: Bundle.framework,
        value: "No",
        comment: "Title of a settings value. For example: `Remember Master Keys: No`")
    public static let titleUseAppSettingsTemplate = NSLocalizedString(
        "[Settings/Value/UseAppSettings/title]",
        bundle: Bundle.framework,
        value: "Use App Settings (%@)",
        comment: "Title of a settings value, when it is not customized and we default to app's global settings. For example: `Remember Master Keys: Use App Settings (No)`")
    public static let titleUseAppSettingsShortTemplate = "(%@)"

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

    public static let titleAutoDownloadFavicons = NSLocalizedString(
        "[Settings/AutoDownloadFavicons/title]",
        bundle: Bundle.framework,
        value: "Auto-Download Favicons",
        comment: "Settings option: automatically download website icons/favicons")

    public static let descriptionAutoDownloadFavicons = NSLocalizedString(
        "[Settings/AutoDownloadFavicons/description]",
        bundle: Bundle.framework,
        value: "Automatically download website icon after editing an entry.",
        comment: "Description of the auto-download favicons feature")

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
