//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension URLReference {

    func getIconSymbol(fileType: FileType) -> SymbolName? {
        switch fileType {
        case .database:
            return getDatabaseIconSymbol()
        case .keyFile:
            return .keyFile
        }
    }

    private func getDatabaseIconSymbol() -> SymbolName? {
        switch self.location {
        case .external, .remote:
            return getExternalDatabaseIconSymbol()
        case .internalDocuments, .internalInbox:
            return FileProvider.getLocalStorageIconSymbol()
        case .internalBackup:
            return .clockArrowCirclepath
        }
    }

    private func getExternalDatabaseIconSymbol() -> SymbolName {
        guard let fileProvider else {
            return .fileProviderGeneric
        }

        if let fileInfo = self.getCachedInfoSync(canFetch: false),
           fileInfo.isInTrash
        {
            return .trash
        }
        return fileProvider.iconSymbol ?? .fileProviderGeneric
    }

    public func getLocationDescription() -> String {
        var components = [String]()
        switch location {
        case .remote:
            if let description = url?.getRemoteLocationDescription() {
                components.append(description)
            } else {
                components.append(url?.absoluteString ?? "")
            }
        case .external:
            if ProcessInfo.isRunningOnMac, let url = self.url {
                return url.path
            }
            guard let fileProvider = self.fileProvider else {
                return location.description 
            }
            components.append(fileProvider.localizedName)
            let isInTrash = getCachedInfoSync(canFetch: false)?.isInTrash
            if isInTrash ?? false {
                components.append(LString.trashDirectoryName)
            }
        case .internalDocuments,
             .internalBackup,
             .internalInbox:
            if ProcessInfo.isRunningOnMac, let url = self.url {
                return url.path
            }
            if let fileProvider = self.fileProvider {
                components.append(fileProvider.localizedName)
            }
            components.append(AppInfo.name)
            components.append(location.description)
        }
        return components.joined(separator: " → ")
    }
}
