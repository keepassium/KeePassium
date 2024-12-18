//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length
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


    public static let titleHardwareKeys = NSLocalizedString(
        "[HardwareKey/Picker/title]",
        bundle: Bundle.framework,
        value: "Hardware Keys",
        comment: "Title of a list with possible hardware key connections")
    public static let hardwareKeyNotAvailableInAutoFill = NSLocalizedString(
        "[HardwareKey/AutoFill/NotAvailable] Hardware keys are not available in AutoFill.",
        bundle: Bundle.framework,
        value: "Hardware keys are not available in AutoFill.",
        comment: "A notification that hardware keys (e.g. YubiKey) cannot be used in AutoFill (the OS does not allow the AutoFill to use NFC/MFI).")
    public static let theseHardwareKeyNotAvailableInAutoFill = NSLocalizedString(
        "[HardwareKey/AutoFill/TheseNotAvailable]",
        bundle: Bundle.framework,
        value: "These hardware keys are not available in AutoFill.",
        comment: "Information notice for a list of hardware keys.")
    public static let usbUnavailableIPadAppOnMac = NSLocalizedString(
        "[HardwareKey/USB/iPadAppOnMac]",
        bundle: Bundle.framework,
        value: "USB is not available, because this is an iPad app running on macOS. Use the native Mac app instead.",
        comment: "Information notice")
    public static let usbHardwareKeyNotSupported = NSLocalizedString(
        "[HardwareKey/USB/chalRespNotSupported]",
        bundle: Bundle.framework,
        value: "This device does not support challenge-response over USB connection.",
        comment: "Information notice. 'Challenge-response' is a glossary term.")
    public static let hardwareKeyPortNFC = "NFC"
    public static let hardwareKeyPortUSB = "USB"
    public static let hardwareKeyPortLightning = "Lightning"
    public static let hardwareKeyPortLightningOverUSBC = NSLocalizedString(
        "[HardwareKey/Interface/LightningViaUSBAdapter]",
        bundle: Bundle.framework,
        value: "Lightning (via USB adapter)",
        comment: "Connector type for older Apple devices, used through a USB adapter. https://en.wikipedia.org/wiki/Lightning_(connector)")
    public static let hardwareKeyRequiresUSBtoLightningAdapter = NSLocalizedString(
        "[HardwareKey/LightningOverUSB/RequiresAdapter]",
        bundle: Bundle.framework,
        value: "Requires Apple USB-C to Lightning adapter",
        comment: "A notice for hardware keys that need an adapter for physical connection to device.")


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

    public static let titleIfFileUnreachableReAddFile = NSLocalizedString(
        "[Database/Settings/FallbackStrategy/ReAddFile/title]",
        bundle: Bundle.framework,
        value: "Re-add File",
        comment: "Title: what to do when a cloud-stored file cannot be loaded. (For example: `If File is Unreachable: Re-add File`.)")

    public static let titleIfDatabaseModifiedExternally = NSLocalizedString(
        "[Database/Settings/ExternalChanges/title]",
        bundle: Bundle.framework,
        value: "Database Modified Externally",
        comment: "File settings parameter: what to do when file was changed by another app/device. (For example: `Database Modified Externally: Notify`)")

    public static let titleIfDatabaseModifiedExternallyDontCheck = NSLocalizedString(
        "[Database/Settings/ExternalChanges/dontCheck]",
        bundle: Bundle.framework,
        value: "Don't check",
        comment: "File settings parameter: what to do when file was changed by another app/device. (For example: `Database Modified Externally: Don't check`)")

    public static let titleIfDatabaseModifiedExternallyNotify = NSLocalizedString(
        "[Database/Settings/ExternalChanges/notify]",
        bundle: Bundle.framework,
        value: "Notify",
        comment: "File settings parameter: what to do when file was changed by another app/device. (For example: `Database Modified Externally: Notify`)")

    public static let titleIfDatabaseModifiedExternallyReload = NSLocalizedString(
        "[Database/Settings/ExternalChanges/reload]",
        bundle: Bundle.framework,
        value: "Reload Automatically",
        comment: "File settings parameter: what to do when file was changed by another app/device. (For example: `Database Modified Externally: Reload Automatically`)")

    public static let actionChangeEncryptionSettings = NSLocalizedString(
        "[Database/EncryptionSettings/Change/action]",
        bundle: Bundle.framework,
        value: "Change Encryption Settings",
        comment: "Action to modify database encryption settings."
    )
    public static let titleEncryptionSettings = NSLocalizedString(
        "[Database/EncryptionSettings/title]",
        bundle: Bundle.framework,
        value: "Encryption Settings",
        comment: "Title: database encryption settings."
    )
    public static let encryptionSettingsDataCipher = NSLocalizedString(
        "[Database/EncryptionSettings/dataCipher]",
        bundle: Bundle.framework,
        value: "Encryption Algorithm",
        comment: "Parameter name in database encryption settings. Example: 'Encryption Algorithm: AES-256'"
    )
    public static let encryptionSettingsKDF = NSLocalizedString(
        "[Database/EncryptionSettings/kdf]",
        bundle: Bundle.framework,
        value: "Key Derivation Function",
        comment: "Parameter name in database encryption settings. This is a term, see https://en.wikipedia.org/wiki/Key_derivation_function. Example: 'Key Derivation Function: Argon2'"
    )
    public static let encryptionSettingsIterations = NSLocalizedString(
        "[Database/EncryptionSettings/iterations]",
        bundle: Bundle.framework,
        value: "Transform Rounds",
        comment: "Parameter name in database encryption settings. Defines the number of times/iterations a calculation (transform) should be executed. Example: 'Transform Rounds: 100'"
    )
    public static let encryptionSettingsMemory = NSLocalizedString(
        "[Database/EncryptionSettings/memory]",
        bundle: Bundle.framework,
        value: "Memory Usage",
        comment: "Parameter name in database encryption settings. Defines the amount of memory that should be used by an algorithm. Example: 'Memory Usage: 16 MB'"
    )
    public static let encryptionSettingsThreads = NSLocalizedString(
        "[Database/EncryptionSettings/threads]",
        bundle: Bundle.framework,
        value: "Parallelism",
        comment: "Parameter name in database encryption settings. Defines the number of computations to run in parallel/simultaneously. Example: 'Parallelism: 2 threads'"
    )
    public static let encryptionSettingsReset = NSLocalizedString(
        "[Database/EncryptionSettings/reset]",
        bundle: Bundle.framework,
        value: "Reset to Recommended Settings",
        comment: "Action/button button in database encryption settings. Resets the settings to recommended values."
    )
    public static let encryptionMemoryAutoFillWarning = NSLocalizedString(
        "[Database/EncryptionSettings/memoryAutoFillWarning]",
        bundle: Bundle.framework,
        value: "High memory requirements can make this database incompatible with Password AutoFill.",
        comment: "Warning for too high value of the `Memory usage` parameter in database encryption settings."
    )


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


    public static let titleSortItemsBy = NSLocalizedString(
        "[Menu/Sort] Sort Items By",
        bundle: Bundle.framework,
        value: "Sort Items By",
        comment: "Title of a menu: sort order of groups and entries in a list")

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
    public static let titleSortByNone = NSLocalizedString(
        "[SortBy/None]",
        bundle: Bundle.framework,
        value: "None",
        comment: "List sorting option, when no sorting is selected. Example: 'Sort by: None'")
    public static let titleSortOrderCustom = NSLocalizedString(
        "[SortOrder/Custom]",
        bundle: Bundle.framework,
        value: "Custom",
        comment: "List sorting option, when items are manually ordered by the user. Example: 'Sort order: Custom'")
    public static let titleSortByFileName = NSLocalizedString(
        "[SortBy/FileName]",
        bundle: Bundle.framework,
        value: "Name",
        comment: "List sorting option (for file names). Example: 'Sort by: Name'")
    public static let titleListSettings = NSLocalizedString(
        "[Settings/ListSettings/title]",
        bundle: Bundle.framework,
        value: "List Settings",
        comment: "Title of list view configuration screen")


    public static let titleGroupName = NSLocalizedString(
        "[GroupEditor/Name/placeholder]",
        bundle: Bundle.framework,
        value: "Group Name",
        comment: "Title of an input field for group name"
    )


    public static let actionChangeIcon = NSLocalizedString(
        "[EditEntry/Icon/change]",
        bundle: Bundle.framework,
        value: "Change Icon",
        comment: "Action: select a different icon for an item"
    )

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


    public static let titleDatabases = NSLocalizedString(
        "[Database/List/title]",
        bundle: Bundle.framework,
        value: "Databases",
        comment: "Title of the database picker list")
    public static let messageLocalFilesMissing = NSLocalizedString(
        "[Database/List/LocalMissing/message]",
        bundle: Bundle.framework,
        value: "If some local files are not listed, launch the main KeePassium app first.",
        comment: "Recommendation for solving a problem with a list of files.")
    public static let titleSortFilesBy = NSLocalizedString(
        "[Menu/Sort] Sort Files By",
        bundle: Bundle.framework,
        value: "Sort Files By",
        comment: "Title of a menu: sort order of files in a list")
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


    public static let titleDatabaseFormatVersionUpgrade = NSLocalizedString(
        "[Database/FormatVersion/Upgrade/title]",
        bundle: Bundle.framework,
        value: "Before we continue",
        comment: "Title of an info message when the app needs to change database file format.")
    public static let databaseFormatVersionUpgradeMessageTemplate = NSLocalizedString(
        "[Database/FormatVersion/Upgrade/text]",
        bundle: Bundle.framework,
        value: "KeePassium needs to upgrade your database file format (from %@ to %@). You might need to update other apps that use this database.",
        comment: "Info message when the app needs to change database file format. [oldFormat, newFormat: String]")
    public static let titleDatabaseFormatConversionAllDataPreserved = NSLocalizedString(
        "[Database/FormatVersion/Conversion/allDataPreserved]",
        bundle: Bundle.framework,
        value: "All your data will be preserved.",
        comment: "Info message when changing database file format.")
    public static let titleDatabaseFormatDoesNotSupportPasskeys = NSLocalizedString(
        "[Database/FormatVersion/PasskeysNotSupported]",
        bundle: Bundle.framework,
        value: "Current database format does not support passkeys.",
        comment: "Error message when creating a new passkey.")

    public static let titleUnsavedChanges = NSLocalizedString(
        "[Database/UnsavedChanges/title]",
        bundle: Bundle.framework,
        value: "Unsaved Changes",
        comment: "Title: there are temporary changes to be saved")
    public static let messageAutoFillCannotModify = NSLocalizedString(
        "[Database/UnsavedChanges/cannotModifyYet]",
        bundle: Bundle.framework,
        value: "Unfortunately, AutoFill cannot modify large databases yet. We are working to resolve this.",
        comment: "Notification message")
    public static let titleDatabaseHasUnsavedChanges = NSLocalizedString(
        "[Database/UnsavedChanges/thisDatabase]",
        bundle: Bundle.framework,
        value: "This database has unsaved changes made in AutoFill.",
        comment: "Notification message")
    public static let titleAutoFillCouldNotSaveChanges = NSLocalizedString(
        "[Database/UnsavedChanges/autoFillCrashed]",
        bundle: Bundle.framework,
        value: "AutoFill could not save some changes due to a technical limitation.",
        comment: "Notification message")
    public static let titleOpenAppToSaveChanges = NSLocalizedString(
        "[Database/UnsavedChanges/OpenAppCallToAction]",
        bundle: Bundle.framework,
        value: "To save changes, open the main KeePassium app.",
        comment: "Call to action shown in AutoFill module.")
    public static let titleSomeDatabasesHaveUnsavedChanges = NSLocalizedString(
        "[Database/UnsavedChanges/someDatabases]",
        bundle: Bundle.framework,
        value: "One or more databases have unsaved changes made in AutoFill.",
        comment: "Notification message")
    public static let actionSaveChanges = NSLocalizedString(
        "[Database/UnsavedChanges/saveAction]",
        bundle: Bundle.framework,
        value: "Save Changes",
        comment: "Action/button to save accummulated modifications")

    public static let statusItemEdited = NSLocalizedString(
        "[Database/Item/Edited/state]",
        bundle: Bundle.framework,
        value: "Edited",
        comment: "Status of a database item (entry or group) after it was edited.")

    public static let titleEntryPointsToDatabase = NSLocalizedString(
        "[Database/Entry/LinkedDatabase/message]",
        bundle: Bundle.framework,
        value: "This entry points to another database.",
        comment: "Info message for entries that contain information for opening a different database.")
}
// swiftlint:enable line_length
