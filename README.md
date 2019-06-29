# KeePassium Password Manager

[KeePassium](https://keepassium.com) is a KeePass-compatible password manager for iOS. It offers automatic database synchronization, respect to privacy and premium user experience.

KeePassium is a commercial open source app. The "commercial" part gives you a well-maintained app with premium support. The "open source" part gives you the transparency expected from a password manager: you can personally audit the code and build the app you can trust.

## Contents

- [Screenshots](#screenshots)
- [Features](#features)
	- [Automatic sync](#automatic-sync)
	- [Password AutoFill](#password-autofill)
	- [App and Data Protection](#app-and-data-protection)
- [Installation](#installation)
- [Is it free?](#is-it-free)
- [How to Contribute](#how-to-contribute)
- [Support](#support)
- [Author and Credits](#author-and-credits)
- [License](#license)

## Screenshots

![Database Unlock](https://keepassium.com/img/github/unlock-db_w250.png) ![View Group](https://keepassium.com/img/github/view-group_w250.png) ![View Entry](https://keepassium.com/img/github/view-entry_w250.png)

## Features

* [Automatic database synchronization](#automatic-sync) with zero setup
	- Integrates with the system, does not ask for your storage credentials
	- Works with iCloud Drive, Dropbox, OneDrive, Google Drive, Box, Nextcloud, SFTP, and probably more.
* [Password AutoFill (iOS 12+)](#password-autofill) — also with synchronization.
* [App and data protection](#app-and-data-protection):
	- Biometric (Face ID / Touch ID) and passcode-based protection.
	- Customizable timeouts for app, database and clipboard.
	- Database names and app settings are also protected.
* Read/write support for all KeePass formats:
	- `kdbx4` (KeePass 2.35+), `kdbx3` (KeePass 2.x) and `kdb` (KeePass 1.x)
	- ChaCha20, Argon2, AES, Salsa20, Twofish algorithms
* Easy switching between multiple databases
* And more:
	- TOTP support (both RFC-6238 and Steam TOTP)
	- File attachments
	- Custom fields
	- Custom icons
	- No ads

### Automatic sync

KeePassium relies on OS-provided integration with storage providers, and supports most providers that appear in iOS Files app.

* __Full support__ (files are automatically downloaded and uploaded when changed): iCloud Drive, Dropbox, Box, Google Drive, OneDrive, Nextcloud, SFTP (via third-party apps, like [this one](https://itunes.apple.com/app/id1406981461?mt=8))
* __Limited support__ (no background sync, files have to be imported and exported manually): Mega, Cryptomator (it supports [only import/export](https://github.com/cryptomator/cryptomator-ios/issues/98#issuecomment-402446441) operations)
* __Not tested yet__: ownCloud, Tresorit

If automatic sync does not work for you, please make sure the cloud provider app can work in background (device settings — Dropbox/OneDrive/... — Background App Refresh = Enabled). 


### Password AutoFill

To fill your passwords easily and quickly, enable AutoFill feature: device settings — Passwords & Accounts — AutoFill Passwords — select KeePassium in the list.

### App and Data Protection

KeePassium has multi-layer protection from unauthorized access.
- __App Lock__ protects the app itself, by covering any in-app screens. This way, only you can see the unlocked database, the list of databases, or change app settings. 
- __Database Lock__ closes all opened databases after a timeout, or after a failed AppLock attempt. It also removes any remembered master keys from keychain.
- __Encryption__ protects the contents of database files. The app relies on [CommonCrypto](https://opensource.apple.com/source/CommonCrypto/) library (for AES and SHA) and time-proven reference implementations of crypto algorithms (see [Credits](#author-and-credits)).
 
By default, AppLock requires a passcode (of any complexity). For convenience, you can configure the app to use Face ID/Touch ID instead.


## Installation

AppStore release is coming soon. During the beta, the app can be installed via [TestFlight](https://testflight.apple.com/join/y8R6iLlK). 

To build your own binary, download the project and open it in Xcode 10.2 (or above). All the dependencies are already included.


## Is it free?

**Free as in free speech (libre):** Yes! You have the freedom to read, modify and distribute the app under the terms of its [license](#license).

**Free as in free beer (gratis):** No. KeePassium is a freemium app, and some features are reserved for premium version. 

**But I can just...** Yes, you can take the source code and build your personal premium version for free (gratis). Feel free to do so, but please be nice and don't request premium support for personal builds. Also, if you delegate this to a freelancer, please make sure you can trust them. 


## How to Contribute

- [Report bugs](https://github.com/keepassium/KeePassium/issues)
- [Suggest new features](https://github.com/keepassium/KeePassium/issues)
- Write an AppStore review (once the app is there)
- Consider buying a premium version (once it is ready)


## Support

- Bug reports: [GitHub Issues](https://github.com/keepassium/KeePassium/issues)
- Discussion: [/r/KeePassium](https://reddit.com/r/KeePassium)
- Updates: [@KeePassium](https://twitter.com/keepassium)


## Author and Credits

KeePassium is created and maintained by [Andrei Popleteev](http://popleteev.com) (also responsible for [KeePassB for BlackBerry 10](https://github.com/anmipo/keepassb)).

The project would not be the same without some third-party components:

* Graphics:
	- [Feather icons](https://feathericons.com) by Cole Bemis (MIT licence) 	
	- [Ionicons](http://ionicons.com) by Ionic (MIT license)
	- [Linecons](https://designmodo.com/linecons-free/) by Andrian Valeanu (CC-BY-ND 3.0 license)
	- [Fancy deboss pattern](http://subtlepatterns.com) by Daniel Beaton (CC-BY-3.0 when downloaded)
	- [System settings icon](https://www.iconfinder.com/icons/2697651/apple_configuration_control_gear_preferences_setting_settings_icon) by Vicons Design (CC-BY 3.0 license)
	- [Bold outline icons](https://roundicons.com/boldicons-outline-icons-set/) by Round Icons ([commercial license](https://roundicons.com/usage-license/)). They cannot be shared and have been replaced with standard KeePass icons from the [Nuvola icon set](https://en.wikipedia.org/wiki/Nuvola) by David Vignoni (LGPL v2.1).
* Code:
	- [AEXML](https://github.com/tadija/AEXML) by Marko Tadić (MIT license) 	
	- Rijndael implementation by Szymon Stefanek (public domain)
	- [Argon2](https://github.com/P-H-C/phc-winner-argon2) by Daniel Dinu, Dmitry Khovratovich, Jean-Philippe Aumasson, and Samuel Neves (CC0 license)
	- [ChaCha20 & Salsa20](https://cr.yp.to/salsa20.html) implementation by D. J. Bernstein (public domain)
	- [Twofish](http://www.cartotype.com/downloads/twofish/twofish.cpp) implementation by Niels Ferguson (custom very permissive license).
	- [GzipSwift](https://github.com/1024jp/GzipSwift) by 1024jp (MIT license)
	- [Base32 for Swift](https://github.com/norio-nomura/Base32) by Norio Nomura (MIT license)
	- [KeyboardLayoutConstraint](https://github.com/MengTo/Spring/blob/master/Spring/KeyboardLayoutConstraint.swift) by James Tang (MIT license)

To avoid backdoors in third-party code, it has been checked by the main developer. Verified files are directly included in the project — we don't want any surprises sneaking via package managers.

## License

KeePassium Password Manager

Copyright ©2018–2019 [Andrei Popleteev](http://popleteev.com).

KeePassium is a commercial open-source app, available under the  [GPLv3 license](https://choosealicense.com/licenses/gpl-3.0/). Our intention is to provide the maximal possible transparency: you can personally audit the code and build your own binary. 

While derivative works (forks) are explicitly allowed by the GPL, please don't submit them to AppStore. Due to a conflict between GPL and AppStore terms of service, GPL-licensed apps are [banned](https://www.fsf.org/blogs/licensing/more-about-the-app-store-gpl-enforcement) from AppStore. 

For commercial licensing or custom modifications, please [contact us](info@keepassium.com).