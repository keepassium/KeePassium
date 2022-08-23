//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

extension LString {

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

    public static let titleMoreActions = NSLocalizedString(
        "[Generic] More Actions",
        bundle: Bundle.framework,
        value: "More Actions",
        comment: "Checkbox/Button to show additional actions"
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
    public static let actionLockDatabase = NSLocalizedString(
        "[Database/Opened/action] Lock Database",
        bundle: Bundle.framework,
        value: "Lock Database",
        comment: "Action/button to lock current database (the next time, it will ask for the master key)."
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

    public static let titleCreateDatabase = NSLocalizedString(
        "[Database/Create/title] Create Database",
        bundle: Bundle.framework,
        value: "Create Database",
        comment: "Title of a form for creating a database"
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
    public static let defaultNewGroupName = NSLocalizedString(
        "[Group/New/defaultName] New Group",
        bundle: Bundle.framework,
        value: "New Group",
        comment: "Default name of a new group"
    )
    public static let titleCreateGroup = NSLocalizedString(
        "[Group/Create/title] Create Group",
        bundle: Bundle.framework,
        value: "Create Group",
        comment: "Title of a form for creating a group"
    )
    public static let titleEditGroup = NSLocalizedString(
        "[Group/Edit/title] Edit Group",
        bundle: Bundle.framework,
        value: "Edit Group",
        comment: "Title of a form for editing a group"
    )
    public static let actionCreateEntry = NSLocalizedString(
        "[Entry/Create/action] Create Entry",
        bundle: Bundle.framework,
        value: "Create Entry",
        comment: "Action/button to create a new entry in the current group"
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
    public static let defaultNewPhotoAttachmentName = NSLocalizedString(
        "[Entry/Attachment/Photo/defaultName]",
        bundle: Bundle.framework,
        value: "Photo",
        comment: "Default name for a photo attachment"
    )

    public static let titleGroupDescriptionTemplate = NSLocalizedString(
        "[Group/a11y/description]",
        bundle: Bundle.framework,
        value: "%@, Group",
        comment: "VoiceOver description of a group [groupTitle: String, itemCount: Int]"
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
    public static let fieldURL      = NSLocalizedString(
        "[Entry/Field/name] URL",
        bundle: Bundle.framework,
        value: "URL",
        comment: "Name of an entry field"
    )
    public static let fieldNotes    = NSLocalizedString(
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

    public static let previousItemVersionRestored = NSLocalizedString(
        "[Item/History/Restored]",
        bundle: Bundle.framework,
        value: "Previous version restored",
        comment: "Notification that an archived/historical item (e.g entry) has been successfully restored"
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

    
    public static let otpSetupOTPAction = NSLocalizedString(
        "[OTP/Setup]",
        bundle: Bundle.framework,
        value: "Setup one-time password (OTP)",
        comment: "Call for action. Acronym `OTP` should not be translated."
    )

    public static let otpQRCodeNotValid = NSLocalizedString(
        "[OTP/Scan/InvalidData]",
        bundle: Bundle.framework,
        value: "This QR code is not suitable for OTP setup.",
        comment: "Error shown when scanned QR code cannot be used for OTP"
    )

    public static let otpQRCodeOverwriteWarning = NSLocalizedString(
        "[OTP/Scan/OverwriteWarning]",
        bundle: Bundle.framework,
        value: "One-time password is already configured for this entry. Do you want to overwrite it?",
        comment: "Message to confirm user intentions"
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

    public static let actionAddCustomIcon = NSLocalizedString(
        "[Database/CustomIcon/add]",
        bundle: Bundle.framework,
        value: "Add Custom Icon",
        comment: "Action: add/import an image as a custom icon"
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
    
    
    public static let copyrightNotice = NSLocalizedString(
        "[About/CopyrightAuthor]",
        bundle: Bundle.framework,
        value: "©Andrei Popleteev",
        comment: "Copyright notice")
}
