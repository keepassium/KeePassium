#CHANGELOG

## [1.36.116] - 2022-09-03

### Added

- macOS: Added support for USB YubiKeys (native MacCatalys builds only)
- Ability to copy references to entry fields (tap the field to see the copy button) [thanks, u/RandomComputerFellow]

### Improved

- Added a button to delete custom entry fields [thanks, YJ]
- Display full Pro app name on the Home screen
- Minor UI improvements focused on macOS
- Updated all translations

### Fixed

- macOS: too frequent Touch ID popups. Now one needs to click a "Touch ID unlock" button first [thanks, everyone]


## [1.36.115] - 2022-08-09

### Added

- Added "Allow Network Access" setting (off by default)
- Added in-app support for WebDAV sync (Nextcloud, Synology, etc) [thanks, everyone]

### Improved

- Added a 48-hour database timeout [thanks, BM]

### Fixed

- On devices restored from a backup, DB loading froze at 60% [thanks, everyone]
- "Save as" on sync conflict could overwrite the original
- Reset keychain when memory protection key disappears
- macOS: Erase app settings after reinstallation [thanks, everyone]
- Fixed loading DBs with several nameless attachments [thanks, u/mindhaq]


## [1.35.114] - 2022-06-22

### Changed

- Attachment previews are no longer restricted in free version
- Database timeout "Never" is shown as a free option (worked as such even before)
- Instead, the app will suggest donating once in a while
- Password generator: fixed sets can be deactivated instead of excluded [thanks, Fabian]
- AutoFill: context menu of the Cancel button will show the diagnostic log
- Updated all translations

### Fixed

- macOS: sensitive data will not show up in Keychain Access app anymore
- Extended diagnostics for AutoFill not showing local DBs [thanks, Dennis]
- Minor UI fixes here and there


## [1.34.113] - 2022-06-02

### Added

- Random generator is now available in context menus in entry/group editor (#155) [thanks, everyone]
- Quick popup with random passwords in database picker (#155) [thanks, everyone]

### Fixed

- AutoFill could not access some local files (regression in 1.32.110) [thanks, Chris]


## [1.34.112] - 2022-05-29

### Added

- New password/passphrase generator (closes #78, #86, #160, #207) [thanks, everyone]

### Improved

- Updated all translations
- Added more detailed crash logs for memory protection issues 


## [1.33.111] - 2022-05-25

### Improved

- Local files should load quickly, no matter what
- Refined File Info dialog interface
- Updated all translations

### Fixed

- DB opening stuck at "Downloading the database… 0%" [thanks, everyone]
- Race condition in file coordination (technical reason of the above)
- It was impossible to open local files with an unresponsive SMB share in the system (fixes #109) [thanks, everyone]
- Parsing misformatted kdbx3/4 timestamps [thanks Jim]
- Reporting missing/unresponsive file providers on iOS 15+
- Minor UI fixes here and there


## [1.32.110] - 2022-05-03

### Fixed 

- Could not export or delete local files (regression in 1.31.105) [thanks, everyone]
- macOS: Replaced DB 'Export' menu with 'Reveal in Finder'.


## [1.31.109] - 2022-04-30

### Fixed 

- macOS: Closing AutoFill dialog with Escape key [thanks, u/TCIHL]
- macOS AutoFill: improved database unlocker UI 
- More informative crash reports
- Broken changelog format (regression in 1.31.108)


## [1.31.108] - 2022-04-28

### Improved

- Refined some texts (#228, #219) [thanks, Taxyovio]
- Updated all translations

### Fixed

- Added parsing of `MasterKeyChangeForceOnce` tag in KDBX databases [thanks, M.H.]


## [1.31.107] - 2022-04-23

### Improved

- Disabled spelling autocorrection in entry editor (closes #223) [thanks, everyone]
- Hidden redundant OTP config fields from entry viewer (closes #218) [thanks, plus-or-minus]
- Made `TOTP Settings` field optional (closes #225) [thanks, plus-or-minus]
- AutoFill will compare port numbers when comparing URLs [thanks, Z.X.]

### Fixed

- macOS: Cleaned up redundant menu items on macOS
- Fixed readability of last characters in expanded fields [thanks, Sachin]
- Removed copyright year from About screen
- Removed obsolete error description for read-only OneDrive [thanks, Thomas]


## [1.31.106] - 2022-03-26

### Improved 

- Renamed TOTP field for clarity (closes #219) [thanks, plus-or-minus]
- Updated all translations

### Fixed

- Loading cached files when there is an unreachable SMB server in the system (related #109)
- Keyboard focus on app launch [thanks, Nelson and raja]
- File info sometimes did not refresh


## [1.31.105] - 2022-02-09

### Improved

- Upgraded YubiKit from 2.0 to 3.2
- Added an opt-in "deep debug" mode for TestFlight builds, to analyze a rare bug
- Updated all translations

### Fixed

- Crash on iPod Touch devices running iOS 15 (fixes #215)


## [1.31.104] - 2022-01-28

### Changed

- Switched to a more lightweight method to access files (`NSFileCoordinator` instead of `UIDocument`).

### Fixed

- AutoFill crash when large DBs present in the app [thanks, everyone]
- macOS: double Touch ID prompt for Quick AutoFill [thanks, Ville]
- Entries hidden from AutoFill could still appear there (related #100) [thanks, u/567567]
- Some icons did not immediately refresh when changing the icon set [thanks, Kamil]
- Some errors appeared as codes instead of human-readable messages [thanks, everyone]


## [1.30.103] - 2021-12-25

### Added

- Offline caching: when database is unreachable, load latest local copy (#135, #17)
- Customizable download timeout for each database

### Improved

- Default download timeout reduced from 15 to 10 seconds
- macOS: show the actual file path in File Info dialog

### Fixed

- AutoFill sometimes mishandled several perfect matches (fixes #212) [thanks, loeffelpan]
- AutoFill sometimes opened an empty window [thanks, Nico]


## [1.30.102] - 2021-12-19

### Fixed

- New attachments did not export properly via `Save As` menu (fixes #211) [thanks, Andreas]
- AutoFill failed to show biometric unlock (regression in 1.28.97) [thanks, Felix and Ville]
- Buttons in passcode input screen could be covered by keyboard [thanks, Ville]


## [1.30.101] - 2021-12-10

### Improved

- Easier copying from a newly created entry [thanks, u/uschrisf and u/Vakke]

### Fixed

- macOS: Quick AutoFill now also works on macOS (fixes #206)
- Empty window on iPad when launching in Split View mode [thanks, G]
- Passwords were not colored in some cases [thanks, Jan]
- AutoFill could use a wrong directory after freemium-to-Pro upgrade [thanks, ARK]
- AutoFill could lock up the database when running low on memory [thanks, Tim]
- Deserialization of pre-1.28 database settings
- macOS: `Remove Master Keys` could miss some files in AutoFill
- macOS: Some texts appeared truncated


## [1.29.100] - 2021-11-29

### Improved

- New/edited entry gets highlighted in the group (now also on iPhones) [thanks, u/uschrisf]
- Database context menu is duplicated on the `...` button [thanks, Igor]
- Updated NL/PT/SK translations [thanks, everyone]

### Fixed

- Localization was mostly broken in previous release [thanks, everyone]
- Quick AutoFill setup prompt appeared all the time [thanks, everyone]
- Pressing Cancel while changing the app protection passcode could erase the passcode [thanks, Kevin]
- Text input mode for username and URL fields


## [1.28.99] - 2021-11-23

### Improved

- Updated translations [thanks, everyone]

### Fixed

- Occasional freeze and crash when launching the app [thanks, everyone]


## [1.28.98] - 2021-11-21

### Added

- Quick AutoFill - fill out login forms with one tap, without even opening AutoFill (closes #50)
- Can manually configure any database as read-only (related #64)

### Improved

- AutoFill setup instructions are also available for macOS
- UI improvements here and there
- Updated translations

### Fixed

- AutoFill for ccSLD domains like .co.nz or .co.jp (closes #201) [thanks, Adam and waynezhang]
- Search field abruptly disappeared in some cases [thanks, Andrew]
- Possible memory leak when tapping "Switch database" repeatedly
- macOS: open/create database menu did not work sometimes


## [1.28.97] - 2021-10-26

### Changed

- This version requires iOS 14 or newer

### Improved 

- Sensitive data is encrypted in process memory using Secure Enclave
- All app files are additionally encrypted on disk and cannot be accessed while device is locked (NSFileProtectionComplete). Reinstall the app to activate this. (closes #141)
- More secure keychain-based biometric authentication
- Require passcode unlock after biometric data was modified
- Keychain-stored data is restricted to the current device
- Improved highlight of focused text fields on macOS
- Old-style popups partially replaced with modern menus

### Fixed

- "Clear master keys on timeout" option was treated as always on
- Show diagnostics on repeated Cancel taps [thanks, Anders]
- Occasional crashes caused by database timeout on launch
- Annoying autocorrection in URL fields


## [1.27.96] - 2021-10-08

### Improved

- Updated translations

### Fixed

- New attachments to kdbx3 files were unreadable in KeePass [thanks, Adam]
- Regression in 1.27.95: Wrong DB picker UI in AutoFill


## [1.27.95] - 2021-09-26

### Added

- Possibility to copy/move data to other databases (closes #102) [thanks, everyone]
- Added Ukrainian translation [thanks, Max]

### Improved

- Show file info in Sync Conflict alert
- Optionally accept input from AutoFill providers
- Updated all translations

### Fixed

- Timestamped backups were zero-filled (regression in 1.25.92)
- Modulo bias in password generator (fixes #195) [thanks, Ben]
- It was possible to skip premium upgrade notice (regression in 1.25.93)
- Latest in-app backup was not updated when saving a conflicted DB
- Auto-unlock worked only with "Auto-open the Previous Database" enabled [thanks, Tom]
- Launch animation glitch [thanks, G]
- Minor UI fixes here and there


## [1.26.94] - 2021-09-06

### Improved 

- Show OTP codes in entry list (closes #8) [thanks, everyone]
- Mark entries with attachments [thanks, David]

### Fixed

- AutoFill could show Touch ID prompt repeatedly [thanks, everyone]
- Crash when adding attachments [thanks, everyone]
- Insert/delete animation of custom fields [thanks, G]


## [1.25.93] - 2021-08-31

### Added

- Possibility to save attachment files (in addition to view/export) (fixes #189) [thanks, Vitaly]

### Improved

- macOS: increase max width of split view's primary column
- macOS: add entry/group creation to main menu
- As an experiment, won't reduce DB timeout in free version under heavy use

### Fixed

- Soft-enforce single-DB limit in free version (#52)
- Regression in 1.25.89: all DB Timeouts were paywalled in free version
- Ensure incoming attachment files are closed after import


## [1.25.92] - 2021-08-27

### Added

- Detect database conflicts on save, with "Overwrite" and "Save as" options ("Merge" is coming later)

### Improved

- Integration with macOS: UI, hotkeys, navigation (for example: Cmd-F to start search, Esc to return to previous view) [thanks, Vitaly]
- Added "Learn more" help links for most common issues
- Fonts in entry viewer and file info dialogs
- Run slow file operations (e.g. backup maintenance) in background
- Show database loading warnings also in AutoFill
- Modern menu UI for username suggestions (iOS 14+)
- Updated all translations [thanks, everyone]

### Fixed

- Regression in 1.25.89: Pro version requested purchase [thanks, Vitaly]
- Possible crash when leaving some settings pages (fixes #179) [thanks, Vitaly]
- Possible crash when DB locks up with a modal window (fixes #188) [thanks, Vitaly]
- Some error messages appeared partially off-screen


## [1.25.91] - 2021-08-19

### Improved

- Updated all translations [thanks, everyone]

### Fixed

- Regression in AutoFill: automatic search did not work (fixes #176) [thanks, everyone]


## [1.25.90] - 2021-08-17

### Fixed

- macOS: Enable premium features when running in beta testing mode [thanks, u/remraf_1]


## [1.25.89] - 2021-08-13

### Changed

- This version requires at least iOS 12
- Massive internal changes to simplify future development

### Added

- Entry history management (closes #56) [thanks, Joahna V, Ivo and A13BioniciOS6]
- Possibility to purchase premium version without subscription "like a CD box"
- Possiblity to attach pictures from Photo Library or camera (closes #162) [thanks, everyone]
- View entry's attachments as a gallery
- Donations! Anyone can support the development now

### Improved

- AutoFill and the main app use the same file list (iOS 14+). Finally! (#1, #122, #125)
- Added a separate field for hardware keys; no more confusion with key files
- Entry expiration date can be edited
- Show "What's new" section also in KeePassium Pro
- AutoFill will import key files if possible, instead of simply referencing them (iOS 14+) (#142)
- You can also select a key file for one-time use, without adding it to the list
- Disabled editing of internal backup databases (they were always intended as read-only)
- Search bar is visible by default (#165, #157) [thanks, everyone]
- Can select and delete attachments in bulk
- Can re-add a broken database directly from the error message
- Showing database errors in a popup, better visibility on small screens
- Added detection of Mega.nz and Boxcryptor (2021) file provider
- Disabled Entry Viewer page swiping/animation on macOS
- Added links to online help for most common issues
- More informative licensing status display
- Refined import workflow from other apps

### Fixed

- Prevent iCloud Keychain AutoFill prompts for password fields (caused a lot of confusion) (related #44)
- Fixed keyboard occasionally missing in AutoFill. 4th attempt, should do the trick (fixes #133)
- Entry attachment preview on macOS (closes #174) [thanks, layandreas]
- Help article about Perpetual Fallback license was misformatted
- Opening the Premium Upgrade screen from AutoFill
- Double Face ID scan after a failed attempt (fixes #158) [thanks, Fotis]
- Several UI improvements throughout
- Hide Custom App Icon setting if not supported by the system [thanks, Andreas]
- Automatically trim whitespaces in OTP config field
- It was impossible to switch entry/group from a custom to (the current) standard icon
- Subscription remained active after a cancelled trial [thanks, everyone]
- Large text did not display correctly in AutoFill [thanks, Peter]


## [1.25.88] - 2021-07-30

- An internal build to ensure TestFlight continuity.


## [1.24.87] - 2021-05-06

### Added

- Support for KDBX 4.1 format [thanks, Dominik]
- Korean translation [thanks, somni]

### Improved

- Updated all translations [thanks, everyone]

### Fixed

- Regression in 1.24.86: entry history was not updated on save
- In .kdb databases, deleted Backup group would get broken until DB reload


## [1.24.86] - 2021-04-26

### Added

- Possibilty to add and select custom icons for groups and entries (closes #84) [thanks, Igor]
- Slovak translation [thanks, onegin1]
- Thai translation [thanks, poonnawit]
- Turkish translation [thanks, ofmenlik]

### Improved

- Visibility of black custom icons in dark mode [thanks, Jon]
- Updated all translations [thanks, everyone]
- Tech debt: internal improvements to streamline further development

### Fixed

- Editor changes were not detected in some rare cases
- Updating associated key components only after successful DB save [thanks, Doug]
- "Hide Passwords" switch in Appearance settings did not work [thanks, Greg]
- Minor UI fixes


## [1.23.85] - 2021-03-29

### Improved

- Added "1 week" database timeout option [thanks, as]

### Fixed

- Fixed processing of OTP parameters defined as otpauth URL [thanks, Marcel]
- VoiceOver will announce toast notifications


## [1.22.84] - 2021-03-19

### Added

- Setup one-time passwords (TOTP) with QR codes (closes #24) [thanks, Igor]

### Improved

- Better-looking context menus (iOS 13+)
- Less important messages are shown as subtle popups (toasts)
- More informative messages if database saving fails (looking at you, OneDrive)
- If database saving failed, the app will offer to save it elsewhere
- Pressing Enter in AutoFill search will select the first result
- On database creation, remind the user to remember the password
- More balanced App Store review prompts
- Updated all translations [thanks, everyone]

### Fixed

- Regression in 1.22.83 beta destroyed TAB/CR/LF characters on save (related #148)
- Some accessibility labels were not translated
- macOS: AutoFill disappeared immediately on show (fixes #147)
- macOS: Minor UI issues here and there [thanks, everyone]


## [1.22.83] - 2021-02-25

### Fixed

- Filter out invalid low-order ASCII characters from pasted/loaded data (fixes #148) [thanks, Mirko]


## [1.22.82] - 2021-02-20

### Added

- Appearance settings page
- Icons from KeePass (Nuvola) and KeePassXC (Icons8)
- "Copy to Clipboard" button to diagnostic viewer [thanks, Eugene]
- "Change Passcode" button in settings

### Improved

- Instructions in Passcode Input dialog
- Clarified license terms for KeePassium (Roundicons) icons
- Text size moved from zoom gesture to Appearance settings (fixes #132)
- Tech debt: adopting coordinators instead of massive view controllers (ongoing)
- Tech debt: unified Diagnostics Viewer
- Minor improvements for Mac Catalyst (#82)
- Updated TPInAppReceipt to 3.0.1

### Fixed

- Database lock timeout was not always respected on iOS 14.4 [thanks, Don and Marinus]
- Crash on iOS 14.4 when cancelling entry creation [thanks, Sandu]
- Crash on iPad when there is no default email client [thanks, Florian]


## [1.21.81] - 2021-01-30

### Refined

- Allow changing master keys to YubiKey-only (no password, no key file)
- Storage provider icon/name when running as iOS app on macOS
- Loading warnings include DB generator name only when it matters
- Updated all translations [thanks, everyone]

### Fixed

- Version parsing of XML key files (fixes #143) [thanks, Kenneth and Ty]
- File provider assertion when running as iOS app on macOS 
- File reference error when running as iOS app on macOS [thanks, u/SmugAlien]
- Crash when creating DB with empty password and key file [thanks, Doug]


## [1.21.80] - 2021-01-21

### Added

- Expert setting "Remember Derived Master Keys" (allows enforcing YubiKey scan) [thanks, Simon]

### Refined

- Show a warning when opening a temporary backup database 
- Improved accessibility of the premium upgrade screen
- After a one-time purchase, remind to cancel ongoing subscriptions

### Fixed

- Processing of key files [thanks, everyone]
- In some conditions, it was possible to open database after a timeout (fixes #140) [thanks, Don]


## [1.21.79] - 2021-01-10

### Added 

- Premium subscriptions now support Family Sharing
- Support for Argon2id and .keyx key file format (KeePass 2.47) [thanks, Dominik]
- VoiceOver: added "Copy Field" accessibility actions in group viewer [thanks, Adam]
- VoiceOver: added Open URL and Share URL accessibility actions for URL fields
- An option to exclude automatic backup files from iTunes/iCloud Backup [thanks, Patrick]
- Option "Lock on App Launch" (settings → App Protection → Timeout) [thanks, Paul]
- Arabic translation [thanks, ZER0-X and Ali Madan]
- Polish translation [thanks, Michał and qxtno]
- Portugese (Brasilian) translation [thanks, Éctor Moreira]

### Refined

- VoiceOver: better descriptions for groups
- Added a warning when opening database from Recently Deleted [thanks, u/opticillusion]
- It is possible to skip AutoFill setup now [thanks, Michael]
- Refined perpetual fallback license text and made it shorter
- Added detection of QNAP Qfile file provider
- Clear master keys when Remember switch is turned off
- Added "Pro" to About screen of the Pro version [thanks, Glenn]
- Updated all translations [thanks, everyone]

### Fixed

- Removed excessive animation when sorting files [thanjks, Vadim and Alan]
- KeePassium won't ask for AppStore review if the user barely used the app [thanks, Timothy]
- Sometimes associated key file was not selected [thanks, Robert]
- In case of database load error, AutoFill won't ask to re-enter the password [thanks, Tim]
- Adding key files with unrecognized/dynamic UTIs [thanks, Daniel]
- Added a debug "Reset entry text scale to default" button at the end of About screen (related #132)
- Made entry field text depend on system font size (possibly fixes #132)
- iOS 14: could access selected text menu through the passcode screen [thanks, Jacob]
- VoiceOver: added missing labels to several buttons [thanks, Fabrice and Adam]
- VoiceOver: improved accessibility of settings that require premium
- VoiceOver: support email address is accessible now [thanks, Adam]
- iOS 14: Keyboard was missing in AutoFill after cancelling biometric prompt — partial fix (#133)
- iOS 14: fixed opening mailto: links in alternative mail clients [thanks, Gianfranco]
- User name generator: made the random option visually distinct [thanks, Daz]
- Minor UI improvements here and there


## [1.20.78] - 2020-11-12

### Changed

- Refined: Allow unlocking databases protected only by YubiKey [thanks, Stefan]

### Fixed

- Sometimes keyboard did not show up in AutoFill on iOS 14 (#133) [thanks, everyone]
- Always treat password fields as protected (related libkeepass/pykeepass#194) [thanks, Ilya]
- Prevent VoiceOver from looking behind the passcode/cover windows on iOS 14 [thanks, Stéphane]
- Unavailable file provider (e.g. SMB) could cause app freezing [thanks, Nicole]
- Unresolved field values for newly created fields
- Using resolved field values througout the app


## [1.20.77] - 2020-10-21

### Added

- Entry field references, resolved and displayed (closes #77)

### Changed

- Refined: iOS 13+ will use system's monospaced font (SF Mono) instead of Menlo

### Fixed

- Excluded unavailable DBs from single-DB limit (related #125) [thanks, rederensy]
- AutoFill did not recognize the premium fallback date [thanks, Pablo]
- "YubiKey not available" was not always shown in AutoFill [thanks, Markus]
- File info dialog controls were unresponsive on iPadOS 12.4 [thanks, u/chrie1]
- Minor UI issues


## [1.19.76] - 2020-10-03

### Changed

- Enabled express unlock in the free version.

### Fixed

- Possible database corruption on save in v1.18 (fixes #130) [thanks, everyone]
- URL fields not recognized on iOS 14 if default browser is not Safari (fixes #129) [thanks, Ivo]


## [1.18.75] - 2020-10-01

### Added

- [Premium] Express unlock using the stored decryption key. This also allows opening YubiKey-protected databases in AutoFill.

### Changed

- Free version won't count broken databases towards the free DB limit
- Added detection of Stratospherix FileBrowser file provider
- Refined local storage icons

### Fixed

- Slow decryption of databases (fixes #128) [thanks, everyone]
- Preserve DB settings on DB deletion, if another DB uses them [thanks, Tim]
- Crash when unselecting a YubiKey in AutoFill
- Detection of file access permission error
- Delete .latest backups when manually deleting all backups via settings


## [1.17.74] - 2020-09-19

### Changed
 
- (iOS 14) Suggesting to re-add the database if it seems missing.
- Keeping the .latest backup file regardless of its age
- Refined CallerID in AutoFill to make it easier to copy [thanks, Adam]
- Showing a wait animation when deleting many backup files
- Increased the max length of generated passwords to 100 [thanks, u/ReevaluateAdNauseam]

### Fixed

- Recognizing storage providers on iOS 14
- Freezing when there are hundreds of backup files (related #109) [thanks, everyone]
- Opening files with unregistered extensions [thanks, Kevin]
- Displaying multi-line Caller ID URLs in AutoFill [thanks, Adam]
- App icon picker UI on iOS 12 (closes #123) [thanks, dragonblitz10]
- Sometimes backup files were shown as external ones
- Opening kdbx4 files with UInt32 transformRounds (keeweb/keeweb#1598) [thanks, Mitchell]
- Hopefully fixed: text missing in entry viewer [thanks, Lionel and Jean-Marc]
- Splash screen background color in dark mode


## [1.16.73] - 2020-08-31

### Added

- Change entry text size with a zoom gesture [thanks, Rick and Thomas]

### Changed

- Refined: preserving the expanded/collapsed state of the Notes field [thanks, Arjan and Thomas]
- Improved Export and Trash icons [thanks, Ivo]
- Updated translations [thanks, everyone]

### Fixed

- Help article text was black in dark mode [thanks, Christian]


## [1.15.72] - 2020-08-28

### Fixed

- Replaced "Try it free" with "Upgrade now" to address AppStore reviewer's comment


## [1.15.71] - 2020-08-28

### Fixed

- Moved trial conditions to the purchase button itself (to address AppStore reviewer's comment)


## [1.15.70] - 2020-08-27

### Added

- Perpetual fallback license for subscriptions (a.k.a. "rent-to-own license")
- App history screen (What's New)

### Changed

- Improved search with diacritics: insensitive to diacritics, unless you use diacritics in the query (closes #118) [thanks, hunhejj]
- Improved haptic feedback in AutoFill
- Updated translations [thanks, everyone]

### Fixed 

- Replacing broken references to external files failed sometimes [thanks, Paul]
- Relative project file paths on GitHub (thanks, @mj)


## [1.14.69] - 2020-08-11

### Added

- Special icon for databases in Trash (Recently Deleted) folder

### Fixed

- Crash after updating the app (iPad) [thanks, everyone]
- Crash when adding an entry attachment	[thanks, Sophie]
- File refresh spinner were invisible in dark mode
- Some icons in the settings


## [1.14.68] - 2020-08-04

### Added

- Customizable app icon
- Offline fallback option: KeePassium maintains a backup copy of the last loaded/saved version of database

### Changed

- Default app icon changed to Atom Blue (freemium) and Atom Black (Pro)
- By default, backups are now kept for 2 months instead of forever
- More detailed file location description for internal files
- Code: switched to KeePassium's own, checked fork of TPInAppReceipt
- AppLock setup reminder can be dismissed [thanks, Dan]
- Minor UI refinements here and there
- Updated DE/FR/JA/NL/RU translations [thanks, everyone]

### Removed

- Xcode11GM_LocalizedLabel, an obsolete workaround for #60

### Fixed

- Excessive caching of file attributes (size, timestamps)
- After transferring to a new device, AppLock did not always accept the correct passcode [thanks, Kirsten]
- Add note that Universal Clipboard timeout on external devices is fixed at 2 minutes [thanks, Christian]
- Backup files with non-standard extensions were not shown
- Tapping the "Show backup files" could change the file sort order instead
- Sporadic crash immediately after loading a database
- AutoFill Setup smallprint always appeared in English
- Return key behavior when changing DB master key
- Hardware key picker is localized now


## [1.14.67] - 2020-07-25

### Changed

- More human-friendly messages about missing file provider
- Replaced problematic NSFileCoordinator calls with UIDocument ones
- Refined purchase dialog UI on iPad
- Updated Japanese translation [thanks, miyar520]

### Fixed

- Fixed persistent timeouts when using Google Drive, DS file and some other clouds. [thanks, everyone]
- Fixed freezing when there are many backup files (fixes #114) [thanks, Paul]
- Added missing credits for Yubico Mobile SDK and TPInAppReceipt library


## [1.14.66] - 2020-07-18

### Added

- "Exclude from iCloud/iTunes backup" option for local files (closes #97) [thanks, everyone]
- Free trial period for premium subscriptions

### Changed

- Accepting databases with any file extension (closes #113) [thanks, everyone]
- Removed premium upgrade button from DB unlock screen
- Upgraded to Swift 5


## [1.14.65] - 2020-07-14

### Added

- New "Clear master keys on database timeout" switch to close-but-not-lock databases in multi-device scenarios [thanks, Niklas]
- New UI for premium upgrade

### Changed

- Increased file timeout from 5 to 15 seconds [thanks, everyone]
- More human-friendly error messages when cloud provider does not respond
- Updated Japanese and Russian translation [thanks, miyar520]
- Minor UI improvements throughout

### Fixed

- Crash on cold launch with an argument [thanks, Helmut]
- Jumpy pull-to-refresh animation [thanks, Sebastian]
- Respect the "Search enabled" flag of KP2 groups [thanks, David]
- Disabled search and auto-type in newly created Recycle Bin


## [1.14.64] - 2020-06-28

### Added

- Japanese translation [thanks, Hiroto Sakai and miyar520]

### Changed

- Refined sorting: files with errors are always listed last
- [TestFlight only] the "[no leftNavController](https://github.com/keepassium/KeePassium/blob/46a3c09d8a00ebd0c82d8707ba89b9ecbd273de7/KeePassium/database/UnlockDatabaseVC.swift#L468)" crash will produce a debug log file
- Updated German translation [thanks, Sebastian]

### Fixed

- Crash when importing an already existing file [thanks, Marc]


## [1.14.63] - 2020-06-21

### Added

- More detailed storage location of files
- Wait animation while waiting to access files (#92, #109)
- AutoFill will show the Caller ID (calling app domain or URL) [thanks, Markus]
- File Info dialog for key files in AutoFill
- Export and Remove buttons to File Info dialog

### Changed

- More detailed load/save progress messages
- More recognizable "sort order" icon
- Added extended diagnostics for DSfile's "7b226572726f7222" issue

### Fixed

- Added a 5-second timeout to all file operations (fixes #92,#109)
- File Info dialog now loads asynchronously [thanks, Tim]
- More reliable refreshing of file lists (each file independently)
- Handling DB settings/keys when the target file is missing
- KDB root group appeared expired (fixes #108) [thanks, Stefan]
- App crashed when selecting "Enable AppLock" reminder with VoiceOver [thanks, Dickson]
- Refresh entry viewer after dismissing entry editor [thanks, Felix]
- Refresh search results after changing search settings [thanks, Paolo]
- Standard field names are excluded from search [thanks, Paolo]


## [1.13.62] - 2020-06-09

### Changed

- Version number only (because App Store Connect insist on an increase)


## [1.12.61] - 2020-06-09

### Changed

- Updated CZ/FR/SV translations
- Refined animation when adding a custom field

### Fixed

- Progress bar sometimes appeared misplaced [thanks, Michael]
- Excessive text view change notifications (fixes #107) [thanks, Michael]


## [1.12.60] - 2020-06-04

### Changed

- Updated DE/ES/RU translations

### Fixed

- Database file descriptions were shown in the system in wrong language (fixes #103) [thanks, majijiwi]
- Load entries with missing field values, treat them as empty [thanks, Oliver]
- Support Steam TOTP configured in KeePassXC with the "encoder" parameter (closes #101) [thanks, Manan] 
- Added search settings to localizable resources

## [1.12.59] - 2020-05-26

### Added

- New setting: whether to auto-unlock the last used database [thanks, Stanislav and Niklas]
- New settings: whether to search in field names and in protected values [thanks, Paolo]
- After copying a field, you can also quickly share it to other apps
- More detailed loading progress messages for .kdbx databases
- Entries marked as non-autofillable in KeePassXC won't appear in AutoFill (closes #100) [thanks, Igor]

### Changed

- Refined accessibility: respect the "bold text" system setting
- Support email template now includes device type (iPhone/iPad)

### Fixed

- Animation of the "Copied" overlay when switching between fields
- With extra-large font, group names appeared trimmed by height
- Don't show AppLock setup prompt if master keys are not stored
- Minor layout and wording improvements in the settings


## [1.12.58] - 2020-05-10

### Added

- App Lock setup is now part of initial onboarding [thanks, everyone]
- Added animated prompts to insert/touch YubiKey 5Ci key
- New setting: show protected fields (off by default) (closes #95) [thanks, Jerry & Jeffrey]
- New setting: use Universal Clipboard (off by default) [thanks, Daniel]
- Added file operation buttons to the File Info dialog [thanks, Dirk]
- The notes field is expandable now

### Changed

- Updated/refined some translations

### Fixed

- Parsing of misformatted ISO 8601 timestamps (sometimes created by MiniKeePass) [thanks, everyone]
- Biometric auth asked for a premium upgrade under a heavy use [thanks, Theo]
- Import conflict resolution dialog did not appear for key files
- Groups and entries always appeared as non-expiring in v1 databases [thanks, Stefan]
- Layout of the hardware key picker on iPad


## [1.11.57] - 2020-04-16

### Added

- Re-added support for YubiKey 5Ci (and other YubiKeys with MFi interface)


## [1.11.56] - 2020-04-16

### Added

- Auto-unlock the last used database on iPad like on iPhone (if allowed by the settings and on first launch only) [thanks, everyone]
- New setting: whether AutoFill should automatically proceed when there is only one suitable entry (related #76) [thanks, Nicolai]

### Fixed

- Now it is possible to edit/move Recycle Bin in .kdbx databases [thanks, Amnuay]
- Sometimes it was not possible to select databases from Google Drive [thanks, K.B.]


## [1.11.55] - 2020-04-11

### Added

- Italian translation


## [1.11.54] - 2020-04-10

### Added

- French translation
- When importing a database, the app will ask whether to overwrite the existing database (closes #91)

### Changed

- When you delete a file, it is no longer moved to the trash but deleted outright. (Moving to trash seems to fail randomly; so sometimes it was impossible to delete a file.)

### Fixed

- Always treat password fields as protected (libkeepass/pykeepass#194) [thanks, Robin]
- Changed master key was not remembered when it should have been
- Adding databases with mixed-case extensions, such as all-caps .KDBX [thanks, Thorsten]
- When moving groups/entries, their timestamps were updated incorrectly, and the move was rolled back when merging with an earlier version of the database [thanks, Daniel]
- Updating master key modification timestamp once it's been changed
- Sometimes it was impossible to delete files
- Infinite clipboard timeout was treated as immediate [thanks, Andreas]
- Backup files are no longer counted towards free 1-database limit
- Hard-coded absolute path in contents.xcworkspacedata (fixes #90)
- Showing and re-hiding a password sometimes produced colored asterisks
- Minor translation fixes


## [1.10.53] - 2020-01-19

### Fixed

- Version bump for AppStore publication
- Parsing problematic timestamps in DBs written by KeePassDX (Kunzisoft/KeePassDX#415)


## [1.09.52] - 2020-01-17

### Changed

- YubiKey support is now available only in premium version

### Removed

- MFi interface (while pending registration)


## [1.09.51] - 2020-01-15

### Added

- YubiKey support (compatible with KeePassXC)


## [1.09.50] - 2020-01-14 [REJECTED]

- Rejected by Apple: missing camera usage description
- Added: YubiKey support (compatible with KeePassXC)


## [1.09.49] - 2020-01-14

### Added

- Move/copy groups and entries to other groups (closes #48)
- Long-press menu for files, groups and entries
- Highlight digits and special symbols in stored passwords [thanks, Sean]
- Support for Steam TOTP with GAuth URI format (closes #85) [thanks, Nu11u5]
- Support for TOTP based on SHA-256 and SHA-512 (closes #81) [thanks, Walter]
- "Add Key File" button to key file pickers [thanks, Ron]

### Changed

- Use local URLs for local files, instead of resolving bookmarks (related #71, #88)
- Preserve the entered master password after DB unlock errors [thanks, Bertrand]

### Fixed

- Occassional freezing at "Loading... 0%" (fixes #88) [thanks, everyone]
- An attempt to fix random freezing when accessing local files on iOS 13 (#71)
- AutoFill FaceID loop on 13.1.3 (closes #74 again) [thanks, Quinn]
- Add missing special symbols in password generator [thanks, Justen]
- "Failed to open file" error after creating a new database [thanks, Craig]
- Loading MiniKeePass DBs with minor issues (missing custom icon UUIDs and group timestamps) [thanks, everyone]
- Overly wide popovers on iPadOS 13


## [1.08.48] - 2019-11-27

### Added

- AutoFill will automatically select the found entry, if there is only one (closes #76) [thanks, Igor]

### Fixed

- A possible fix for the file picker issues in AutoFill (#79) [thanks, Thorsten]


## [1.08.47] - 2019-11-25

### Changed

- Auto-unlock databases whenever possible (2nd attempt)


## [1.08.46] - 2019-11-25

### Fixed

- Improved handling of databases that close slowly


## [1.08.45] - 2019-11-24

### Changed

- Reverted: auto-unlock from v1.07.44 (it was very unstable, will be re-tried in a separate build)
- Added a confirmation dialog when locking database manually [thanks, Tim]
- Added timestamps to diagnostic log to help debugging slow operations

### Fixed

- AutoFill stuck in FaceID loop on iOS 13.2.3 (fixes #74)
- Sometimes entries incorrectly appeared as expired [thanks, Felix]
- Double unlock screen after database creation (fixes #68) [thanks, magebarf]
- Repetitive Welcome screen after clearing backup files [thanks, Chris]


## [1.07.44] - 2019-11-11

### Changed

- Databases with a stored master key will unlock automatically when appropriate.


## [1.07.43] - 2019-11-10

### Added

- Haptic feedback for some UI actions

### Changed

- Won't force-erase the master key from keychain on database errors [thanks, Silunare]

### Fixed

- With passcode-only AppLock, database list flashed visible on launch [thanks, Joseph]
- AppLock worked intermittently on iOS 13.2 (#72) [thanks, loblawbob]
- Compatibility with other installed KeePass apps [thanks, Philippe]
- Removing key file associations when deleting a database [thanks, M.H.]
- Premium features missing in Pro version's AutoFill [thanks, J.B.]


## [1.06.42] - 2019-10-18

### Changed

- "Database timeout" option now defaults to Never instead of 1 hour.

### Fixed

- Fix layout of the item counter in group viewer [thanks, Simone]


## [1.06.41] - 2019-10-14

### Added

- Spanish translation [thanks, Juan_Net and NicolasCGN]

### Changed

- Under-the-hood: database state broadcasts (notifications) replaced by observers to prevent race conditions

### Fixed

- Respect font size settings throughout the app [thanks, AD]


## [1.05.40] - 2019-10-06

### Added

- KeePassium Pro as a family-friendly alternative to premium upgrade
- Notification about KeePassium Pro release

### Changed

- Premium Upgrade screen remains available to premium users

### Removed

- Outdated notifications (beta transition and early-bird pricing)

### Fixed

- iOS 13: Search bar did not autofocus in AutoFill (fixes #69) [thanks, tunger]
- Database timeout could have been set to 'Never' in free version
- UI colors in the Premium Upgrade screen


## [1.04.39] - 2019-10-04

### Added

- KeePassium Pro edition, compatible with Family Sharing

### Fixed 

- On iPadOS 13, the app launched to an empty screen (fixes #66)


## [1.04.38] - 2019-10-01

### Changed

- Updated Swedish translation [thanks, Patrik]
- Minor changes to facilitate fastlane snapshots

### Fixed

- AppLock passcode colors in dark mode [thanks, Joseph and Chris]
- Handling of the dismiss gesture in AppLock setup dialog (iOS 13)


## [1.03.37] - 2019-09-25

### Added

- Swedish translation [thanks, Patrik Thunström]
- Czech translation [thanks, Tomáš Piešťanský, Marcel Piestansky, and Radek Weis]
- If current database is inaccessible due to new iOS 13 permissions, the app will suggest to re-add the database [thanks, Patrik]

### Removed:

- Beta will not show the "Now in the App Store" button anymore

### Fixed

- Database unlock errors were not always shown
- Now VoiceOver will automatically announce database unlocking errors
- Deleted entries are now excluded from username suggestions


## [1.02.36] - 2019-09-17

### Fixed

- English UI garbled (regression caused by the workaround for #60) [thanks, shad0whawk]


## [1.02.35] - 2019-09-17 [WITHDRAWN]

### Added

- iOS 13 dark mode (#56, closes #35)

### Fixed

- Some elements appeared not translated (closes #60) [thanks, 3374575857]
- Entry timestamps not visible on iOS 13
- Unlock errors sometimes were not visible on small screen (iPhone SE)
- Gesture dismissal of AutoFill and Premium upgrade dialogs on iOS 13
- Premium upgrade did not work on iOS 13


## [1.02.34] - 2019-09-14

### Added

- German translation [thanks, Lukas Wolfsteiner and @cpktmpkt]
- Chinese Simplified translation (omitted by mistake in v1.02.33) [thanks, 3374575857]
- In entry editor, you can choose a random or a frequently used username [thanks, Mike]
- For new entries, the user name field is pre-filled with the default one from database settings [thanks, Mike]
- Added a "Repeat password" field to the Change Master Key dialog [thanks, A.G.]

### Fixed

- Search controller did not show up on iOS 13 (fixes #46)
- Custom fields could interfere with the fixed ones (fixes #54) [thanks, Michael]
- Layout issues (missing buttons) in entry editor [thanks, S.Y.]
- Unlock errors could be squished/invisible on small screens (iOS 13) [thanks, KK9]
- Properly dismissing group/entry editor with a gesture (iOS 13)


## [1.02.33] (Beta Release) - 2019-09-10

### Added
- Russian translation
- Chinese Traditional and Chinese Simplified translations [thanks, 3374575857]
- Dutch translation [thanks, vistausss]

### Changed
- Massive under-the-hood work for localization (#20)
- Expired items now shown in strikethrough font and with original icons
- Refined Edit mode for entry attachments [thanks, KK9]
- Improved VoiceOver label for the entry Notes field [thanks, Adrian]
- Added a title bar to File Sorting popover (closes #51) [thanks, raymond127]

### Fixed
- UI layouts adjusted to accommodate longer texts


## [1.01.32] (Public Release) - 2019-08-12

### Added
- In-app announcements about the AppStore release and early-bird promo
- Associated the app with keepassium.com domain, to allow auto-filling master passwords from Keychain (closes #44)
- Detection whether running in TestFlight (beta) or App Store (production) environment
- Added app version to About screen and diagnostic log (closes #37) [thanks, Marcel]
- AutoFill now also searches for full URL in custom fields (closes #47) [thanks, Dragonblitz10]

### Changed
- Hiding visible passwords when leaving the app (closes #43) [thanks, V.M.]
- Running in TestFlight automatically enables premium features
- Switched to prettier version numbering: major.minor.build

### Fixed
- Incomplete loading of AutoType sequences (fixes #45) [thanks, Silun]
- Fixed broken App Store links (closes #32) [thanks, Patrik]
- Don't show usage stats in premium version (they are frozen anyway)
- Entry sorting in AutoFill (fixes #31) [thanks, rderensy]
- AutoFill did not understand domain-name only URLs [thanks, Brett]
- Accessibility labels in entry editor and for Add Database buttons [thanks, Adrian]
- Creating a new database also created an empty backup file [thanks, Phani]
- Jumpy/squished footer in Settings (closes #33) [thanks, Patrik]

### Removed
- Hidden obsolete "Free trial" countdown from Settings (fixes #36) [thanks, Akshay]
- Removed obsolete debug info from the About screen


## [1.0.30.31] (Public Release) - 2019-07-26

### Added
- Added a business premium tier

### Changed
- Refined the style and wording of the premium upgrade screen

### Fixed
- Fixed positioning of the Upgrade button on iPad

### Removed
- Obsolete (debug) in-app purchases


## [1.0.30] (Public Beta) - 2019-07-24

### Added
- Support for KeeOtp TOTP format (closes #29) [thanks, Z.Z.]

### Changed
- In TouchID prompt, the "Cancel" button renamed to "Use Passcode" for clarity [thanks, James]

### Fixed
- AutoFill did not always quit properly and skipped the TouchID/FaceID prompt [thanks, Arthur]
- Handling of extra settings in TrayTOTP settings (closes #28) [thanks, Bas]
- Accessibility labels in entry editor [thanks, Adrian]
- Scaling of custom icons in AutoFill


## [1.0.29] (Internal Release) - 2019-07-19
An internal release for App Store review. 

### Added
- In-app purchases


## [1.0.28] (Public Beta) - 2019-07-18

### Changed
- Refined AutoFill setup instructions

### Fixed
- Handling of empty tags in decrypted XML
- Accessibility labels on toolbar buttons and password fields


## [1.0.27] (Public Beta) - 2019-07-13

### Added
- Support for URI-formatted TOTP (closes #23) [thanks, Nu11u5]
- View diagnostic log in AutoFill by long-pressing the top-left button (inspired by #22) [thanks, Ankur]
- Possibility to rename attachments (Entry - Files - Edit - tap the file)

### Changed
- Unified search: AutoFill and main app use the same method
- Rearranged "Unlocking Database" settings page

### Fixed
- Parsing of ISO8601 timestamps with fractional seconds [thanks, Luka]
- Copy to clipboard did not work in AutoFill diagnostics (closes #16) [thanks, Dragonblitz10]
- Search in v1/kdb was case-sensitive (closes #21) [thanks, Martin]
- Multi-word search was erratic
- Welcome screen did not close after adding a database (closes #18) [thanks, Patrik and Craig]
- Graceful handling of attachments with empty names [thanks, Marco and Radim]
- Clarified in readme.txt that TOTP is view-only at the moment


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