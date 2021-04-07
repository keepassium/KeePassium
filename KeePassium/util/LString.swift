//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

public enum LString {

    public static let actionOK = NSLocalizedString(
        "[Generic] OK",
        value: "OK",
        comment: "Action/button: generic OK"
    )
    public static let actionContinue = NSLocalizedString(
        "[Generic] Continue",
        value: "Continue",
        comment: "Action/button to proceed with the action"
    )
    public static let actionCancel = NSLocalizedString(
        "[Generic] Cancel",
        value: "Cancel",
        comment: "Action/button to cancel whatever is going on"
    )
    public static let actionDismiss = NSLocalizedString(
        "[Generic] Dismiss",
        value: "Dismiss",
        comment: "Action/button to close an error message."
    )
    public static let actionDiscard = NSLocalizedString(
        "[Generic] Discard",
        value: "Discard",
        comment: "Action/button to discard any unsaved changes"
    )
    public static let actionDelete = NSLocalizedString(
        "[Generic] Delete",
        value: "Delete",
        comment: "Action/button to delete an item (destroys the item/file)"
    )
    public static let actionReplace = NSLocalizedString(
        "[Generic] Replace",
        value: "Replace",
        comment: "Action/button to replace an item with another one"
    )
    public static let actionEdit = NSLocalizedString(
        "[Generic] Edit",
        value: "Edit",
        comment: "Action/button to edit an item"
    )
    public static let actionRename = NSLocalizedString(
        "[Generic] Rename",
        value: "Rename",
        comment: "Action/button to rename an item"
    )
    public static let actionOverwrite = NSLocalizedString(
        "[Generic] Overwrite",
        value: "Overwrite",
        comment: "Action/button to replace/overwrite an item"
    )
    public static let actionMove = NSLocalizedString(
        "[Generic] Move",
        value: "Move",
        comment: "Action/button to move an item (to another group/folder/etc)"
    )
    public static let actionCopy = NSLocalizedString(
        "[Generic] Copy",
        value: "Copy",
        comment: "Action/button to move an item (to another group/folder/etc)"
    )
    public static let actionDone = NSLocalizedString(
        "[Generic] Done",
        value: "Done",
        comment: "Action/button to finish (editing) and keep changes"
    )
    public static let actionCreate = NSLocalizedString(
        "[Generic] Create",
        value: "Create",
        comment: "Action/button to create an item (entry, group, file — depending on context)"
    )
    public static let actionShowMore = NSLocalizedString(
        "[Generic] Show more",
        value: "Show more",
        comment: "Checkbox/Button to show a text field in its full size"
    )
    public static let actionOpenURL = NSLocalizedString(
        "[Generic] Open URL",
        value: "Open URL",
        comment: "Action/button to open URL in the appropriate app (usually, web browser)"
    )
    public static let actionShare = NSLocalizedString(
        "[Generic] Share",
        value: "Share",
        comment: "Action/button to share an item with another app (AirDrop, send an email, etc)"
    )
    public static let actionShowDetails = NSLocalizedString(
        "[Generic] Show Details",
        value: "Show Details",
        comment: "Action/button to show additional information about an error or item"
    )
    public static let actionShowInPlainText = NSLocalizedString(
        "[Generic] Show In Plain Text",
        value: "Show In Plain Text",
        comment: "Action/button to show sensitive info as it is, in plain text (as opposed to asterisks)"
    )
    public static let actionExport = NSLocalizedString(
        "[Generic] Export",
        value: "Export",
        comment: "Action/button to export an item to another app"
    )
    public static let actionContactUs = NSLocalizedString(
        "[Generic] Contact Us",
        value: "Contact Us",
        comment: "Action/button to write an email to support"
    )
    public static let actionContactSupport = NSLocalizedString(
        "[Generic] Contact Support",
        value: "Contact Support",
        comment: "Action/button to write an email to support"
    )
    public static let actionLearnMore = NSLocalizedString(
        "[Generic] Learn more",
        value: "Learn more…",
        comment: "Action/button to view more help/info about some topic"
    )
    
    public static let actionDeleteFile = NSLocalizedString(
        "[Generic/File] Delete",
        value: "Delete",
        comment: "Action/button to delete a file (destroys the file forever)"
    )
    public static let actionRemoveFile = NSLocalizedString(
        "[Generic/File] Remove",
        value: "Remove",
        comment: "Action/button to remove a file from the app (the file remains, but the app forgets about it)"
    )
    
    public static let actionUpgradeToPremium = NSLocalizedString(
        "[Premium/Upgrade/action] Upgrade to Premium",
        value: "Upgrade to Premium",
        comment: "Action/button to start choosing premium versions and possibly buying one")

    public static let titleMoreActions = NSLocalizedString(
        "[Generic] More Actions",
        value: "More Actions",
        comment: "Checkbox/Button to show additional actions"
    )

    public static let titleError = NSLocalizedString(
        "[Generic/title] Error",
        value: "Error",
        comment: "Title of an error message notification"
    )
    public static let titleWarning = NSLocalizedString(
        "[Generic/title] Warning",
        value: "Warning",
        comment: "Title of an warning message"
    )
    public static let titleFileImportError = NSLocalizedString(
        "[Generic/File/title] Import Error",
        value: "Import Error",
        comment: "Title of an error message about file import"
    )
    public static let titleKeychainError = NSLocalizedString(
        "[Generic/title] Keychain Error",
        value: "Keychain Error",
        comment: "Title of an error message about iOS system keychain"
    )
    public static let titleFileExportError = NSLocalizedString(
        "[Generic/File/title] Export Error",
        value: "Export Error",
        comment: "Title of an error message about file export"
    )
    public static let dontUseDatabaseAsKeyFile = NSLocalizedString(
        "KeePass database should not be used as key file. Please pick a different file.",
        comment: "Warning message when the user tries to use a database as a key file"
    )
    public static let tryToReAddFile = NSLocalizedString(
        "[File/PermissionDenied] Try to remove the file from the app, then add it again.",
        value: "Try to remove the file from the app, then add it again.",
        comment: "A suggestion shown after specific file errors (either databases or key files)."
    )
    public static let actionReAddFile = NSLocalizedString(
        "[File/Re-add/title]",
        value: "Add the file again",
        comment: "Action: re-add (a broken) database or key file to the app."
    )
    public static let fileAlreadyExists = NSLocalizedString(
        "[Generic/File/title] File already exists",
        value: "File already exists",
        comment: "Message shown when trying to copy into an existing file."
    )
    
    
    public static let actionUnlock = NSLocalizedString(
        "[AppLock] Unlock",
        value: "Unlock",
        comment: "Action/button to unlock the App Lock with passcode"
    )
    public static let actionUsePasscode = NSLocalizedString(
        "[AppLock/cancelBiometricAuth] Use Passcode",
        value: "Use Passcode",
        comment: "Action/button to switch from TouchID/FaceID prompt to manual input of the AppLock passcode."
    )
    public static let actionChangePasscode = NSLocalizedString(
        "[AppLock/changePasscode]",
        value: "Change Passcode",
        comment: "Action/button to modify the existing AppLock passcode."
    )
    public static let titleNewPasscodeSaved = NSLocalizedString(
        "[AppLock/passcodeUpdated/title]",
        value: "Passcode updated successfully.",
        comment: "Notification that the modified AppLock passcode has been saved."
    )
    public static let actionSavePasscode = NSLocalizedString(
        "[AppLock/savePasscode]",
        value: "Save Passcode",
        comment: "Action/button to save new or edited AppLock passcode."
    )
    public static let titleSetupAppPasscode = NSLocalizedString(
        "[AppLock/SetupPasscode/callToAction]",
        value: "Protect KeePassium from unauthorized access",
        comment: "Call to action in the passcode input dialog."
    )
    public static let titleUnlockTheApp = NSLocalizedString(
        "[AppLock/EnterPasscode/callToAction]",
        value: "Unlock KeePassium",
        comment: "Call to action in the passcode input dialog."
    )
    
    public static let actionCopyToClipboardTemplate = NSLocalizedString(
        "[Clipboard/Copy/namedValue]",
        value: "Copy %@",
        comment: "Action copy some named value to clipboard. For example: `Copy Password`. [valueName: String]"
    )
    public static let titleCopiedToClipboard = NSLocalizedString(
        "[Clipboard/Copy/notification]",
        value: "Copied",
        comment: "Notification: an item has been copied to clipboard"
    )

    public static let hintDoubleTapToCopyToClipboard = NSLocalizedString(
        "[Accessibility] Double tap to copy to clipboard",
        value: "Double tap to copy to clipboard",
        comment: "Suggestion/hint for available user action"
    )

    public static let databaseStatusLoading = NSLocalizedString(
        "[Database/Loading/Status] Loading...",
        value: "Loading...",
        comment: "Status message: loading a database"
    )
    public static let databaseStatusSaving = NSLocalizedString(
        "[Database/Saving/Status] Saving...",
        value: "Saving...",
        comment: "Status message: saving a database"
    )
    public static let databaseStatusSavingDone = NSLocalizedString(
        "[Database/Saving/Status] Done",
        value: "Done",
        comment: "Status message: finished saving a database"
    )
    public static let actionCloseDatabase = NSLocalizedString(
        "[Database/Opened/action] Close",
        value: "Close",
        comment: "Action/button to close current database (for example, when leaving the root group). NOTE: closing does not necessarily lock the database."
    )
    public static let actionLockDatabase = NSLocalizedString(
        "[Database/Opened/action] Lock Database",
        value: "Lock Database",
        comment: "Action/button to lock current database (the next time, it will ask for the master key)."
    )

    
    public static let messageUnsavedChanges = NSLocalizedString(
        "[Generic/Edit/Aborting/title] There are unsaved changes",
        value: "There are unsaved changes",
        comment: "Title of a notification when the user tries to close a document with unsaved changes"
    )
    public static let confirmKeyFileDeletion = NSLocalizedString(
        "[KeyFile/Delete/Confirm/text] Delete key file?\n Make sure you have a backup.",
        value: "Delete key file?\n Make sure you have a backup.",
        comment: "Message to confirm deletion of a key file."
    )
    public static let confirmKeyFileRemoval = NSLocalizedString(
        "[KeyFile/Remove/Confirm/text] Remove key file from the list?\n The file will remain intact and you can add it again later.",
        value: "Remove key file from the list?\n The file will remain intact and you can add it again later.",
        comment: "Message to confirm removal of a key file from the app. (This keeps the file, but removes its reference from the app.)"
    )
    public static let confirmDatabaseDeletion = NSLocalizedString(
        "[Database/Delete/Confirm/text] Delete database file?\n Make sure you have a backup.",
        value: "Delete database file?\n Make sure you have a backup.",
        comment: "Message to confirm deletion of a database file. (This deletes the file itself)"
    )
    public static let confirmDatabaseRemoval = NSLocalizedString(
        "[Database/Remove/Confirm/text] Remove database from the list?\n The file will remain intact and you can add it again later.",
        value: "Remove database from the list?\n The file will remain intact and you can add it again later.",
        comment: "Message to confirm removal of database file from the app. (This keeps the file, but removes its reference from the app.)"
    )

    public static let titleCreateDatabase = NSLocalizedString(
        "[Database/Create/title] Create Database",
        value: "Create Database",
        comment: "Title of a form for creating a database"
    )
    public static let titleRememberYourPassword = NSLocalizedString(
        "[Database/MasterKey/RememberYourPassword/title]",
        value: "Remember your database password",
        comment: "Imperative/recommendation: title of a warning when changing database password."
    )
    public static let warningRememberYourPassword = NSLocalizedString(
        "[Database/MasterKey/RememberYourPassword/text]",
        value: "If you ever forget it, you won't be able to access your data. There is no password reset option.",
        comment: "A warning shown when changing database password. Is preceded with `Remember your database password`."
    )
    public static let warningNonDatabaseExtension = NSLocalizedString(
        "[Database/Add] Selected file \"%@\" does not look like a database.",
        value: "Selected file \"%@\" does not look like a database.",
        comment: "Warning when trying to add a random file as a database. [fileName: String]")
    
    public static let actionCreateGroup = NSLocalizedString(
        "[Group/Create/action] Create Group",
        value: "Create Group",
        comment: "Action/button to create a new sub-group in the current group"
    )
    public static let defaultNewGroupName = NSLocalizedString(
        "[Group/New/defaultName] New Group",
        value: "New Group",
        comment: "Default name of a new group"
    )
    public static let titleCreateGroup = NSLocalizedString(
        "[Group/Create/title] Create Group",
        value: "Create Group",
        comment: "Title of a form for creating a group"
    )
    public static let titleEditGroup = NSLocalizedString(
        "[Group/Edit/title] Edit Group",
        value: "Edit Group",
        comment: "Title of a form for editing a group"
    )
    public static let actionCreateEntry = NSLocalizedString(
        "[Entry/Create/action] Create Entry",
        value: "Create Entry",
        comment: "Action/button to create a new entry in the current group"
    )
    public static let defaultNewEntryName = NSLocalizedString(
        "[Entry/New/defaultTitle] New Entry",
        value: "New Entry",
        comment: "Default title of a new entry"
    )
    public static let defaultNewCustomFieldName = NSLocalizedString(
        "[Entry/Edit/CreateField/defaultName] Field Name",
        value: "Field Name",
        comment: "Default name of a newly created entry field")
    
    public static let titleGroupDescriptionTemplate = NSLocalizedString(
        "[Group/a11y/description]",
        value: "%@, Group",
        comment: "VoiceOver description of a group [groupTitle: String, itemCount: Int]"
    )
    
    public static let fieldTitle = NSLocalizedString(
        "[Entry/Field/name] Title",
        value: "Title",
        comment: "Name of an entry field"
    )
    public static let fieldUserName = NSLocalizedString(
        "[Entry/Field/name] User Name",
        value: "User Name",
        comment: "Name of an entry field"
    )
    public static let fieldPassword = NSLocalizedString(
        "[Entry/Field/name] Password",
        value: "Password",
        comment: "Name of an entry field"
    )
    public static let fieldURL      = NSLocalizedString(
        "[Entry/Field/name] URL",
        value: "URL",
        comment: "Name of an entry field"
    )
    public static let fieldNotes    = NSLocalizedString(
        "[Entry/Field/name] Notes",
        value: "Notes",
        comment: "Name of an entry field"
    )

    
    
    public static let trashDirectoryName = NSLocalizedString(
        "[Generic/Directory/Recently Deleted/name]",
        value: "Recently Deleted",
        comment: "Name of the Recently Deleted (Recycle Bin) directory, as shown in the Files app"
    )
    public static let titleExcludeFromBackup = NSLocalizedString(
        "[FileInfo/isExcludedFromBackup/title]",
        value: "Exclude From iCloud/iTunes Backup",
        comment: "Title of a setting: is the file exluded from iCloud/iTunes backup. For example: `Exclude From Backup: <Yes>`"
    )
    public static let titleBackupSettings = NSLocalizedString(
        "[FileInfo/Backup/header]",
        value: "Backup",
        comment: "Section header: file backup settings"
    )

    public static let errorFailedToChangeFileAttributes = NSLocalizedString(
        "[FileInfo/Error/failed to change attributes]",
        value: "Failed to update file attributes.",
        comment: "Error message shown when the user tries to change file attributes (such as creation/modification date, backup flag, etc)"
    )
    

    public static let titleHelpViewer = NSLocalizedString(
        "[Help Viewer/title]",
        value: "Help",
        comment: "Generic title of in-app help article")
    
    public static let titleTouchID  = NSLocalizedString(
        "[AppLock/Biometric/Hint] Unlock KeePassium",
        value: "Unlock KeePassium",
        comment: "Hint/Description why the user is asked to provide their fingerprint. Shown in the standard Touch ID prompt.")
    
    public static let actionCreateDatabase = NSLocalizedString(
        "[Database/Create/action] Create Database",
        value: "Create Database",
        comment: "Action/button to create a new database")
    public static let actionOpenDatabase = NSLocalizedString(
        "[Database/Open/action] Open Database",
        value: "Open Database",
        comment: "Action/button")

    public static let masterKeySuccessfullyChanged = NSLocalizedString(
        "[Database/MasterKey/changed] Master key successfully changed",
        value: "Master key successfully changed",
        comment: "Notification after changing database master key")
    
    public static let emailTemplateDescribeTheProblemHere = NSLocalizedString(
        "[Support/template] (Please describe the problem here)",
        value: "(Please describe the problem here)",
        comment: "Template text of a bug report email")
    
    
    public static let dontUseYubikey = NSLocalizedString(
        "[YubiKey] Don't use YubiKey",
        value: "Without YubiKey",
        comment: "Selector choice: don't use YubiKey to encrypt/decrypt database")
    
    public static let useYubikeySlotN = NSLocalizedString(
        "[YubiKey] Use YubiKey Slot %d",
        value: "Use YubiKey Slot %d",
        comment: "Selector choice: use YubiKey to encrypt/decrypt database. For example: `Use YubiKey Slot 1`. [slotID: Int]")

    public static let insertMFIYubikey = NSLocalizedString(
        "[YubiKey] Insert the key",
        value: "Insert the key",
        comment: "Call for action: insert YubiKey 5Ci to the Lightning port")

    public static let touchMFIYubikey = NSLocalizedString(
        "[YubiKey] Touch the key",
        value: "Touch the key",
        comment: "Call for action: touch the sides of YubiKey 5Ci to continue")

    
    public static let otpSetupOTPAction = NSLocalizedString(
        "[OTP/Setup]",
        value: "Setup one-time password (OTP)",
        comment: "Call for action. Acronym `OTP` should not be translated."
    )

    public static let otpQRCodeNotValid = NSLocalizedString(
        "[OTP/Scan/InvalidData]",
        value: "This QR code is not suitable for OTP setup.",
        comment: "Error shown when scanned QR code cannot be used for OTP"
    )

    public static let otpQRCodeOverwriteWarning = NSLocalizedString(
        "[OTP/Scan/OverwriteWarning]",
        value: "One-time password is already configured for this entry. Do you want to overwrite it?",
        comment: "Message to confirm user intentions"
    )

    
    public static let itemIconPickerStandardIcons = NSLocalizedString(
        "[ItemIconPicker/StandardIcons]",
        value: "Standard Icons",
        comment: "Title of a list with standard/default icons for groups and entries"
    )

    public static let itemIconPickerCustomIcons = NSLocalizedString(
        "[ItemIconPicker/CustomIcons]",
        value: "Custom Icons",
        comment: "Title of a list with custom (user-imported) icons for groups and entries"
    )

    public static let actionAddCustomIcon = NSLocalizedString(
        "[Database/CustomIcon/add]",
        value: "Add Custom Icon",
        comment: "Action: add/import an image as a custom icon"
    )
    
    public static func directionAwareConcatenate(_ parts: [String]) -> String {
        if UIApplication.shared.userInterfaceLayoutDirection == .rightToLeft {
            return parts.reversed().joined()
        }
        return parts.joined()
    }
}
