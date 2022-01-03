//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

internal final class DataSourceFactory {
    
    public static func getDataSource(for url: URL) -> DataSource {
        guard let urlSchemePrefix = url.schemePrefix else {
            return LocalDataSource()
        }
        
        switch urlSchemePrefix {
        case WebDAVDataSource.urlSchemePrefix:
            return WebDAVDataSource()
        default:
            Diag.warning("Unexpected URL scheme prefix [prefix: \(urlSchemePrefix)]")
            return LocalDataSource()
        }
    }
    
    public static func findFileProvider(for url: URL) -> FileProvider? {
        switch url.schemePrefix {
        case WebDAVDataSource.urlSchemePrefix:
            return .keepassiumWebDAV
        default:
            return nil
        }
    }
}
