#CHANGELOG

## [1.0.26] (Public Beta) - 2019-06-29

### Added 
- [Frequently asked questions](https://keepassium.com/faq)
- AutoFill setup instructions
- Option to lock the app not only immediately, but after a few seconds in background (closes #14) [thanks, J.B.]
- Option to automatically delete old backup copies (closes #12) [thanks, Dragonblitz10]
- Button in AutoFill to discard auto-suggestions and start manual search (closes #9) [thanks, Dragonblitz10]
- Option to copy OTP to clipboard when using AutoFill (closes #7) [thanks, Thunder33345]
- When long-pressing a file, suggest swiping instead [thanks, u/bananajoe]

### Changed
- "Remember master keys" option now defaults to "on" on first launch
- Manual search now checks the names of custom entry fields, even protected ones (related to #8)
- Moved backup setings to a separate page
- Refined the Settings screens

### Fixed
- Diagnostics viewer scrolls to bottom 
- Error message animation in Create Database dialog [thanks, Tobias]
- Regression: files are not syncronized (#10, #13) [thanks, Sunil and AndiB.]
- Database loading error 'Nil value in Entry/Times/ExpiryTime' in some cases [thanks, u/yacob841]


## [1.0.25] (Public Beta) - 2019-06-19

### Fixed

- Loading of Twofish-encrypted `kdbx` databases [thanks, Robin]
- Some files in Google Drive still appeared greyed-out [thanks, Edoardo]
- Crash when trying to delete something in an empty group
- Internal clean up after deleting the Recycle Bin group
- Possible crash when quickly switching between online databases


## [1.0.24] (Public Beta) - 2019-06-15

### Added
- This changelog [thanks, Quinton and u/vertigo9aa]

### Fixed
- Better handling of low memory conditions (#4) [thanks, Patrik]
- Parsing of timestamps across all locales (#5) [thanks, Marcel]
- Sometimes it was impossible to select databases from Google Drive [thanks, Edoardo]


## [1.0.23] (Public Beta) - 2019-06-03

### Fixed
- Database Lock now clears master keys of *all* the databases, not just the currently opened one
- In AutoFill, remembered key file was auto-picked for a database, even if the key file was not available (#1) [thanks, Patrik]
- AutoFill crash when reopening from an app (#2) [thanks, Patrik]
- Could not select Chinese keyboard in custom entry fields (#3) [thanks, Regulus]


## [1.0.22] (Public Beta) - 2019-05-22

### Fixed
- Timestamps shown in KeePassium were different from those shown in KeePass/KeePassXC [thanks, Marc]

### Changed
- Improved loading of databases with misformatted (empty-name) custom fields [thanks, Jorijn]


## [1.0.21] (Public Beta) - 2019-05-21

Published the source code and announced the public beta.

### Added
- Pull-to-refresh in database list actually updates timestamps [thanks, Kamal]

### Fixed
- Pressing Home when in AutoFill was considered an out-of-memory event.
- Database master key is cleared if unlocking is cancelled.


## [1.0.20] (Stealth Beta) - 2019-05-09

### Added
- Database creation feature (kdbx4 only)

### Changed
- Improved switching between databases. 
- "Remember master keys" option now works as expected: the master key remains in the keychain unless you press the Lock button in the toolbar.


## [1.0.19] (Stealth Beta) - 2019-04-23
### Fixed
- Possible corruption of Gzip-compressed databases [thanks, Marc]


## [1.0.18] (Closed Beta) - 2019-04-20 [WITHDRAWN]
Only made it to the closed beta group; was withdrawn on the same day due to reported database corruption [thanks, Marc!]

### Added
- Partial text selection in Notes and other multi-line fields.
- Longer clipboard timeouts [thanks, Marc]

### Changed
- To open a URL in an alternative browser, long-press the "Open URL" button
- Very long fields are now limited by height [thanks, Marc]
- TOTP codes are grouped for better readability [thanks, Qubing]

### Fixed
- It was impossible to add some cloud-based database from the Welcome screen [thanks, G Li and Alex]
- Refresh after deleting entries from search results [thanks, Norbert]
- Typo in clipboard timeouts [thanks, Marc and Alex]

### Removed
- Ability to drag-and-drop entry fields to another app on iPad (this conflicted with partial text selection)


## [1.0.17] (Stealth Beta) - 2019-03-16

### Changed
- Improved TOTP viewing

### Fixed
- Adding databases from OneDrive and probably other file providers [thanks everyone who reported this]
- Avoid protected/password fields during search [thanks, Tobias]
- Sorting of entries "Title Z-A" did not work [thanks, Marc]
- It was impossible to delete backup files [thanks, Tobias]
- Title capitalization in created entries [thanks, Marc]
- Potential crash-warning-crash loop in AutoFill with only one database


## [1.0.16] (Stealth Beta) - 2019-03-12

Started a stealth beta: published a TestFlight link on the landing page, without any announcements.

### Added
- View TOTP (time-based one-time passwords) created by KeePassXC (RFC6238 and Steam TOTP) 
- Graceful processing of out-of-memory warnings and AutoFill crashes [Tass]
- Button to forget all master keys
- Button to forget all key file associations

### Changed
- Rearranged settings across pages
- Moved "Remember master password" switch from DB unlocker to Settings
- Returned the big unlock button to DB unlocker
- Improved error panel layout (in DB unlockers)
- Improved some settings icons ("wrong appLock passcode" and "database protection")
- Minor visual improvements in Settings

### Fixed
- When navigating from a group with a visible search bar, the search field flickers in the next VC [thanks, Demian] — (but the bug remains for backward navigation)
- Clean up old data from keychain on first launch


## [1.0.15] (Closed Beta) - 2019-03-08
### Added
- Showing number of items in each group
- Possibility to add and remove attachments
- Showing a detailed warning when opening a problematic database 
- Remember last opened entry viewer tab

### Fixed
- Delay in updating operation progress
- Could create an entry in .kdb root group
- Could create items in deleted groups
- Deleting stuff from RecycleBin
- Editing of deleted items
- Database could not "be moved to trash because the volume does not have one" [thanks, Miles]
- Loading of .kdbx attachments with non-consecutive IDs [thanks, Daniel]
- Entry editor backed up the edited state, not the original.
- Preserve protection flag of kdbx4 attachments on save
- Entries in kdb were created with an empty attachment (as seen by KeePass)
- Could not open database with attachments after Strongbox [reported](https://github.com/mmcguill/Strongbox/issues/74)
- Entry viewer title did not change after editing


## [1.0.14] (Closed Beta) - 2019-02-24
### Added
- Similarity-based entry search in AutoFill

### Fixed
- RecycleBin groups are now created non-searchable


## [1.0.13] (Closed Beta) - 2019-02-23
### Fixed
- Regression: "File does not exist" when adding any file


## [1.0.12] (Closed Beta) - 2019-02-22
### Added
- SettingsMigrator to update settings format as the app evolves
- New setting: "Lock databases on failed AppLock passcode"

### Changed
- Improved names of biometrics-related settings

### Fixed
- AppLock did not re-trigger after the app is unlocked and minimized
- Face ID stuck in loop in AutoFill [thanks, Michael]
- Animation of AppLock/AppCover in main app and AutoFill
- On app launch, database list appeared briefly before the AppLock
- Re-importing the save database created numbered copies [thanks, Qubing]


## [1.0.11] (Closed Beta) - 2019-02-18
### Added
- Can choose keyboard type for AppLock passcode
- AppLock/Database Lock timeouts now account for app restarts [thanks, S.S.]
- Button to retry biometric auth in AppLock 

### Changed
- Default AppLock timeout: never -> immediately
- Improved AutoFill onboarding (explaining the need to re-add files)
- Improved font sizes in group viewer [thanks, Qubing]
- Improved feedback on failed master password [thanks, M.]
- Returned the unlock button to database unlock screens (main and AutoFill)

### Fixed
- Could not delete "Invalid file" databases
- Crash when long-pressing an entry field on iPad [thanks, M.]
- Could not select databases in Google Drive [thanks, BK]
- No biometric request in AppLock
- AppLock passcode field shifts up in AutoFill on iPad
- Occasional crashes when trying to show database icons


## [1.0.10] (Closed Beta) - 2018-12-22
### Fixed
- Could not open .kdbx using only key file [thanks, BK]


## [1.0.9] (Closed Beta) - 2018-12-22 
### Added
- GPL license file and headers
- "Clear" and "Contact Support" button to diagnostics viewer

### Fixed
- It was impossible to select key file with "Remember key files" disabled [thanks, BK]

## [1.0.8] (Closed Beta) - 2018-12-20
### Added
- File size field to File Info screen

### Fixed
- Some fixed colors get randomly deleted by Xcode
- Crash when locking database with stored master key [thanks, Josh and Nicolas]
- Problem adding .key files from iCloud to AutoFill [thanks, Nicolas]


## [1.0.7] (Closed Beta) - 2018-12-19
### Fixed
- Databases greyed out in document picker with StrongBox installed
- Sporadic crash in group.isRoot


## [1.0.6] (Closed Beta) - 2018-12-18
### Added
- AutoFill extension

### Changed
- Master keys are associated with databases by file name now, not full URL (to make the keys usable in AutoFill)

### Fixed
- <Enter> key behavior in  AppLock passcode screen


## [1.0.5] (Closed Beta) - 2018-12-07
### Fixed
- AutoFill build number did not match that of the main app.


## [1.0.4] (Closed Beta) - 2018-12-07 [WITHDRAWN]
(Build rejected by AppStore due to AutoFill build # mismatch; re-uploaded as beta 5)

### Added
- File Info viewer for databases and key files
- Password visibility button [thanks, Miles]
- Export of entry fields on long tap (can now open URLs in alternative browsers) [thanks, Miles]
- The long-overdue initial commit :)
- Unlocking databases using keychain-stored master keys
- AutoFill stub ("Under construction" screen)

### Changed
- Key files are now associated with databases by file name, not full URL [thanks, Miles]
 
### Fixed
- Problematic file timestamps
- Race conditions in DatabaseManager
- No need to enter the master password after closing the app [thanks, Andreas and Miles]
- Keyboard did not auto-show in app lock 
- Trouble opening kdbx4 files by KeePass Touch
- Some entry fields were copied as URLs


## [1.0.3] (Closed Beta) - 2018-11-08

### Changed
- Moved KeePass-specific code to a separate framework
- Entry viewer will not show empty standard fields
- Switched to thin blue UI icons

### Fixed
- Write correct database generator name in .kdbx
- Processing of nil/nil fields (sometimes produced by MiniKeePass) [thanks, Andreas]
- Wrong popover source when exporting database
- No back button from database unlocker on iPhone
- Password visibility button could be pushed off the screen [thanks, Nicolas]

## [1.0.2] (Closed Beta) - 2018-10-10

### Fixed
- Impossible unlock with FaceID - [stuck in infinite loop](https://forums.developer.apple.com/thread/91384)


## [1.0.1] (Closed Beta) - 2018-10-07

Started closed invite-only beta testing.