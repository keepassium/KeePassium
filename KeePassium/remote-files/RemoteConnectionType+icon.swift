//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension RemoteConnectionType {
    public var iconSymbol: SymbolName? {
        switch self {
        case .webdav:
            return FileProvider.keepassiumWebDAV.iconSymbol
        case .oneDrive,
             .oneDriveForBusiness:
            return FileProvider.keepassiumOneDrive.iconSymbol
        }
    }
}
