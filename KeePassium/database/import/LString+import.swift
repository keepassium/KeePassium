//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension LString {
    public static let titleApplePasswordsCSV = NSLocalizedString(
        "[Format/ApplePasswordsCSV]",
        value: "Apple Passwords (.csv)",
        comment: "Name of Apple Passwords' CSV file format"
    )

    public static let titleEnpassJSON = NSLocalizedString(
        "[Format/EnpassJSON]",
        value: "Enpass (.json)",
        comment: "Name of Enpass' JSON file format"
    )
}

extension LString.Error {
    // swiftlint:disable line_length
    public static let importEmptyIncomingFile = NSLocalizedString(
        "[Import/Error/EmptyFile]",
        value: "Incoming file is empty.",
        comment: "Error shown when trying to import from an empty file"
    )
    public static let importCSVInvalidFormatWithColumnTemplate = NSLocalizedString(
        "[Import/CSV/Error/InvalidFormat/withColumn]",
        value: "Invalid CSV format at line %d, column %d.",
        comment: "Error message when CSV parsing fails [lineNumber: Int, colNumber: Int]"
    )
    public static let importCSVInvalidFormatTemplate = NSLocalizedString(
        "[Import/CSV/Error/InvalidFormat]",
        value: "Invalid CSV format at line %d.",
        comment: "Error message when CSV parsing fails [lineNumber: Int]"
    )
    public static let importJSONParsingFailed = NSLocalizedString(
        "[Import/JSON/ParsingError]",
        value: "Failed to parse JSON file.",
        comment: "Error message when JSON parsing fails"
    )
    public static let importEnpassCorruptedAttachmentTemplate = NSLocalizedString(
        "[Import/Enpass/Error/CorruptedAttachment]",
        value: "Corrupted data for attachment '%@' in item '%@'.",
        comment: "Error message when Enpass import fails due to corrupted attachment data [attachmentName: String, itemName: String]"
    )
    // swiftlint:enable line_length
}
