//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length

extension LString {

    public static let entriesSelectedCountTemplate = NSLocalizedString(
        "[Generic/Count/EntriesSelected]",
        bundle: Bundle.framework,
        comment: "Number of entries selected. For example: 'No entries selected', '1 entry selected'. IMPORTANT: Please fill out all the plural forms."
    )
    public static let itemsSelectedCountTemplate = NSLocalizedString(
          "[Generic/Count/ItemsSelected]",
          bundle: Bundle.framework,
          comment: "Number of list items selected. For example: 'No items selected', '1 entry selected'. IMPORTANT: Please fill out all the plural forms."
      )

    public static let bitCountTemplate = NSLocalizedString(
        "[Generic/Count/Bits]",
        bundle: Bundle.framework,
        comment: "Number of bits. For example: '123 bits of entropy'. IMPORTANT: Please fill out all the plural forms."
    )

    public static let threadCountTemplate = NSLocalizedString(
        "[Generic/Count/Threads]",
        bundle: Bundle.framework,
        comment: "Number of computation threads. For example: '4 threads'. IMPORTANT: Please fill out all the plural forms."
    )

    public static let actionOK = NSLocalizedString(
        "[Generic] OK",
        bundle: Bundle.framework,
        value: "OK",
        comment: "Action/button: generic OK"
    )
    public static let actionContinue = NSLocalizedString(
        "[Generic] Continue",
        bundle: Bundle.framework,
        value: "Continue",
        comment: "Action/button to proceed with the action"
    )
    public static let actionSkip = NSLocalizedString(
        "[Generic] Skip",
        bundle: Bundle.framework,
        value: "Skip",
        comment: "Action/button to skip the current step and proceed with the next one"
    )
    public static let actionCancel = NSLocalizedString(
        "[Generic] Cancel",
        bundle: Bundle.framework,
        value: "Cancel",
        comment: "Action/button to cancel whatever is going on"
    )
    public static let actionDismiss = NSLocalizedString(
        "[Generic] Dismiss",
        bundle: Bundle.framework,
        value: "Dismiss",
        comment: "Action/button to close an error message."
    )
    public static let actionDiscard = NSLocalizedString(
        "[Generic] Discard",
        bundle: Bundle.framework,
        value: "Discard",
        comment: "Action/button to discard any unsaved changes"
    )
    public static let actionRetry = NSLocalizedString(
        "[Generic] Retry",
        bundle: Bundle.framework,
        value: "Retry",
        comment: "Action: repeat the previous (failed) action"
    )
    public static let actionDelete = NSLocalizedString(
        "[Generic] Delete",
        bundle: Bundle.framework,
        value: "Delete",
        comment: "Action/button to delete an item (destroys the item/file)"
    )
    public static let actionDeleteAll = NSLocalizedString(
        "[Generic] Delete All",
        bundle: Bundle.framework,
        value: "Delete All",
        comment: "Action/button to delete all relevant/selected items"
    )
    public static let actionReplace = NSLocalizedString(
        "[Generic] Replace",
        bundle: Bundle.framework,
        value: "Replace",
        comment: "Action/button to replace an item with another one"
    )
    public static let actionEdit = NSLocalizedString(
        "[Generic] Edit",
        bundle: Bundle.framework,
        value: "Edit",
        comment: "Action/button to edit an item"
    )
    public static let actionRename = NSLocalizedString(
        "[Generic] Rename",
        bundle: Bundle.framework,
        value: "Rename",
        comment: "Action/button to rename an item"
    )
    public static let actionRestore = NSLocalizedString(
        "[Generic] Restore",
        bundle: Bundle.framework,
        value: "Restore",
        comment: "Action/button to restore a backup/archived item in its original place"
    )
    public static let actionOverwrite = NSLocalizedString(
        "[Generic] Overwrite",
        bundle: Bundle.framework,
        value: "Overwrite",
        comment: "Action/button to replace/overwrite an item"
    )
    public static let actionMove = NSLocalizedString(
        "[Generic] Move",
        bundle: Bundle.framework,
        value: "Move",
        comment: "Action/button to move an item (to another group/folder/etc)"
    )
    public static let actionCopy = NSLocalizedString(
        "[Generic] Copy",
        bundle: Bundle.framework,
        value: "Copy",
        comment: "Action/button to move an item (to another group/folder/etc)"
    )
    public static let actionDone = NSLocalizedString(
        "[Generic] Done",
        bundle: Bundle.framework,
        value: "Done",
        comment: "Action/button to finish (editing) and keep changes"
    )
    public static let actionCreate = NSLocalizedString(
        "[Generic] Create",
        bundle: Bundle.framework,
        value: "Create",
        comment: "Action/button to create an item (entry, group, file — depending on context)"
    )
    public static let actionSelect = NSLocalizedString(
        "[Generic/Action/SelectItems]",
        bundle: Bundle.framework,
        value: "Select",
        comment: "Action/button to select some items in a list."
    )
    public static let actionReorderItems = NSLocalizedString(
        "[Generic/Action/ReorderItems]",
        bundle: Bundle.framework,
        value: "Reorder",
        comment: "Action/button to change the order of items in a list (move them higher/lower)."
    )

    public static let actionFileSaveAs = NSLocalizedString(
        "[Generic/File/Save as]",
        bundle: Bundle.framework,
        value: "Save as…",
        comment: "Action/button to save data to a different file"
    )
    public static let actionShowMore = NSLocalizedString(
        "[Generic] Show more",
        bundle: Bundle.framework,
        value: "Show more",
        comment: "Checkbox/Button to show a text field in its full size"
    )
    public static let actionOpenURL = NSLocalizedString(
        "[Generic] Open URL",
        bundle: Bundle.framework,
        value: "Open URL",
        comment: "Action/button to open URL in the appropriate app (usually, web browser)"
    )
    public static let actionShare = NSLocalizedString(
        "[Generic] Share",
        bundle: Bundle.framework,
        value: "Share",
        comment: "Action/button to share an item with another app (AirDrop, send an email, etc)"
    )
    public static let actionShowDetails = NSLocalizedString(
        "[Generic] Show Details",
        bundle: Bundle.framework,
        value: "Show Details",
        comment: "Action/button to show additional information about an error or item"
    )
    public static let actionShowInPlainText = NSLocalizedString(
        "[Generic] Show In Plain Text",
        bundle: Bundle.framework,
        value: "Show In Plain Text",
        comment: "Action/button to show sensitive info as it is, in plain text (as opposed to asterisks)"
    )
    public static let actionExport = NSLocalizedString(
        "[Generic] Export",
        bundle: Bundle.framework,
        value: "Export",
        comment: "Action/button to export an item to another app"
    )
    public static let actionRefreshList = NSLocalizedString(
        "[Generic/RefreshList/action]",
        bundle: Bundle.framework,
        value: "Refresh List",
        comment: "Action: refresh list of items, usually files"
    )
    public static let actionPrint = NSLocalizedString(
        "[Generic] Print",
        bundle: Bundle.framework,
        value: "Print",
        comment: "Action/button to print a document"
    )
    public static let actionRevealInFinder = NSLocalizedString(
        "[Generic] Reveal in Finder",
        bundle: Bundle.framework,
        value: "Reveal in Finder",
        comment: "Action/button to open Finder (macOS file manager) and highlight a given file"
    )
    public static let actionContactUs = NSLocalizedString(
        "[Generic] Contact Us",
        bundle: Bundle.framework,
        value: "Contact Us",
        comment: "Action/button to write an email to support"
    )
    public static let actionContactSupport = NSLocalizedString(
        "[Generic] Contact Support",
        bundle: Bundle.framework,
        value: "Contact Support",
        comment: "Action/button to write an email to support"
    )
    public static let actionLearnMore = NSLocalizedString(
        "[Generic] Learn more",
        bundle: Bundle.framework,
        value: "Learn more…",
        comment: "Action/button to view more help/info about some topic"
    )
    public static let actionViewHelpArticle = NSLocalizedString(
        "[Generic/ViewHelpArticle/action]",
        bundle: Bundle.framework,
        value: "View help article",
        comment: "Action/button to open an online support article (about a specific error)"
    )
    public static let actionFixThis = NSLocalizedString(
        "[Generic] Fix this",
        bundle: Bundle.framework,
        value: "Fix this",
        comment: "Action/button shown below error messages. Tapping the button will start the fixing/repairing workflow described in the error message."
    )

    public static let actionDeleteFile = NSLocalizedString(
        "[Generic/File] Delete",
        bundle: Bundle.framework,
        value: "Delete",
        comment: "Action/button to delete a file (destroys the file forever)"
    )
    public static let actionRemoveFile = NSLocalizedString(
        "[Generic/File] Remove",
        bundle: Bundle.framework,
        value: "Remove",
        comment: "Action/button to remove a file from the app (the file remains, but the app forgets about it)"
    )
    public static let actionUpgradeToPremium = NSLocalizedString(
        "[Premium/Upgrade/action] Upgrade to Premium",
        bundle: Bundle.framework,
        value: "Upgrade to Premium",
        comment: "Action/button to start choosing premium versions and possibly buying one")

    public static let titleTools = NSLocalizedString(
        "[Generic/Tools/title]",
        bundle: Bundle.framework,
        value: "Tools",
        comment: "Title of a menu with various utilities"
    )
    public static let titleMoreActions = NSLocalizedString(
        "[Generic] More Actions",
        bundle: Bundle.framework,
        value: "More Actions",
        comment: "Checkbox/Button to show additional actions"
    )
    public static let titleViewOptions = NSLocalizedString(
        "[Generic/ViewOptions/title]",
        bundle: Bundle.framework,
        value: "View Options",
        comment: "Title of a screen/list view configuration: sort order, visible items, etc"
    )
    public static let titlePresets = NSLocalizedString(
        "[Generic/Presets]",
        bundle: Bundle.framework,
        value: "Presets",
        comment: "Title of a list with predefined quick-choice values (for example: 'Presets: 1 week, 1 months, 1 year')"
    )

    public static let statusFeatureOn = NSLocalizedString(
        "[General/Feature/On]",
        bundle: Bundle.framework,
        value: "On",
        comment: "Feature status: enabled/active. Keep it short, possibly abbreviated.")
    public static let statusFeatureOff = NSLocalizedString(
        "[General/Feature/Off]",
        bundle: Bundle.framework,
        value: "Off",
        comment: "Feature status: disabled/inactive. Keep it short, possibly abbreviated.")

    public static let titleError = NSLocalizedString(
        "[Generic/title] Error",
        bundle: Bundle.framework,
        value: "Error",
        comment: "Title of an error message notification"
    )
    public static let titleWarning = NSLocalizedString(
        "[Generic/title] Warning",
        bundle: Bundle.framework,
        value: "Warning",
        comment: "Title of an warning message"
    )
    public static let titleSearch = NSLocalizedString(
        "[Generic/Search/title]",
        bundle: Bundle.framework,
        value: "Search",
        comment: "Title of a search field (a noun, not verb)"
    )
    public static let titleFileExport = NSLocalizedString(
        "[Generic/File/Export/title]",
        bundle: Bundle.framework,
        value: "File Export",
        comment: "Title of a generic file export screen."
    )
    public static let titleFileImportError = NSLocalizedString(
        "[Generic/File/title] Import Error",
        bundle: Bundle.framework,
        value: "Import Error",
        comment: "Title of an error message about file import"
    )
    public static let titleKeychainError = NSLocalizedString(
        "[Generic/title] Keychain Error",
        bundle: Bundle.framework,
        value: "Keychain Error",
        comment: "Title of an error message about iOS system keychain"
    )
    public static let titleFileExportError = NSLocalizedString(
        "[Generic/File/title] Export Error",
        bundle: Bundle.framework,
        value: "Export Error",
        comment: "Title of an error message about file export"
    )
    public static let dontUseDatabaseAsKeyFile = NSLocalizedString(
        "KeePass database should not be used as key file. Please pick a different file.",
        bundle: Bundle.framework,
        comment: "Warning message when the user tries to use a database as a key file"
    )
    public static let tryToReAddFile = NSLocalizedString(
        "[File/PermissionDenied] Try to remove the file from the app, then add it again.",
        bundle: Bundle.framework,
        value: "Try to remove the file from the app, then add it again.",
        comment: "A suggestion shown after specific file errors (either databases or key files)."
    )
    public static let actionReAddFile = NSLocalizedString(
        "[File/Re-add/title]",
        bundle: Bundle.framework,
        value: "Add the file again",
        comment: "Action: re-add (a broken) database or key file to the app."
    )
    public static let fileAlreadyExists = NSLocalizedString(
        "[Generic/File/title] File already exists",
        bundle: Bundle.framework,
        value: "File already exists",
        comment: "Message shown when trying to copy into an existing file."
    )


    public static let actionUnlock = NSLocalizedString(
        "[AppLock] Unlock",
        bundle: Bundle.framework,
        value: "Unlock",
        comment: "Action/button to unlock the App Lock with passcode"
    )
    public static let actionChangePasscode = NSLocalizedString(
        "[AppLock/changePasscode]",
        bundle: Bundle.framework,
        value: "Change Passcode",
        comment: "Action/button to modify the existing AppLock passcode."
    )
    public static let titleNewPasscodeSaved = NSLocalizedString(
        "[AppLock/passcodeUpdated/title]",
        bundle: Bundle.framework,
        value: "Passcode updated successfully.",
        comment: "Notification that the modified AppLock passcode has been saved."
    )
    public static let actionSavePasscode = NSLocalizedString(
        "[AppLock/savePasscode]",
        bundle: Bundle.framework,
        value: "Save Passcode",
        comment: "Action/button to save new or edited AppLock passcode."
    )
    public static let titleSetupAppPasscode = NSLocalizedString(
        "[AppLock/SetupPasscode/callToAction]",
        bundle: Bundle.framework,
        value: "Protect KeePassium from unauthorized access",
        comment: "Call to action in the passcode input dialog."
    )
    public static let titleUnlockTheApp = NSLocalizedString(
        "[AppLock/EnterPasscode/callToAction]",
        bundle: Bundle.framework,
        value: "Unlock KeePassium",
        comment: "Call to action in the passcode input dialog."
    )

    public static let actionCopyToClipboardTemplate = NSLocalizedString(
        "[Clipboard/Copy/namedValue]",
        bundle: Bundle.framework,
        value: "Copy %@",
        comment: "Action copy some named value to clipboard. For example: `Copy Password`. [valueName: String]"
    )
    public static let titleCopiedToClipboard = NSLocalizedString(
        "[Clipboard/Copy/notification]",
        bundle: Bundle.framework,
        value: "Copied",
        comment: "Notification: an item has been copied to clipboard"
    )

    public static let hintDoubleTapToCopyToClipboard = NSLocalizedString(
        "[Accessibility] Double tap to copy to clipboard",
        bundle: Bundle.framework,
        value: "Double tap to copy to clipboard",
        comment: "Suggestion/hint for available user action"
    )

    public static let fieldRepeatPassword = NSLocalizedString(
        "[Repeat Password/Field/title]",
        bundle: Bundle.framework,
        value: "Repeat Password",
        comment: "Name of an input field for entering the password again"
    )
    public static let fieldKeyFile = NSLocalizedString(
        "[KeyFile/Field/title]",
        bundle: Bundle.framework,
        value: "Key File",
        comment: "Name of an input field which shows selected key file"
    )
    public static let fieldHardwareKey = NSLocalizedString(
        "[HardwareKey/Field/title]",
        bundle: Bundle.framework,
        value: "Hardware Key",
        comment: "Name of an input field which shows selected hardware key"
    )
    public static let forgotPasswordQuestion = NSLocalizedString(
        "[Database/Unlock/wrongPassword/question]",
        bundle: Bundle.framework,
        value: "Forgot your password?",
        comment: "Message shown when user enters an invalid database password"
    )

    public static let databaseStatusLoading = NSLocalizedString(
        "[Database/Loading/Status] Loading...",
        bundle: Bundle.framework,
        value: "Loading...",
        comment: "Status message: loading a database"
    )
    public static let databaseStatusSaving = NSLocalizedString(
        "[Database/Saving/Status] Saving...",
        bundle: Bundle.framework,
        value: "Saving...",
        comment: "Status message: saving a database"
    )
    public static let databaseStatusSavingDone = NSLocalizedString(
        "[Database/Saving/Status] Done",
        bundle: Bundle.framework,
        value: "Done",
        comment: "Status message: finished saving a database"
    )
    public static let databaseIsReadOnly = NSLocalizedString(
        "[Database/Loading/ReadOnly/text]",
        bundle: Bundle.framework,
        value: "The database is read-only",
        comment: "Message shown if current database cannot be edited"
    )
    public static let databaseIsFallbackCopy = NSLocalizedString(
        "[Database/Loading/FromCache/text]",
        bundle: Bundle.framework,
        value: "The database is unreachable.\nThis is its latest local copy.",
        comment: "Message shown after we show a cached local database instead of the (unavailable) original database."
    )
    public static let databaseStatusPreparingPrintPreview = NSLocalizedString(
        "[Database/Print/preparingPreview]",
        bundle: Bundle.framework,
        value: "Preparing preview…",
        comment: "Status message: preparing database print preview."
    )

    public static let messageUnsavedChanges = NSLocalizedString(
        "[Generic/Edit/Aborting/title] There are unsaved changes",
        bundle: Bundle.framework,
        value: "There are unsaved changes",
        comment: "Title of a notification when the user tries to close a document with unsaved changes"
    )
    public static let confirmKeyFileDeletion = NSLocalizedString(
        "[KeyFile/Delete/Confirm/text] Delete key file?\n Make sure you have a backup.",
        bundle: Bundle.framework,
        value: "Delete key file?\n Make sure you have a backup.",
        comment: "Message to confirm deletion of a key file."
    )
    public static let confirmKeyFileRemoval = NSLocalizedString(
        "[KeyFile/Remove/Confirm/text] Remove key file from the list?\n The file will remain intact and you can add it again later.",
        bundle: Bundle.framework,
        value: "Remove key file from the list?\n The file will remain intact and you can add it again later.",
        comment: "Message to confirm removal of a key file from the app. (This keeps the file, but removes its reference from the app.)"
    )
    public static let confirmDatabaseDeletion = NSLocalizedString(
        "[Database/Delete/Confirm/text] Delete database file?\n Make sure you have a backup.",
        bundle: Bundle.framework,
        value: "Delete database file?\n Make sure you have a backup.",
        comment: "Message to confirm deletion of a database file. (This deletes the file itself)"
    )
    public static let confirmDatabaseRemoval = NSLocalizedString(
        "[Database/Remove/Confirm/text] Remove database from the list?\n The file will remain intact and you can add it again later.",
        bundle: Bundle.framework,
        value: "Remove database from the list?\n The file will remain intact and you can add it again later.",
        comment: "Message to confirm removal of database file from the app. (This keeps the file, but removes its reference from the app.)"
    )

    public static let titleDatabaseOperations = NSLocalizedString(
        "[Database/Operations/title]",
        bundle: Bundle.framework,
        value: "Database Operations",
        comment: "Title of a list with database-related actions (e.g. lock database, change master key, etc)"
    )
    public static let actionLockDatabase = NSLocalizedString(
        "[Database/Opened/action] Lock Database",
        bundle: Bundle.framework,
        value: "Lock Database",
        comment: "Action/button to lock current database (the next time, it will ask for the master key)."
    )
    public static let titlePlainTextDatabaseExport = NSLocalizedString(
        "[Database/Export/PlainText/warning]",
        bundle: Bundle.framework,
        value: "The exported file will contain your data in plaintext, without any protection.",
        comment: "Notification message before database export."
    )

    public static let actionChangeMasterKey = NSLocalizedString(
        "[Database/MasterKey/Change/action]",
        bundle: Bundle.framework,
        value: "Change Master Key",
        comment: "Action/button: change master key of a database."
    )
    public static let titleRememberYourPassword = NSLocalizedString(
        "[Database/MasterKey/RememberYourPassword/title]",
        bundle: Bundle.framework,
        value: "Remember your database password",
        comment: "Imperative/recommendation: title of a warning when changing database password."
    )
    public static let warningRememberYourPassword = NSLocalizedString(
        "[Database/MasterKey/RememberYourPassword/text]",
        bundle: Bundle.framework,
        value: "If you ever forget it, you won't be able to access your data. There is no password reset option.",
        comment: "A warning shown when changing database password. Is preceded with `Remember your database password`."
    )
    public static let warningNonDatabaseExtension = NSLocalizedString(
        "[Database/Add] Selected file \"%@\" does not look like a database.",
        bundle: Bundle.framework,
        value: "Selected file \"%@\" does not look like a database.",
        comment: "Warning when trying to add a random file as a database. [fileName: String]")

    public static let actionCreateGroup = NSLocalizedString(
        "[Group/Create/action] Create Group",
        bundle: Bundle.framework,
        value: "Create Group",
        comment: "Action/button to create a new sub-group in the current group"
    )
    public static let actionCreateSmartGroup = NSLocalizedString(
        "[Group/Smart/Create/action]",
        bundle: Bundle.framework,
        value: "Create Smart Group",
        comment: "Action/button to create a new Smart Group"
    )
    public static let defaultNewGroupName = NSLocalizedString(
        "[Group/New/defaultName] New Group",
        bundle: Bundle.framework,
        value: "New Group",
        comment: "Default name of a new group"
    )
    public static let defaultNewSmartGroupName = NSLocalizedString(
        "[Group/Smart/New/defaultName]",
        bundle: Bundle.framework,
        value: "New Smart Group",
        comment: "Default name of a new smart group"
    )
    public static let titleGroup = NSLocalizedString(
        "[Group/title]",
        bundle: Bundle.framework,
        value: "Group",
        comment: "Glossary term: noun, a group in database."
    )
    public static let titleSmartGroup = NSLocalizedString(
        "[Group/Smart/title]",
        bundle: Bundle.framework,
        value: "Smart Group",
        comment: "Glossary term: noun, a smart group in database."
    )
    public static let titleNewGroup = defaultNewGroupName
    public static let titleNewSmartGroup = defaultNewSmartGroupName
    public static let titleEditGroup = NSLocalizedString(
        "[Group/Edit/title] Edit Group",
        bundle: Bundle.framework,
        value: "Edit Group",
        comment: "Title of a form for editing a group"
    )
    public static let actionEmptyRecycleBinGroup = NSLocalizedString(
        "[Group/RecycleBin/Empty/action]",
        bundle: Bundle.framework,
        value: "Empty Recycle Bin",
        comment: "Action/button to delete everything inside the Recycle Bin"
    )
    public static let confirmEmptyRecycleBinGroup = NSLocalizedString(
        "[Group/RecycleBin/Empty/confirmTitle]",
        bundle: Bundle.framework,
        value: "Permanently delete everything in the Recycle Bin?",
        comment: "Title of the confirmation dialog for `Empty Recycle Bin` action"
    )
    public static let titleGroupNotes = NSLocalizedString(
        "[Group/Notes/title]",
        bundle: Bundle.framework,
        value: "Notes",
        comment: "Title for the Notes field in group editor"
    )
    public static let titleSmartGroupQuery = NSLocalizedString(
        "[Group/Smart/Query/title]",
        bundle: Bundle.framework,
        value: "Smart Group Filter",
        comment: "Title for the Smart Group search conditions in group editor"
    )
    public static let titleAboutSmartGroups = NSLocalizedString(
        "[Group/Smart/about]",
        bundle: Bundle.framework,
        value: "About smart groups…",
        comment: "Action/button to show a help article"
    )
    public static let titleSmartGroupAllEntries = NSLocalizedString(
        "[Group/Smart/Preset/allEntries]",
        bundle: Bundle.framework,
        value: "All Entries",
        comment: "Title of a list: all entries in the database"
    )
    public static let titleSmartGroupOTPEntries = NSLocalizedString(
        "[Group/Smart/Preset/otpEntries]",
        bundle: Bundle.framework,
        value: "Entries with OTP",
        comment: "Title of a list: entries with one-time passwords (OTP)"
    )
    public static let titleSmartGroupPasskeyEntries = NSLocalizedString(
        "[Group/Smart/Preset/passkeyEntries]",
        bundle: Bundle.framework,
        value: "Entries with Passkeys",
        comment: "Title of a list: entries that contain passkeys"
    )
    public static let titleSmartGroupExpiredEntries = NSLocalizedString(
        "[Group/Smart/Preset/expiredEntries]",
        bundle: Bundle.framework,
        value: "Expired Entries",
        comment: "Title of a list: entries that are beyond their expiration date."
    )

    public static let actionCreateEntry = NSLocalizedString(
        "[Entry/Create/action] Create Entry",
        bundle: Bundle.framework,
        value: "Create Entry",
        comment: "Action/button to create a new entry in the current group"
    )
    public static let actionEditEntry = NSLocalizedString(
        "[Entry/Edit/action]",
        bundle: Bundle.framework,
        value: "Edit Entry",
        comment: "Action/button to modify an entry"
    )
    public static let actionAddAttachment = NSLocalizedString(
        "[Entry/Attachment/add]",
        bundle: Bundle.framework,
        value: "Add File",
        comment: "Action/button to add a file to entry attachments"
    )
    public static let actionChooseFile = NSLocalizedString(
        "[Entry/Attachment/chooseFile]",
        bundle: Bundle.framework,
        value: "Choose File",
        comment: "Action/button to pick a file from a list"
    )
    public static let actionChoosePhoto = NSLocalizedString(
        "[Entry/Attachment/choosePhoto]",
        bundle: Bundle.framework,
        value: "Choose Photo",
        comment: "Action/button to select an (existing) photo from Photo Library"
    )
    public static let actionTakePhoto = NSLocalizedString(
        "[Entry/Attachment/takePhoto]",
        bundle: Bundle.framework,
        value: "Take Photo",
        comment: "Action/button to take a new photo from camera"
    )
    public static let actionCopyFieldReference = NSLocalizedString(
        "[Entry/Field/CopyReference/action]",
        bundle: Bundle.framework,
        value: "Copy Field Reference",
        comment: "Action: copy a reference to the selected entry field to clipboard"
    )
    public static let fieldReferenceCopiedToClipboard = NSLocalizedString(
        "[Entry/Field/CopyReference/acknowledgement]",
        bundle: Bundle.framework,
        value: "Field reference copied to clipboard",
        comment: "Notification: a reference to an entry field has been copied to clipboard"
    )
    public static let actionShowTextInLargeType = NSLocalizedString(
        "[Entry/Field/LargeType/action]",
        bundle: Bundle.framework,
        value: "Show in Large Type",
        comment: "Action: display text using large font"
    )
    public static let titleEntry = NSLocalizedString(
        "[Entry/title]",
        bundle: Bundle.framework,
        value: "Entry",
        comment: "Glossary term: noun, an entry in database."
    )
    public static let titleNewEntry = defaultNewEntryName
    public static let defaultNewEntryName = NSLocalizedString(
        "[Entry/New/defaultTitle] New Entry",
        bundle: Bundle.framework,
        value: "New Entry",
        comment: "Default title of a new entry"
    )
    public static let defaultNewCustomFieldName = NSLocalizedString(
        "[Entry/Edit/CreateField/defaultName] Field Name",
        bundle: Bundle.framework,
        value: "Field Name",
        comment: "Default name of a newly created entry field"
    )
    public static let titleProtectedField = NSLocalizedString(
        "[Entry/Field/Protected/title]",
        bundle: Bundle.framework,
        value: "Protected Field",
        comment: "Title of a setting: whether the entry's field is protected (shown as asterisks)."
    )
    public static let defaultNewPhotoAttachmentName = NSLocalizedString(
        "[Entry/Attachment/Photo/defaultName]",
        bundle: Bundle.framework,
        value: "Photo",
        comment: "Default name for a photo attachment"
    )

    public static let titleGroupMenu = NSLocalizedString(
        "[Group/Menu/a11y/title]",
        bundle: Bundle.framework,
        value: "Group Menu",
        comment: "VoiceOver description of a menu with group-related actions"
    )
    public static let titleGroupDescriptionTemplate = NSLocalizedString(
        "[Group/a11y/description]",
        bundle: Bundle.framework,
        value: "%@, Group",
        comment: "VoiceOver description of a group [groupTitle: String, itemCount: Int]"
    )
    public static let titleSmartGroupDescriptionTemplate = NSLocalizedString(
        "[Group/Smart/a11y/description]",
        bundle: Bundle.framework,
        value: "%@, Smart group",
        comment: "VoiceOver description of a smart group [groupTitle: String]"
    )

    public static let sectionGroups = NSLocalizedString(
        "[Group/Section/Groups/title]",
        bundle: Bundle.framework,
        value: "Groups",
        comment: "Title of the Groups section visible while editing"
    )
    public static let sectionEntries = NSLocalizedString(
        "[Group/Section/Entries/title]",
        bundle: Bundle.framework,
        value: "Entries",
        comment: "Title of the Entries section visible while editing"
    )

    public static let fieldIcon = NSLocalizedString(
        "[Entry/Field/name] Icon",
        bundle: Bundle.framework,
        value: "Icon",
        comment: "Name of an entry field"
    )
    public static let fieldTitle = NSLocalizedString(
        "[Entry/Field/name] Title",
        bundle: Bundle.framework,
        value: "Title",
        comment: "Name of an entry field"
    )
    public static let fieldUserName = NSLocalizedString(
        "[Entry/Field/name] User Name",
        bundle: Bundle.framework,
        value: "User Name",
        comment: "Name of an entry field"
    )
    public static let fieldPassword = NSLocalizedString(
        "[Entry/Field/name] Password",
        bundle: Bundle.framework,
        value: "Password",
        comment: "Name of an entry field"
    )
    public static let fieldPasskey = NSLocalizedString(
        "[Entry/Field/name] Passkey",
        bundle: Bundle.framework,
        value: "Passkey",
        comment: "Title of an entry field"
    )
    public static let fieldURL = NSLocalizedString(
        "[Entry/Field/name] URL",
        bundle: Bundle.framework,
        value: "URL",
        comment: "Name of an entry field"
    )
    public static let fieldNotes = NSLocalizedString(
        "[Entry/Field/name] Notes",
        bundle: Bundle.framework,
        value: "Notes",
        comment: "Name of an entry field"
    )
    public static let fieldOTP = NSLocalizedString(
        "[OTP/FieldName]",
        bundle: Bundle.framework,
        value: "One-Time Password",
        comment: "Name of an entry field"
    )
    public static let fieldTOTP = NSLocalizedString(
        "[TOTP/FieldName]",
        bundle: Bundle.framework,
        value: "One-Time Password (TOTP)",
        comment: "Name of an entry field. Acronym `TOTP` should not be translated."
    )
    public static let fieldHOTP = NSLocalizedString(
        "[HOTP/FieldName]",
        bundle: Bundle.framework,
        value: "One-Time Password (HOTP)",
        comment: "Name of an entry field. Acronym `HOTP` should not be translated."
    )
    public static let fieldTags = NSLocalizedString(
        "[Entry/Field/tags] Tags",
        bundle: Bundle.framework,
        value: "Tags",
        comment: "Name of an entry field"
    )
    public static let fieldUUID = "UUID"

    public static let previousItemVersionRestored = NSLocalizedString(
        "[Item/History/Restored]",
        bundle: Bundle.framework,
        value: "Previous version restored",
        comment: "Notification that an archived/historical item (e.g entry) has been successfully restored"
    )

    public static let titleItemProperties = NSLocalizedString(
        "[Item/Properties/title]",
        bundle: Bundle.framework,
        value: "Properties",
        comment: "Title of a list with item (e.g. entry) properties/settings, such as searchability, auto-typing, etc"
    )
    public static let titleItemAdvancedProperties = NSLocalizedString(
        "[Item/Properties/Advanced/title]",
        bundle: Bundle.framework,
        value: "Advanced",
        comment: "Title of a list with advanced/expert-level properties of a database item (e.g. entry)"
    )

    public static let titleItemPropertyPasswordAudit = NSLocalizedString(
        "[Item/Properties/PasswordAudit/title]",
        bundle: Bundle.framework,
        value: "Password Audit",
        comment: "Title of a setting: whether the item (e.g. entry) should be included in password audit"
    )
    public static let itemPasswordAuditAllowed = NSLocalizedString(
        "[Item/Properties/PasswordAudit/allowed]",
        bundle: Bundle.framework,
        value: "Allowed",
        comment: "Possible value of the `Password Audit` setting. For example: 'Password Audit: Allowed'"
    )
    public static let itemPasswordAuditDisabled = NSLocalizedString(
        "[Item/Properties/PasswordAudit/disabled]",
        bundle: Bundle.framework,
        value: "Disabled",
        comment: "Possible value of the `Password Audit` setting. For example: 'Password Audit: Disabled'"
    )

    public static let titleItemPropertyAutoFill = NSLocalizedString(
        "[Item/Properties/AutoFill/title]",
        bundle: Bundle.framework,
        value: "Password AutoFill",
        comment: "Title of a setting: whether the item (e.g. entry) should be used in AutoFill feature"
    )
    public static let titleItemPropertyAutoFillKeePassXC = NSLocalizedString(
        "[Item/Properties/AutoFill/KeePassXC/title]",
        bundle: Bundle.framework,
        value: "Password AutoFill (KeePassXC)",
        comment: "Title of a setting: whether the item (e.g. entry) should be used in AutoFill feature. App-specific setting for KeePassXC."
    )
    public static let itemAutoFillAllowed = NSLocalizedString(
        "[Item/Properties/AutoFill/allowed]",
        bundle: Bundle.framework,
        value: "Allowed",
        comment: "Possible value of the `Password AutoFill` setting. For example: 'Password AutoFill: Allowed'"
    )
    public static let itemAutoFillDisabled = NSLocalizedString(
        "[Item/Properties/AutoFill/disabled]",
        bundle: Bundle.framework,
        value: "Disabled",
        comment: "Possible value of the `Password AutoFill` setting. For example: 'Password AutoFill: Disabled'"
    )

    public static let titleItemPropertySearch = NSLocalizedString(
        "[Item/Properties/Search/title] Search",
        bundle: Bundle.framework,
        value: "Search",
        comment: "Title of a setting: whether the item (e.g. entry) should be considered during search. Example: 'Search: Allowed'"
    )
    public static let itemSearchAllowed = NSLocalizedString(
        "[Item/Properties/Search/allowed]",
        bundle: Bundle.framework,
        value: "Allowed",
        comment: "Possible value of the `Search` setting. Example: 'Search: Allowed'"
    )
    public static let itemSearchDisabled = NSLocalizedString(
        "[Item/Properties/Search/disabled]",
        bundle: Bundle.framework,
        value: "Disabled",
        comment: "Possible value of the `Search` setting, when the item should be excluded from search results. Example: 'Search: Disabled'"
    )
    public static let itemPropertyInheritedTemplate = NSLocalizedString(
        "[Item/Properties/inheritedValue]",
        bundle: Bundle.framework,
        value: "Inherit from parent group (%@)",
        comment: "Default value of an item property. For example: 'Password Audit: Inherit from parent group (Allowed)'. [inheritedValue: String]"
    )


    public static let expiryDateNever = NSLocalizedString(
        "[Entry/History/ExpiryDate] Never",
        bundle: Bundle.framework,
        value: "Never",
        comment: "Expiry Date of an entry which does not expire.")
    public static let itemExpiryDate = NSLocalizedString(
        "[Entry/History] Expiry Date",
        bundle: Bundle.framework,
        value: "Expiry Date",
        comment: "Title of a field with date and time when the entry will no longer be valid. 'Never' is also a possible value")
    public static let itemCreationDate = NSLocalizedString(
        "[Entry/History] Creation Date",
        bundle: Bundle.framework,
        value: "Creation Date",
        comment: "Title of a field with entry creation date and time")
    public static let itemLastModificationDate = NSLocalizedString(
        "[Entry/History] Last Modification Date",
        bundle: Bundle.framework,
        value: "Last Modification Date",
        comment: "Title of a field with entry's last modification date and time")
    public static let itemModificationDate = NSLocalizedString(
        "[Entry/History] Modification Date",
        bundle: Bundle.framework,
        value: "Modification Date",
        comment: "Title of a field with entry's modification date and time")
    public static let itemLastAccessDate = NSLocalizedString(
        "[Entry/History] Last Access Date",
        bundle: Bundle.framework,
        value: "Last Access Date",
        comment: "Title of a field with date and time when the entry was last accessed/viewed")



    public static let trashDirectoryName = NSLocalizedString(
        "[Generic/Directory/Recently Deleted/name]",
        bundle: Bundle.framework,
        value: "Recently Deleted",
        comment: "Name of the Recently Deleted (Recycle Bin) directory, as shown in the Files app"
    )
    public static let titleExcludeFromBackup = NSLocalizedString(
        "[FileInfo/isExcludedFromBackup/title]",
        bundle: Bundle.framework,
        value: "Exclude From iCloud/iTunes Backup",
        comment: "Title of a setting: is the file exluded from iCloud/iTunes backup. For example: `Exclude From Backup: <Yes>`"
    )
    public static let titleFileBackupSettings = NSLocalizedString(
        "[FileInfo/Backup/header]",
        bundle: Bundle.framework,
        value: "Backup",
        comment: "Section header: file backup settings"
    )
    public static let titleFileAttributes = NSLocalizedString(
        "[FileInfo/Attributes/header]",
        bundle: Bundle.framework,
        value: "File Attributes",
        comment: "Section header for attributes of a file (e.g. hidden, excluded from backup, etc)"
    )
    public static let titleHiddenFileAttribute = NSLocalizedString(
        "[FileInfo/Attributes/Hidden/title]",
        bundle: Bundle.framework,
        value: "Hidden",
        comment: "Title of a setting: is the file hidden"
    )
    public static let descriptionHiddenFileAttribute = NSLocalizedString(
        "[FileInfo/Attributes/Hidden/warning]",
        bundle: Bundle.framework,
        value: "Hidden files are less visible to a casual user, but don't improve data security.",
        comment: "Warning message for 'hidden' files."
    )
    public static let errorFailedToChangeFileAttributes = NSLocalizedString(
        "[FileInfo/Error/failed to change attributes]",
        bundle: Bundle.framework,
        value: "Failed to update file attributes.",
        comment: "Error message shown when the user tries to change file attributes (such as creation/modification date, backup flag, etc)"
    )


    public static let titleHelpViewer = NSLocalizedString(
        "[Help Viewer/title]",
        bundle: Bundle.framework,
        value: "Help",
        comment: "Generic title of in-app help article")

    public static let titleNewDatabase = NSLocalizedString(
        "[Database/New/title]",
        bundle: Bundle.framework,
        value: "New Database",
        comment: "Title of database creation dialog")
    public static let actionCreateDatabase = NSLocalizedString(
        "[Database/Create/action] Create Database",
        bundle: Bundle.framework,
        value: "Create Database",
        comment: "Action/button to create a new database")
    public static let actionOpenDatabase = NSLocalizedString(
        "[Database/Open/action] Open Database",
        bundle: Bundle.framework,
        value: "Open Database",
        comment: "Action/button")
    public static let actionReloadDatabase = NSLocalizedString(
        "[Database/Reload/action]",
        bundle: Bundle.framework,
        value: "Reload Database",
        comment: "Action/button")
    public static let actionSaveDatabase = NSLocalizedString(
        "[Database/Save/action] Save Database",
        bundle: Bundle.framework,
        value: "Save Database",
        comment: "Action/button to save the current database.")
    public static let actionSaveToServer = NSLocalizedString(
        "[Database/SaveToServer/action]",
        bundle: Bundle.framework,
        value: "Save To Server",
        comment: "Action/button to save file to a remote server.")
    public static let tryRemoteConnection = NSLocalizedString(
        "[Database/RecommendRemote/callToAction]",
        bundle: Bundle.framework,
        value: "Try connecting to your remote storage directly from KeePassium.",
        comment: "Suggested solution/call to action when intermediate sync app fails.")

    public static let titleMasterKey = NSLocalizedString(
        "[Database/MasterKey/title]",
        bundle: Bundle.framework,
        value: "Master Key",
        comment: "Glossary term: noun, a master key for encrypting the database")
    public static let masterKeySuccessfullyChanged = NSLocalizedString(
        "[Database/MasterKey/changed] Master key successfully changed",
        bundle: Bundle.framework,
        value: "Master key successfully changed",
        comment: "Notification after changing database master key")

    public static let emailTemplateDescribeTheProblemHere = NSLocalizedString(
        "[Support/template] (Please describe the problem here)",
        bundle: Bundle.framework,
        value: "(Please describe the problem here)",
        comment: "Template text of a bug report email")

    public static let defaultKeyFileName = NSLocalizedString(
        "[KeyFile/Create/defaultName]",
        bundle: Bundle.framework,
        value: "keyfile.dat",
        comment: "Default name for new key files. Should match the `key file` term in the glossary.")
    public static let importKeyFileAction = NSLocalizedString(
        "[KeyFile/Import/action]",
        bundle: Bundle.framework,
        value: "Import Key File",
        comment: "Action: import/add a key file into the app. `Key file` is a glossary term.")
    public static let importKeyFileDescription = NSLocalizedString(
        "[KeyFile/Import/actionDescription]",
        bundle: Bundle.framework,
        value: "Add file to the app",
        comment: "Description of the `Import Key File` action.")
    public static let useKeyFileAction = NSLocalizedString(
        "[KeyFile/Use/action]",
        bundle: Bundle.framework,
        value: "Select Key File",
        comment: "Action: use a key file at its storage location, without importing to the app.")
    public static let useKeyFileDescription = NSLocalizedString(
        "[KeyFile/Use/actionDescription]",
        bundle: Bundle.framework,
        value: "Use without adding",
        comment: "Description of the `Select Key File` action.")
    public static let actionCreateKeyFile = NSLocalizedString(
        "[KeyFile/Create/action]",
        bundle: Bundle.framework,
        value: "Create Key File",
        comment: "Action: create new key file.")

    public static let noHardwareKey = NSLocalizedString(
        "[HardwareKey/None] No Hardware Key",
        bundle: Bundle.framework,
        value: "No Hardware Key",
        comment: "Master key/unlock option: don't use hardware keys")
    public static let yubikeySlotNTemplate = NSLocalizedString(
        "[HardwareKey/YubiKey/Slot] YubiKey Slot #%d",
        bundle: Bundle.framework,
        value: "YubiKey Slot %d",
        comment: "Master key/unlock option: use given slot of YubiKey")

    public static let dontUseYubikey = NSLocalizedString(
        "[YubiKey] Don't use YubiKey",
        bundle: Bundle.framework,
        value: "Without YubiKey",
        comment: "Selector choice: don't use YubiKey to encrypt/decrypt database")

    public static let useYubikeySlotN = NSLocalizedString(
        "[YubiKey] Use YubiKey Slot %d",
        bundle: Bundle.framework,
        value: "Use YubiKey Slot %d",
        comment: "Selector choice: use YubiKey to encrypt/decrypt database. For example: `Use YubiKey Slot 1`. [slotID: Int]")

    public static let insertMFIYubikey = NSLocalizedString(
        "[YubiKey] Insert the key",
        bundle: Bundle.framework,
        value: "Insert the key",
        comment: "Call for action: insert YubiKey 5Ci to the Lightning port")

    public static let touchMFIYubikey = NSLocalizedString(
        "[YubiKey] Touch the key",
        bundle: Bundle.framework,
        value: "Touch the key",
        comment: "Call for action: touch the sides of YubiKey 5Ci to continue")


    public static let otpSetUpOTPAction = NSLocalizedString(
        "[OTP/Setup]",
        bundle: Bundle.framework,
        value: "Set up one-time password (OTP)",
        comment: "Call for action. Acronym `OTP` should not be translated."
    )
    public static let otpSetupScanQRCode = NSLocalizedString(
        "[OTP/Setup/ScanQRCode]",
        bundle: Bundle.framework,
        value: "Scan QR code",
        comment: "Button/action: proceed with QR code based OTP setup"
    )
    public static let otpSetupEnterManually = NSLocalizedString(
        "[OTP/Setup/EnterManually]",
        bundle: Bundle.framework,
        value: "Enter manually",
        comment: "Button/action: proceed with manual OTP setup"
    )

    public static let otpQRCodeNotValid = NSLocalizedString(
        "[OTP/Scan/InvalidData]",
        bundle: Bundle.framework,
        value: "This QR code is not suitable for OTP setup.",
        comment: "Error shown when scanned QR code cannot be used for OTP"
    )
    public static let otpInvalidSecretCode = NSLocalizedString(
        "[OTP/Scan/InvalidSecretCode]",
        bundle: Bundle.framework,
        value: "Entered secret code is not suitable for OTP setup.",
        comment: "Error shown when a manually entered OTP secret is misformatted."
    )

    public static let otpConfigOverwriteWarning = NSLocalizedString(
        "[OTP/Scan/OverwriteWarning]",
        bundle: Bundle.framework,
        value: "One-time password is already configured for this entry. Do you want to overwrite it?",
        comment: "Message to confirm user intentions"
    )

    public static let otpSecretCodePlaceholder = "abcd1234…" 
    public static let otpEnterSecretCodeTitle = NSLocalizedString(
        "[OTP/Setup/EnterSecretCode/callToAction]",
        bundle: Bundle.framework,
        value: "Enter Secret Code",
        comment: "Call to action: type in the secret key for OTP setup."
    )

    public static let otpCodeCopyToClipboardDemo = "Demo"
    public static let otpCodeCopiedToClipboard = NSLocalizedString(
        "[OTP/CopiedToClipboard/title]",
        bundle: Bundle.framework,
        value: "One-time password copied to clipboard",
        comment: "Notification next to the OTP code which was copied to clipboard"
    )
    public static let otpCodeHereItIs = NSLocalizedString(
        "[OTP/Title/sentenceCase]",
        bundle: Bundle.framework,
        value: "One-time password",
        comment: "Description of an OTP code; sentence case."
    )


    public static let itemIconPickerStandardIcons = NSLocalizedString(
        "[ItemIconPicker/StandardIcons]",
        bundle: Bundle.framework,
        value: "Standard Icons",
        comment: "Title of a list with standard/default icons for groups and entries"
    )

    public static let itemIconPickerCustomIcons = NSLocalizedString(
        "[ItemIconPicker/CustomIcons]",
        bundle: Bundle.framework,
        value: "Custom Icons",
        comment: "Title of a list with custom (user-imported) icons for groups and entries"
    )

    public static let titleUnusedIconsCountTemplate = NSLocalizedString(
        "[Database/CustomIcon/Unused/count]",
        bundle: Bundle.framework,
        value: "Unused icons found: %d",
        comment: "Notification when some custom icons are not used by any group or entry [iconCount: Int]"
    )

    public static let actionDeleteUnusedIcons = NSLocalizedString(
        "[Database/CustomIcon/deleteUnused]",
        bundle: Bundle.framework,
        value: "Delete Unused Icons",
        comment: "Action: delete unused icons"
    )

    public static let actionAddCustomIcon = NSLocalizedString(
        "[Database/CustomIcon/add]",
        bundle: Bundle.framework,
        value: "Add Custom Icon",
        comment: "Action: add/import an image as a custom icon"
    )
    public static let actionDownloadFavicon = NSLocalizedString(
        "[Database/CustomIcon/DownloadFavicon/action]",
        bundle: Bundle.framework,
        value: "Download Favicon",
        comment: "Action: download icon of a website"
    )
    public static let actionDownloadFavicons = NSLocalizedString(
        "[Database/CustomIcon/DownloadFavicons/action]",
        bundle: Bundle.framework,
        value: "Download Favicons",
        comment: "Action/button to download favicons of websites mentioned in selected entries."
    )
    public static let faviconUpdateStatsTemplate = NSLocalizedString(
        "[Database/CustomIcon/DownloadFavicons/stats]",
        bundle: Bundle.framework,
        value: "Entries processed: %d\nIcons updated: %d",
        comment: "Report of favicon download results."
    )
    public static let statusDownloadingOneFavicon = NSLocalizedString(
        "[Database/CustomIcon/DownloadOneFavicon/status]",
        bundle: Bundle.framework,
        value: "Downloading favicon",
        comment: "Status message: a website favicon is being downloaded"
    )
    public static let statusDownloadingFavicons = NSLocalizedString(
        "[Database/CustomIcon/DownloadFavicons/status]",
        bundle: Bundle.framework,
        value: "Downloading favicons",
        comment: "Status message: multiple website favicons are being downloaded"
    )


    public static let biometricsTypeTouchID = NSLocalizedString(
        "[BiometricAuthType] Touch ID",
        bundle: Bundle.framework,
        value: "Touch ID",
        comment: "Name of biometric authentication method. Trademarked, do not translate unless Apple traslated it to your language.")
    public static let biometricsTypeFaceID = NSLocalizedString(
        "[BiometricAuthType] Face ID",
        bundle: Bundle.framework,
        value: "Face ID",
        comment: "Name of biometric authentication method. Trademarked, do not translate unless Apple traslated it to your language.")


    public static let copyrightNotice = "©KeePassium Labs" 
    public static let previousCopyrightNotice = NSLocalizedString(
        "[About/CopyrightAuthor]",
        bundle: Bundle.framework,
        value: "©Andrei Popleteev",
        comment: "Copyright notice")

    public static let statusCheckingDatabaseForExternalChanges = NSLocalizedString(
        "[Database/ExternalChange/Status/checkInProgress]",
        bundle: Bundle.framework,
        value: "Checking for changes…",
        comment: "Status message: checking if currently loaded database is the latest version"
    )

    public static let statusDatabaseFileUpdateFailed = NSLocalizedString(
        "[Database/ExternalChange/Status/failed]",
        bundle: Bundle.framework,
        value: "Refresh failed",
        comment: "Status message: failed to check if currently loaded database is the latest version"
    )
    public static let statusDatabaseFileIsUpToDate = NSLocalizedString(
        "[Database/ExternalChange/Status/upToDate]",
        bundle: Bundle.framework,
        value: "Up to date",
        comment: "Status message: currently loaded database is the latest version"
    )

    public static let databaseChangedExternallyMessage = NSLocalizedString(
        "[Database/ExternalChange/notification]",
        bundle: Bundle.framework,
        value: "Database file has changed. Reload?",
        comment: "Notification message about external changes to the loaded file."
    )
}
// swiftlint:enable line_length
