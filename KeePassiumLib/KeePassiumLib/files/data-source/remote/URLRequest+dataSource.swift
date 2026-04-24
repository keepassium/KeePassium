//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension URLRequest.CachePolicy {
    static let forAuth: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    static let forMetaInfo: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    static let forContent: URLRequest.CachePolicy = .reloadRevalidatingCacheData
}

extension URLRequest {
    init(url: URL, cachePolicy: CachePolicy, timeout: Timeout) {
        self.init(
            url: url,
            cachePolicy: cachePolicy,
            timeoutInterval: timeout.remainingTimeInterval
        )
        attribution = .developer
    }
}
