//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum UnreachableFileFallbackStrategy: Int, Codable, CaseIterable {
    case showError = 0
    case useCache = 1
    
    public var title: String {
        switch self {
        case .showError:
            return LString.titleIfFileUnreachableShowError
        case .useCache:
            return LString.titleIfFileUnreachableUseCache
        }
    }
}
