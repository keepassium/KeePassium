//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension FileProvider {
    var iconSymbol: SymbolName? {
        switch self {
        case .localStorage:
            return FileProvider.getLocalStorageIconSymbol()
        case .box:
            return .fileProviderBox
        case .boxcryptor,
             .boxcryptorLegacy2020:
            return .fileProviderBoxCryptor
        case .dropbox:
            return .fileProviderDropbox
        case .googleDrive:
            return .fileProviderGoogleDrive
        case .iCloudDrive, .iCloudDriveLegacy:
            return .iCloud
        case .keepassiumWebDAV:
            return .fileProviderWebDAV
        case .keepassiumOneDrive:
            return .fileProviderOneDrive
        case .nextcloud:
            return .fileProviderNextCloud
        case .oneDrive:
            return .fileProviderOneDrive
        case .ownCloud:
            return .fileProviderOwnCloud
        case .pCloud:
            return .fileProviderPCloud
        case .smbShare:
            return .fileProviderSMB
        case .synologyDSfile:
            return .fileProviderNAS
        case .synologyDrive:
            return .fileProviderSynologyDrive
        case .usbDrive:
            return .fileProviderUSB
        case .amerigo,
            .amerigoFree,
            .feFileExplorer,
            .megaNz,
            .magentaCloud,
            .qnapQFile,
            .readdleDocuments,
            .resilioSync,
            .seafilePro,
            .stratospherixFileBrowser,
            .syncCom,
            .tresorit,
            .yandexDisk,
            .other:
            return .fileProviderGeneric
        }
    }

    public static func getLocalStorageIconSymbol() -> SymbolName {
        if ProcessInfo.isRunningOnMac {
            return .fileProviderGeneric
        }
        let device = UIDevice.current
        switch device.userInterfaceIdiom {
        case .pad:
            if device.hasHomeButton() {
                return .iPadHomeButton
            } else {
                return .iPad
            }
        case .phone:
            if device.hasHomeButton() {
                return .iPhoneHomeButton
            } else {
                return .iPhone
            }
        case .mac:
            return .fileProviderGeneric
        default:
            return .fileProviderGeneric
        }
    }
}
