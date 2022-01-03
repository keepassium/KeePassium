//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension URLReference {
    
    func getIcon(fileType: FileType) -> UIImage? {
        switch fileType {
        case .database:
            return getDatabaseIcon()
        case .keyFile:
            return UIImage(asset: .keyFileListitem)
        }
    }
    
    private func getDatabaseIcon() -> UIImage {
        switch self.location {
        case .external,
             .remote:
            return getExternalDatabaseIcon()
        case .internalDocuments, .internalInbox:
            if UIDevice.current.userInterfaceIdiom == .pad {
                return UIImage(asset: .fileProviderOnMyIPadListitem)
            }
            if UIDevice.current.hasHomeButton() {
                return UIImage(asset: .fileProviderOnMyIPhoneListitem)
            } else {
                return UIImage(asset: .fileProviderOnMyIPhoneXListitem)
            }
        case .internalBackup:
            return UIImage(asset: .databaseBackupListitem)
        }
    }
    
    private func getExternalDatabaseIcon() -> UIImage {
        guard let _fileProvider = fileProvider else {
            return UIImage(asset: .fileProviderGenericListitem)
        }
        if let _fileInfo = self.getCachedInfoSync(canFetch: false),
           _fileInfo.isInTrash
        {
            return UIImage(asset: .databaseTrashedListitem)
        }
        return _fileProvider.icon ?? UIImage(asset: .fileProviderGenericListitem)
    }

    public func getLocationDescription() -> String {
        if ProcessInfo.isRunningOnMac, let url = self.url {
            return url.path
        }
        
        guard let fileProvider = self.fileProvider else {
            return location.description 
        }
        
        var components = [String]()
        switch location {
        case .remote:
            components.append(fileProvider.localizedName)
            if let url = url {
                components.append(url.absoluteString)
            }
        case .external:
            components.append(fileProvider.localizedName)
            let isInTrash = getCachedInfoSync(canFetch: false)?.isInTrash
            if isInTrash ?? false {
                components.append(LString.trashDirectoryName)
            }
        case .internalDocuments,
             .internalBackup,
             .internalInbox:
            components.append(fileProvider.localizedName)
            components.append(AppInfo.name)
            components.append(location.description)
        }
        return components.joined(separator: " → ")
    }
}
