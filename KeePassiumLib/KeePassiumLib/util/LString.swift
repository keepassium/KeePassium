//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

internal enum LString {
        
    enum Error {
        public static let passwordAndKeyFileAreBothEmpty = NSLocalizedString(
            "[Database/Unlock/Error] Password and key file are both empty.",
            bundle: Bundle.framework,
            value: "Password and key file are both empty.",
            comment: "Error message")
        public static let failedToOpenKeyFile = NSLocalizedString(
            "[Database/Unlock/Error] Failed to open key file",
            bundle: Bundle.framework,
            value: "Failed to open key file",
            comment: "Error message")
        public static let cannotFindDatabaseFile = NSLocalizedString(
            "[Database/Load/Error] Cannot find database file",
            bundle: Bundle.framework,
            value: "Cannot find database file",
            comment: "Error message")
        public static let cannotFindKeyFile = NSLocalizedString(
            "[Database/Load/Error] Cannot find key file",
            bundle: Bundle.framework,
            value: "Cannot find key file",
            comment: "Error message")
        public static let cannotOpenDatabaseFile = NSLocalizedString(
            "[Database/Load/Error] Cannot open database file",
            bundle: Bundle.framework,
            value: "Cannot open database file",
            comment: "Error message")
        public static let cannotOpenKeyFile = NSLocalizedString(
            "[Database/Load/Error] Cannot open key file",
            bundle: Bundle.framework,
            value: "Cannot open key file",
            comment: "Error message")
        public static let unrecognizedDatabaseFormat = NSLocalizedString(
            "[Database/Load/Error] Unrecognized database format",
            bundle: Bundle.framework,
            value: "Unrecognized database format",
            comment: "Error message")
        public static let needPasswordOrKeyFile = NSLocalizedString(
            "[Database/Load/Error] Please provide at least a password or a key file",
            bundle: Bundle.framework,
            value: "Please provide at least a password or a key file",
            comment: "Error shown when both master password and key file are empty")
    }
    
    
    enum Warning {
        public static let fileIsInTrashTemplate = NSLocalizedString(
            "[File/In Trash/warning]",
            bundle: Bundle.framework,
            value: "'%@' is located in Recently Deleted and might be deleted soon. To preserve your data, move the file to a more permanent location.",
            comment: "Warning shown when opening files from Recycle Bin location. Translation of 'Recently Deleted' should match that in the Files app. [fileName: String]"
        )
        public static let temporaryBackupDatabase = NSLocalizedString(
            "[File/TemporaryBackup/warning]",
            bundle: Bundle.framework,
            value: "This is a temporary backup database. It can be automatically deleted without a warning. Don't use it as your main database.",
            comment: "Notification when user opens an in-app backup database.")
    }
    
    
    enum Progress {
        static let contactingStorageProvider = NSLocalizedString(
            "[Database/Progress/resolving]",
            bundle: Bundle.framework,
            value: "Contacting storage provider...",
            comment: "Progress status")
        static let loadingKeyFile = NSLocalizedString(
            "[Database/Progress] Loading key file...",
            bundle: Bundle.framework,
            value: "Loading key file...",
            comment: "Progress status")
        static let loadingDatabaseFile = NSLocalizedString(
            "[Database/Progress/downloading]",
            bundle: Bundle.framework,
            value: "Downloading database file...",
            comment: "Database loading status: fetching the database file from disk/cloud")
        static let makingDatabaseBackup = NSLocalizedString(
            "[Database/Progress/makingDatabaseBackup]",
            bundle: Bundle.framework,
            value: "Making backup copy...",
            comment: "Database saving status: making a local backup copy of the database")
        static let resolvingFieldReferences = NSLocalizedString(
            "[Database/Progress/resolvingFieldReferences]",
            bundle: Bundle.framework,
            value: "Resolving field references…",
            comment: "Database loading/saving status: replacing field references with their values")
        static let done = NSLocalizedString(
            "[Database/Progress] Done",
            bundle: Bundle.framework,
            value: "Done",
            comment: "Progress status: finished loading database")
        
        static let database1ParsingContent = NSLocalizedString(
            "[Database1/Progress] Parsing content",
            bundle: Bundle.framework,
            value: "Parsing content",
            comment: "Status message: processing the content of a database")
        static let database1PackingContent = NSLocalizedString(
            "[Database1/Progress] Packing the content",
            bundle: Bundle.framework,
            value: "Packing the content",
            comment: "Status message: collecting database items into a single package")
        
        static let database2LoadingDatabase = NSLocalizedString(
            "[Database2/Progress] Loading database",
            bundle: Bundle.framework,
            value: "Loading database",
            comment: "Progress bar status")
        static let database2DecompressingDatabase = NSLocalizedString(
            "[Database2/Progress/decompressing]",
            bundle: Bundle.framework,
            value: "Decompressing database",
            comment: "Progress bar status: un-zipping the database content")
        static let database2IntegrityCheck = NSLocalizedString(
            "[Database2/Progress/integrityCheck]",
            bundle: Bundle.framework,
            value: "Checking integrity",
            comment: "Progress bar status")
        static let database2ReadingContent = NSLocalizedString(
            "[Database2/Progress] Reading database content",
            bundle: Bundle.framework,
            value: "Reading database content",
            comment: "Progress bar status")
        static let database2ParsingXML = NSLocalizedString(
            "[Database2/Progress/parsingXML]",
            bundle: Bundle.framework,
            value: "Parsing database",
            comment: "Progress bar status: parsing decrypted XML content")
        static let database2WritingBlocks = NSLocalizedString(
            "[Database2/Progress] Writing encrypted blocks",
            bundle: Bundle.framework,
            value: "Writing encrypted blocks",
            comment: "Progress bar status")
    }
}
