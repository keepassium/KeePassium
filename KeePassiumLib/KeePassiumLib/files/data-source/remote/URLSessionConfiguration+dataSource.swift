//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension URLSessionConfiguration {
    static var forRemoteDataSource: URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.allowsCellularAccess = true
        config.multipathServiceType = .none
        config.waitsForConnectivity = false
        config.urlCache = nil
        config.requestCachePolicy = .reloadRevalidatingCacheData
        return config
    }
}
