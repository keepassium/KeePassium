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

    public static let titleBitwardenJSON = NSLocalizedString(
        "[Format/BitwardenJSON]",
        value: "Bitwarden (.json)",
        comment: "Name of Bitwarden's JSON file format"
    )

    public static let titleEnpassJSON = NSLocalizedString(
        "[Format/EnpassJSON]",
        value: "Enpass (.json)",
        comment: "Name of Enpass' JSON file format"
    )

    public static let titleOnePassword1PUX = NSLocalizedString(
        "[Format/OnePassword1PUX]",
        value: "1Password (.1pux)",
        comment: "Name of 1Password's 1PUX file format"
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
    public static let importBitwardenEncryptedExport = NSLocalizedString(
        "[Import/Bitwarden/Error/EncryptedExport]",
        value: "This appears to be an encrypted Bitwarden export. Please export as plaintext JSON instead.",
        comment: "Error message when trying to import an encrypted Bitwarden export"
    )
    public static let importOnePasswordEmptyFile = NSLocalizedString(
        "[Import/OnePassword/Error/EmptyFile]",
        value: "1Password file contains no items.",
        comment: "Error message when 1Password import file is empty or contains no items"
    )
    public static let importOnePasswordInvalidZIPFormat = NSLocalizedString(
        "[Import/OnePassword/Error/InvalidZIPFormat]",
        value: "Invalid 1Password file format: %@",
        comment: "Error message when 1Password import fails due to invalid ZIP format [reason: String]"
    )
    public static let importOnePasswordParsingFailed = NSLocalizedString(
        "[Import/OnePassword/Error/ParsingFailed]",
        value: "Failed to parse 1Password file: %@",
        comment: "Error message when 1Password import fails during JSON parsing [reason: String]"
    )
    public static let importOnePasswordCorruptedAttachmentData = NSLocalizedString(
        "[Import/OnePassword/Error/CorruptedAttachment]",
        value: "Corrupted data for attachment '%@' in item '%@'.",
        comment: "Error message when 1Password import fails due to corrupted attachment data [attachmentName: String, itemName: String]"
    )
    // swiftlint:enable line_length
}
