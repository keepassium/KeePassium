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
    public static let appBeingUsefulTemplate = NSLocalizedString(
        "[Premium/usage] App being useful: %@/month, that is around %@/year.",
        value: "App being useful: %@/month, that is around %@/year.",
        comment: "Status: how long the app has been used during some time period. For example: `App being useful: 1hr/month, about 12hr/year`. [monthlyUsage: String, annualUsage: String — already include the time unit (hours, minutes)]")

    public static let settingsStartSectionTitle = NSLocalizedString(
        "[Settings/Start/title]",
        value: "Start",
        comment: "Title of a section in settings: parameters that control what happens when the app is started.")
    public static let autoOpenPreviousDatabase = NSLocalizedString(
        "[Settings/AutoOpenPreviousDatabase/title]",
        value: "Auto-Open Previous Database",
        comment: "Option in settings: whether to open the last used database automatically on start.")

    public static let settingsPremiumSectionTitle = NSLocalizedString(
        "[Settings/Premium/title]",
        value: "Premium",
        comment: "Title of a section in settings")
    public static let premiumVersion = NSLocalizedString(
        "[Premium/Status/title]",
        value: "Premium Version",
        comment: "Status when the user has a premium version")
    public static let premiumStatusBetaTesting = NSLocalizedString(
        "[Premium/Status/BetaTesting/title]",
        value: "Beta testing",
        comment: "Status: special premium for beta-testing environment is active")
    public static let premiumStatusValidForever = NSLocalizedString(
        "[Premium/Status/ValidForever/title]",
        value: "Valid forever",
        comment: "Status: validity period of once-and-forever premium")
    public static let premiumStatusNextRenewalTemplate = NSLocalizedString(
        "[Premium/Status/nextRenewal]",
        value: "Next renewal on %@",
        comment: "Status: scheduled renewal date of a premium subscription. For example: `Next renewal on 1 Jan 2050`. [expiryDateString: String]")
    public static let premiumStatusExpiredTemplate = NSLocalizedString(
        "[Premium/Status/expiredAgo]",
        value: "Expired %@ ago. Please renew.",
        comment: "Status: premium subscription has expired. For example: `Expired 1 day ago`. [timeFormatted: String, includes the time unit (day, hour, minute)]")
    public static let premiumStatusLicensedVersionTemplate = NSLocalizedString(
        "[Premium/Status/licensedVersion]",
        value: "Licensed version: %@",
        comment: "Status: licensed premium version of the app. For example: `Licensed version: 1.23`. [version: String]")
    public static let premiumStatusCurrentVersionTemplate = NSLocalizedString(
        "[Premium/Status/currentVersion]",
        value: "Current version: %@",
        comment: "Status: current version of the app. For example: `Current version: 1.23`. Should be similar to the `Licensed version` string. [version: String]")

    public static let settingsAccessControlTitle = NSLocalizedString(
        "[Settings/AccessControl/title]",
        value: "Access Control",
        comment: "Title of a section in settings: parameters that protect access to data")
    public static let settingsSupportSectionTitle = NSLocalizedString(
        "[Settings/Support/title]",
        value: "Support",
        comment: "Title of a section in settings: technical support and diagnostics")

    public static let contactUsSubtitle = NSLocalizedString(
        "[ContactUs/subtitle]",
        value: "Suggestions? Problems? Let us know!",
        comment: "Subtitle for `Contact Us`. Keep it short.")

    public static let diagnosticLogSubtitle = NSLocalizedString(
        "[DiagLog/subtitle]",
        value: "For expert troubleshooting",
        comment: "Subtitle for `Diagnostic Log`. Keep it short.")

    public static let aboutKeePassiumTitle = NSLocalizedString(
        "[About/altTitle]",
        value: "About KeePassium",
        comment: "Menu item that shows info about KeePassium app")
    // swiftlint:enable line_length
}
