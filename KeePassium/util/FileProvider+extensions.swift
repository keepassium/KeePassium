//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension FileProvider {
    var icon: UIImage? {
        switch self {
        case .localStorage:
            return getLocalStorageIcon()
        case .box:
            return UIImage(named: "fp-box-listitem")
        case .boxcryptor:
            return UIImage(named: "fp-boxcryptor-listitem")
        case .dropbox:
            return UIImage(named: "fp-dropbox-listitem")
        case .googleDrive:
            return UIImage(named: "fp-google-drive-listitem")
        case .iCloudDrive:
            return UIImage(named: "fp-icloud-drive-listitem")
        case .nextcloud:
            return UIImage(named: "fp-nextcloud-listitem")
        case .oneDrive:
            return UIImage(named: "fp-onedrive-listitem")
        case .ownCloud:
            return UIImage(named: "fp-owncloud-listitem")
        case .pCloud:
            return UIImage(named: "fp-pcloud-listitem")
        case .smbShare:
            return UIImage(named: "fp-smb-share-listitem")
        case .synologyDSfile:
            return UIImage(named: "fp-nas-listitem") // UIImage(named: "fp-synology-dsfile-listitem")
        case .synologyDrive:
            return UIImage(named: "fp-synology-drive-listitem")
        case .usbDrive:
            return UIImage(named: "fp-usb-drive-listitem")
        case .amerigo:        fallthrough
        case .amerigoFree:    fallthrough
        case .feFileExplorer: fallthrough
        case .qnapQFile:      fallthrough
        case .readdleDocuments: fallthrough
        case .resilioSync:    fallthrough
        case .seafilePro:     fallthrough
        case .stratospherixFileBrowser: fallthrough
        case .syncCom:        fallthrough
        case .tresorit:       fallthrough
        case .yandexDisk:     fallthrough
        case .other:
            return UIImage(asset: .fileProviderGenericListitem)
        }
    }
    
    private func getLocalStorageIcon() -> UIImage? {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return UIImage(named: "fp-on-iphone-listitem")
        }
        if ProcessInfo.isRunningOnMac {
            return UIImage(named: "fp-on-hard-drive-listitem")
        } else {
            return UIImage(named: "fp-on-ipad-listitem")
        }
    }
}
