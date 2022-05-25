//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension LString {
    public enum FileInfo {
        public static let menuFileInfo = NSLocalizedString(
            "[Menu/FileInfo/title]",
            bundle: Bundle.framework,
            value: "File Info",
            comment: "Menu item: show information about file (name, size, dates)"
        )
        public static let title = NSLocalizedString(
            "[FileInfo/title]",
            bundle: Bundle.framework,
            value: "File Info",
            comment: "Title of a dialog with file details (name, size, dates)"
        )
        
        public static let fieldFileName = NSLocalizedString(
            "[FileInfo/Field/title] File Name",
            bundle: Bundle.framework,
            value: "File Name",
            comment: "Field title")
        public static let fieldError = NSLocalizedString(
            "[FileInfo/Field/valueError] Error",
            bundle: Bundle.framework,
            value: "Error",
            comment: "Title of a field with an error message")
        public static let fieldFileLocation = NSLocalizedString(
            "[FileInfo/Field/title] File Location",
            bundle: Bundle.framework,
            value: "File Location",
            comment: "Field title")
        public static let fieldFileSize = NSLocalizedString(
            "[FileInfo/Field/title] File Size",
            bundle: Bundle.framework,
            value: "File Size",
            comment: "Field title")
        public static let fieldCreationDate = NSLocalizedString(
            "[FileInfo/Field/title] Creation Date",
            bundle: Bundle.framework,
            value: "Creation Date",
            comment: "Field title")
        public static let fieldModificationDate = NSLocalizedString(
            "[FileInfo/Field/title] Last Modification Date",
            bundle: Bundle.framework,
            value: "Last Modification Date",
            comment: "Field title")
    }
}
