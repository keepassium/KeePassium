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
    public static let appearanceSettingsTitle = NSLocalizedString(
        "[Appearance/title]",
        value: "Appearance",
        comment: "Group of settings for user interface appearance (text size, icons, etc)")

    public static let appearanceAppIconTitle = NSLocalizedString(
        "[Appearance/AppIcon/title]",
        value: "App Icon",
        comment: "Section in settings: icon for the app")
    public static let appearanceDatabaseIconsTitle = NSLocalizedString(
        "[Appearance/DatabaseIcons/title]",
        value: "Database Icons",
        comment: "Section in settings: icons for database")

    public static let appearanceEntryViewerTitle = NSLocalizedString(
        "[Appearance/EntryViewer/title]",
        value: "Entry Viewer",
        comment: "Section in settings: parameters related to entry viewer component")
    public static let appearanceOpenLastUsedTabTitle = NSLocalizedString(
        "[Appearance/EntryViewer/OpenLastUsedTab/title]",
        value: "Open Last Used Tab",
        comment: "Title of a setting: whether the Entry Viewer should open on the same tab/page when switching between entries, or switch to the first tab instead.")
    public static let appearanceTextSizeTitle = NSLocalizedString(
        "[Appearance/TextSize/title]",
        value: "Text Size",
        comment: "Title of a setting option: font size")
    public static let actionResetTextSize = NSLocalizedString(
        "[Appearance/TextSize/reset]",
        value: "Reset text size to default",
        comment: "Action: set text size to standard size")

    public static let appearanceFontTitle = NSLocalizedString(
        "[Appearance/Font/title]",
        value: "Font",
        comment: "Title of a setting option: font")

    public static let appearanceFontDefaultTitle = NSLocalizedString(
        "[Appearance/DefaultFont/shortTitle]",
        value: "Default",
        comment: "Short name of the default/system font. For example: `Font: Default`")
    // swiftlint:enable line_length
}
