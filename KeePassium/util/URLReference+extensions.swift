//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
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
        case .external:
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
        if _fileProvider == .localStorage,
            let _fileInfo = self.getCachedInfoSync(canFetch: false),
            _fileInfo.isInTrash
        {
            return UIImage(asset: .databaseTrashedListitem)
        }
        return _fileProvider.icon ?? UIImage(asset: .fileProviderGenericListitem)
    }
}
