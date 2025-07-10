//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension LString {
    public static let searchSettingsTitle = NSLocalizedString(
        "[Settings/Search/title]",
        value: "Search",
        comment: "Section title in settings")
    public static let searchScopeTitle = NSLocalizedString(
        "[Settings/Search/Scope/title]",
        value: "Search Scope",
        comment: "Title of a setting: which fields to consider in search")
    public static let startWithSearchTitle = NSLocalizedString(
        "[Settings/Search/StartWithSearch/title]",
        value: "Start with Search",
        comment: "Title of a setting: whether to open search field immediately after opening a database")
    public static let startWithSearchDescription = NSLocalizedString(
        "[Settings/Search/StartWithSearch/description]",
        value: "After opening a database, automatically show the search field.",
        comment: "Description of the 'Start with Search' setting.")
    public static let searchInPasswordsTitle = NSLocalizedString(
        "[Settings/Search/InPasswords/title]",
        value: "Search in Passwords",
        comment: "Title of a setting: whether search looks in passwords")
    public static let searchInFieldNamesTitle = NSLocalizedString(
        "[Settings/Search/InFieldNames/title]",
        value: "Search in Field Names",
        comment: "Title of a setting: whether search looks in field names")
    public static let searchInProtectedValuesTitle = NSLocalizedString(
        "[Settings/Search/InProtectValues/title]",
        value: "Search in Protected Values",
        comment: "Title of a setting: whether search looks in values of protected fields")
}
