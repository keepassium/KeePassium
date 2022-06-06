//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension LString {
    
    public static let keyFileErrorTemplate = NSLocalizedString(
        "[Database/Unlock] Key file error: %@",
        bundle: Bundle.framework,
        value: "Key file error: %@",
        comment: "Error message related to key file. [errorDetails: String]")
    
    
    public static let titleSyncConflict = NSLocalizedString(
        "[Database/SyncConflict/title]",
        bundle: Bundle.framework,
        value: "Sync Conflict",
        comment: "Title of a message shown when saving to a database that has already been modified elsewhere."
    )
    public static let syncConflictMessage = NSLocalizedString(
        "[Database/SyncConflict/description]",
        bundle: Bundle.framework,
        value: "The database has changed since it was loaded in KeePassium.",
        comment: "Message shown in case of database sync conflict."
    )
    
    public static let syncConflictLoadedVersion = NSLocalizedString(
        "[Database/SyncConflict/loadedVersion]",
        bundle: Bundle.framework,
        value: "Loaded version",
        comment: "Title: the loaded (on-device) database version in case of sync conflict."
    )
    public static let syncConflictCurrentVersion = NSLocalizedString(
        "[Database/SyncConflict/currentVersion]",
        bundle: Bundle.framework,
        value: "Current version",
        comment: "Title: the current (on-server) database version in case of sync conflict."
    )
    
    public static let conflictResolutionOverwriteAction = LString.actionOverwrite
    public static let conflictResolutionOverwriteDescription = NSLocalizedString(
        "[Database/SyncConflict/Overwrite/description]",
        bundle: Bundle.framework,
        value: "Overwrite target file with the local version.",
        comment: "Explanation of the database sync conflict `Overwrite` option.")
    
    public static let conflictResolutionSaveAsAction = LString.actionFileSaveAs
    public static let conflictResolutionSaveAsDescription = NSLocalizedString(
        "[Database/SyncConflict/SaveAs/description]",
        bundle: Bundle.framework,
        value: "Save changes to another file.",
        comment: "Explanation of the database sync conflict `Save as` option.")

    public static let conflictResolutionMergeAction = NSLocalizedString(
        "[Database/SyncConflict/Merge/action]",
        bundle: Bundle.framework,
        value: "Merge",
        comment: "Action: combine changes in two conflicting databases.")
    public static let conflictResolutionMergeDescription = NSLocalizedString(
        "[Database/SyncConflict/Merge/description]",
        bundle: Bundle.framework,
        value: "Combine changes before saving.",
        comment: "Explanation of the database sync conflict `Merge` option.")
    
    public static let conflictResolutionCancelAction = LString.actionCancel
    public static let conflictResolutionCancelDescription = NSLocalizedString(
        "[Database/SyncConflict/Cancel/description]",
        bundle: Bundle.framework,
        value: "Cancel saving, leave target file intact.",
        comment: "Explanation of the database sync conflict `Cancel` option.")
    
    
    
    public static let hardwareKeyNotAvailableInAutoFill = NSLocalizedString(
        "[HardwareKey/AutoFill/NotAvailable] Hardware keys are not available in AutoFill.",
        bundle: Bundle.framework,
        value: "Hardware keys are not available in AutoFill.",
        comment: "A notification that hardware keys (e.g. YubiKey) cannot be used in AutoFill (the OS does not allow the AutoFill to use NFC/MFI).")
    public static let iOSVersionTooOldForHardwareKey = NSLocalizedString(
        "[HardwareKey/NFC/OS too old]",
        bundle: Bundle.framework,
        value: "NFC requires iOS 13 or later.",
        comment: "A notification that NFC (Near Field Communication) interface is not supported by the current iOS version.")
    
    
    public static let titleDatabaseSettings = NSLocalizedString(
        "[Database/Settings/title]",
        bundle: Bundle.framework,
        value: "Database Settings",
        comment: "Title of database-related settings screen"
    )
    
    public static let titleSettingsFileAccess = NSLocalizedString(
        "[Database/Settings/FileAccess/title]",
        bundle: Bundle.framework,
        value: "File Access",
        comment: "Title of settings section (read-only, backup-able, etc)"
    )

    public static let titleFileAccessReadOnly = NSLocalizedString(
        "[Database/Settings/ReadOnly/title]",
        bundle: Bundle.framework,
        value: "Read Only",
        comment: "File setting title, whether the file can be modified (yes/no).")
    
    public static let titleConsiderFileUnreachable = NSLocalizedString(
        "[Database/Settings/ConsiderFileUnreachable/title]",
        bundle: Bundle.framework,
        value: "Consider File Unreachable",
        comment: "File settings parameter: time after which file will be considered unreachable. Example: `Consider File Unreachable: in 10 seconds`.)")

    public static let titleIfFileIsUnreachable = NSLocalizedString(
        "[Database/Settings/FallbackStrategy/title]",
        bundle: Bundle.framework,
        value: "If File is Unreachable",
        comment: "File settings parameter: what to do when (remote) file cannot be loaded. (For example: `If File is Unreachable: Use Local Copy`.)")
    
    public static let titleIfFileUnreachableShowError = NSLocalizedString(
        "[Database/Settings/FallbackStrategy/ShowError/title]",
        bundle: Bundle.framework,
        value: "Show Error",
        comment: "Title: what to do when (remote) file cannot be loaded. (For example: `If File is Unreachable: Show Error`.)")
    
    public static let titleIfFileUnreachableUseCache = NSLocalizedString(
        "[Database/Settings/FallbackStrategy/UseCache/title]",
        bundle: Bundle.framework,
        value: "Use Local Copy",
        comment: "Title: what to do when (remote) file cannot be loaded. (For example: `If File is Unreachable: Use Local Copy`.)")

    
    
    public static let callToActionChooseDestinationGroup = NSLocalizedString(
        "[General/DestinationGroup/title] Choose a Destination",
        bundle: Bundle.framework,
        value: "Choose a Destination",
        comment: "Title of the dialog for picking the destination group for move/copy operations")
    public static let actionSwitchDatabase = NSLocalizedString(
        "[Database/Switch/action]",
        bundle: Bundle.framework,
        value: "Switch Database",
        comment: "Action/button to switch from current to some other database."
    )
    
    
    public static let titleEntrySubtitle = NSLocalizedString(
        "[Settings/GroupViewer] Entry Subtitle",
        bundle: Bundle.framework,
        value: "Entry Subtitle",
        comment: "Title of a settings section: which entry field to show along with entry title")
    public static let titleSortOrder = NSLocalizedString(
        "[Settings/GroupViewer] Sort Order",
        bundle: Bundle.framework,
        value: "Sort Order",
        comment: "Title of a settings section: sort order of groups and entries in a list")
    public static let titleListSettings = NSLocalizedString(
        "[Settings/ListSettings/title]",
        bundle: Bundle.framework,
        value: "List Settings",
        comment: "Title of list view configuration screen")
    
    
    public static let actionChooseUserName = NSLocalizedString(
        "[EditEntry/UserName/choose]",
        bundle: Bundle.framework,
        value: "Choose",
        comment: "Action: choose a username from a list"
    )

    
    public static let statusLoadingAttachmentFile = NSLocalizedString(
        "[Entry/Files/Add] Loading attachment file",
        bundle: Bundle.framework,
        value: "Loading attachment file",
        comment: "Status message: loading file to be attached to an entry")
    
    public static let itemCategoryDefault = NSLocalizedString(
        "[ItemCategory] Default (KeePass)",
        bundle: Bundle.framework,
        value: "Default (KeePass)",
        comment: "Name of an entry/group category (visual style): default one, like in KeePass"
    )
    
    public static let actionPreviewAttachments = NSLocalizedString(
        "[Entry/Attachments/preview]",
        bundle: Bundle.framework,
        value: "Preview",
        comment: "Action to preview one or several attached documents or images"
    )
    
    public static let titleEntryPreviousVersions = NSLocalizedString(
        "[Entry/History] Previous Versions",
        bundle: Bundle.framework,
        value: "Previous Versions",
        comment: "Title of a list with previous versions/revisions of an entry.")
    
    
    public static let titleShowBackupFiles = NSLocalizedString(
        "Show Backup Files",
        bundle: Bundle.framework,
        value: "Show Backup Files",
        comment: "Settings switch: whether to include backup copies in the file list"
    )
    public static let titleNoDatabaseFiles = NSLocalizedString(
        "No database files",
        bundle: Bundle.framework,
        value: "No database files",
        comment: "Placeholder shown when there are no database files available")

    
    public static let databaseLastEditedByTemplate = NSLocalizedString(
        "[Database/Opened/Warning/lastEdited] Database was last edited by: %@",
        bundle: Bundle.framework,
        value: "Database was last edited by: %@",
        comment: "Status message: name of the app that was last to write/create the database file. [lastUsedAppName: String]")
    public static let titleDatabaseLoadingWarning = NSLocalizedString(
        "[Database/Opened/Warning/title] Your database is ready, but there was an issue.",
        bundle: Bundle.framework,
        value: "Your database is ready, but there was an issue.",
        comment: "Title of a warning message, shown after opening a problematic database")
    public static let actionIgnoreAndContinue = NSLocalizedString(
        "[Database/Opened/Warning/action] Ignore and Continue",
        bundle: Bundle.framework,
        value: "Ignore and Continue",
        comment: "Action: ignore warnings and proceed to work with the database")
    public static let actionCloseDatabase = NSLocalizedString(
        "[Database/Opened/Warning/action] Close Database",
        bundle: Bundle.framework,
        value: "Close Database",
        comment: "Action: lock database")
}
