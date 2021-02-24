//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum FileProvider: Hashable {

    private static let providerByID: [String: FileProvider] = [
        "com.apple.FileProvider.LocalStorage": .localStorage,
        "it.ideasolutions.amerigo.FileExtension": .amerigo,
        "it.ideasolutions.amerigo-free.FileExtension": .amerigoFree,
        "net.box.BoxNet.documentPickerFileProvider": .box,
        "com.boxcryptor.ios.BoxcryptorDocumentProviderFileProvider": .boxcryptor,
        "com.getdropbox.Dropbox.FileProvider": .dropbox,
        "com.skyjos.fileexplorer.fileprovider": .feFileExplorer,
        "com.google.Drive.FileProviderExtension": .googleDrive,
        "com.apple.CloudDocs.MobileDocumentsFileProvider": .iCloudDrive,
        "it.twsweb.Nextcloud.File-Provider-Extension": .nextcloud,
        "com.microsoft.skydrive.onedrivefileprovider": .oneDrive,
        "com.owncloud.ios-app.ownCloud-File-Provider": .ownCloud,
        "com.pcloud.pcloud.FileProvider": .pCloud,
        "com.qnap.qfile.FileProvider": .qnapQFile,
        "com.readdle.ReaddleDocsIPad.DocsExtFileProvider": .readdleDocuments,
        "com.resilio.sync.fileprovider": .resilioSync,
        "com.seafile.seafilePro.SeafFileProvider": seafilePro,
        "com.apple.SMBClientProvider.FileProvider": .smbShare,
        "com.stratospherix.filebrowser.DocumentProviderFileProvider": .stratospherixFileBrowser,
        "com.sync.mobileapp.NewFileProvider": .syncCom,
        "com.synology.DSdrive.FileProvider": .synologyDrive,
        "com.synology.DSfile.ExtFileProvider": .synologyDSfile,
        "com.tresorit.ios.TresoritiOS-DocumentProviderFileProvider": .tresorit,
        "com.apple.filesystems.UserFS.FileProvider": .usbDrive,
        "ru.yandex.disk.filesext": .yandexDisk
    ]
    private static let idByProvider: [FileProvider: String] =
            Dictionary(uniqueKeysWithValues: FileProvider.providerByID.map { ($1, $0) })

    case amerigo
    case amerigoFree
    case box
    case boxcryptor
    case dropbox
    case feFileExplorer
    case googleDrive
    case iCloudDrive
    case nextcloud
    case oneDrive
    case ownCloud
    case pCloud
    case qnapQFile
    case readdleDocuments
    case resilioSync
    case seafilePro
    case smbShare
    case stratospherixFileBrowser
    case syncCom
    case synologyDrive
    case synologyDSfile
    case tresorit
    case usbDrive
    case yandexDisk
    
    case localStorage
    case other(id: String)
    
    public var rawValue: String { return id }
    
    public var id: String {
        switch self {
        case .other(let id):
            return id
        default:
            return FileProvider.idByProvider[self]!
        }
    }
    
    public init(rawValue: String) {
        if let provider = FileProvider.providerByID[rawValue] {
            self = provider
        } else {
            self = .other(id: rawValue)
        }
    }
    
    public var localizedName: String {
        switch self {
        case .amerigoFree: fallthrough
        case .amerigo:
            return NSLocalizedString(
                "[FileProvider/Amerigo/name]",
                bundle: Bundle.framework,
                value: "Amerigo",
                comment: "Localized name of the storage service: Amerigo (https://www.amerigo-app.com)")
        case .box:
            return NSLocalizedString(
                "[FileProvider/Box/name]",
                bundle: Bundle.framework,
                value: "Box",
                comment: "Localized name of the storage service: Box (https://box.com)")
        case .boxcryptor:
            return NSLocalizedString(
                "[FileProvider/Boxcryptor/name]",
                bundle: Bundle.framework,
                value: "Boxcryptor",
                comment: "Localized name of the storage service: Boxcryptor (https://boxcryptor.com)")
        case .dropbox:
            return NSLocalizedString(
                "[FileProvider/Dropbox/name]",
                bundle: Bundle.framework,
                value: "Dropbox",
                comment: "Localized name of the storage service: Dropbox (https://dropbox.com)")
        case .feFileExplorer:
            return NSLocalizedString(
                "[FileProvider/FE File Explorer/name]",
                bundle: Bundle.framework,
                value: "FE File Explorer",
                comment: "Localized name of the storage service: FE File Explorer (https://apps.apple.com/app/fe-file-explorer-file-manager/id510282524)")
        case .googleDrive:
            return NSLocalizedString(
                "[FileProvider/Google Drive/name]",
                bundle: Bundle.framework,
                value: "Google Drive",
                comment: "Localized name of the storage service: Google Drive (https://drive.google.com)")
        case .iCloudDrive:
            return NSLocalizedString(
                "[FileProvider/iCloud Drive/name]",
                bundle: Bundle.framework,
                value: "iCloud Drive",
                comment: "Localized name of the storage service iCloud Drive (https://icloud.com/iclouddrive)")
        case .nextcloud:
            return NSLocalizedString(
                "[FileProvider/Nextcloud/name]",
                bundle: Bundle.framework,
                value: "Nextcloud",
                comment: "Localized name of the storage service: Nextcloud (https://nextcloud.com)")
        case .oneDrive:
            return NSLocalizedString(
                "[FileProvider/OneDrive/name]",
                bundle: Bundle.framework,
                value: "OneDrive",
                comment: "Localized name of the storage service: OneDrive (https://onedrive.com)")
        case .ownCloud:
            return NSLocalizedString(
                "[FileProvider/ownCloud/name]",
                bundle: Bundle.framework,
                value: "ownCloud",
                comment: "Localized name of the storage service: ownCloud (https://owncloud.com)")
        case .pCloud:
            return NSLocalizedString(
                "[FileProvider/pCloud/name]",
                bundle: Bundle.framework,
                value: "pCloud",
                comment: "Localized name of the storage service: pCloud (https://pcloud.com)")
        case .qnapQFile:
            return NSLocalizedString(
                "[FileProvider/qnapQFile/name]",
                bundle: Bundle.framework,
                value: "Qfile",
                comment: "Localized name of the storage service: QNAP Qfile (https://apps.apple.com/app/qfile/id526330408)")
        case .readdleDocuments:
            return NSLocalizedString(
                "[FileProvider/Readdle Documents/name]",
                bundle: Bundle.framework,
                value: "Documents by Readdle",
                comment: "Localized name of the storage service: Documents by Readdle (https://apps.apple.com/app/id364901807)")
        case .resilioSync:
            return NSLocalizedString(
                "[FileProvider/Resilio Sync/name]",
                bundle: Bundle.framework,
                value: "Resilio Sync",
                comment: "Localized name of the storage service: Resilio Sync (https://https://apps.apple.com/us/app/id1126282325)")
        case .seafilePro:
            return NSLocalizedString(
                "[FileProvider/Seafile Pro/name]",
                bundle: Bundle.framework,
                value: "Seafile Pro",
                comment: "Localized name of the storage app: Seafile Pro (https://apps.apple.com/us/app/seafile-pro/id639202512)")
        case .smbShare:
            return NSLocalizedString(
                "[FileProvider/SMB/name]",
                bundle: Bundle.framework,
                value: "SMB server",
                comment: "Localized name of the storage service: SMB server (network share) via native iOS integration.")
        case .stratospherixFileBrowser:
            return NSLocalizedString(
                "[FileProvider/Stratospherix FileBrowser/name]",
                bundle: Bundle.framework,
                value: "FileBrowser",
                comment: "Localized name of the storage service: Stratospherix FileBrowser (https://apps.apple.com/us/app/filebrowser-document-manager/id364738545)")
        case .syncCom:
            return NSLocalizedString(
                "[FileProvider/sync.com/name]",
                bundle: Bundle.framework,
                value: "Sync.com",
                comment: "Localized name of the storage service: Sync.com (https://sync.com)")
        case .synologyDrive:
            return NSLocalizedString(
                "[FileProvider/Synology Drive/name]",
                bundle: Bundle.framework,
                value: "Synology Drive",
                comment: "Localized name of the storage service: Synology Drive (https://apps.apple.com/us/app/synology-drive/id1267275421)")
        case .synologyDSfile:
            return NSLocalizedString(
                "[FileProvider/Synology DS file/name]",
                bundle: Bundle.framework,
                value: "Synology DS file",
                comment: "Localized name of the storage service: Synology DS file (https://apps.apple.com/us/app/ds-file/id416751772)")
        case .tresorit:
            return NSLocalizedString(
                "[FileProvider/Tresorit/name]",
                bundle: Bundle.framework,
                value: "Tresorit",
                comment: "Localized name of the storage service: Tresorit (https://tresorit.com)")
        case .usbDrive:
            return NSLocalizedString(
                "[FileProvider/USB drive/name]",
                bundle: Bundle.framework,
                value: "USB drive",
                comment: "Localized name of the storage service: local USB drive (native iOS integration)")
        case .yandexDisk:
            return NSLocalizedString(
                "[FileProvider/Yandex.Disk/name]",
                bundle: Bundle.framework,
                value: "Yandex.Disk",
                comment: "Localized name of the storage service: Yandex.Disk (https://disk.yandex.com)")
        case .localStorage:
            return getLocalStorageName()
        case .other(let id):
            return id
        }
    }
    
    private func getLocalStorageName() -> String {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            return NSLocalizedString(
                "[FileProvider/On My iPhone/name]",
                bundle: Bundle.framework,
                value: "On My iPhone",
                comment: "Localized name of the local on-device storage, as shown in the Files app.")
        }
        
        if ProcessInfo.isRunningOnMac {
            return "macOS" 
        } else {
            return NSLocalizedString(
                "[FileProvider/On My iPad/name]",
                bundle: Bundle.framework,
                value: "On My iPad",
                comment: "Localized name of the local on-device storage, as shown in the Files app.")
        }

    }
}
