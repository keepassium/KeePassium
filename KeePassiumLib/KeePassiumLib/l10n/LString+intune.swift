//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length
extension LString {
    public enum Intune {
        public static let orgNeedsToManage = NSLocalizedString(
            "[Intune/OrgNeedsToManage]",
            bundle: Bundle.framework,
            value: "To protect its data, your organization needs to manage this app. To complete this action, sign in with your work or school account.",
            comment: "Info message for enterprise users")

        public static let personalVersionInAppStore = NSLocalizedString(
            "[Intune/PersonalVersionElsewhere]",
            bundle: Bundle.framework,
            value: "KeePassium version for personal use is available on the App Store.",
            comment: "Info message for users who accidentally installed the enterprise version.")

        public static let orgLicenseMissing = NSLocalizedString(
            "[Org/LicenseMissing]",
            bundle: Bundle.framework,
            value: "KeePassium could not find the enterprise account of your organization.",
            comment: "Error message, euphemism for missing corporate license")

        public static let hintContactYourAdmin = NSLocalizedString(
            "[Org/ContactYourAdmin]",
            bundle: Bundle.framework,
            value: "Please contact your IT administrator.",
            comment: "Suggestion/hint on how to fix an accompanying error.")
    }
}
// swiftlint:enable line_length
