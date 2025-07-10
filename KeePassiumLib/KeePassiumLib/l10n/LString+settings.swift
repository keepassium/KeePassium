//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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
