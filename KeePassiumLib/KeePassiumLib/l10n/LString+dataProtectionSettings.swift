//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension LString {
    public static let dataProtectionSettingsTitle = NSLocalizedString(
        "[Settings/DataProtection/title]",
        bundle: Bundle.framework,
        value: "Data Protection",
        comment: "Settings section: protection of databases, their keys and data inside them")
    public static let rememberMasterKeysTitle = NSLocalizedString(
        "[Settings/MasterKeys/Remember/title]",
        bundle: Bundle.framework,
        value: "Remember Master Keys",
        comment: "Title of a yes/no setting")
    public static let rememberKeyFilesTitle = NSLocalizedString(
        "[Settings/KeyFiles/Remember/title]",
        bundle: Bundle.framework,
        value: "Remember Key Files",
        comment: "Title of a yes/no setting")
    public static let cacheDerivedKeysTitle = NSLocalizedString(
        "[Settings/MasterKeys/CacheDerived/title]",
        bundle: Bundle.framework,
        value: "Cache Derived Encryption Keys",
        comment: "Setting: preserve (cache) calculated database keys")
}
