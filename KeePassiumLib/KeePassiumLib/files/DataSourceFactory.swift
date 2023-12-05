//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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

        if url.isWebDAVFileURL {
            return WebDAVDataSource()
        } else if url.isOneDriveFileURL {
            return OneDriveDataSource()
        } else {
            Diag.warning("Unexpected URL format, assuming local file [prefix: \(urlSchemePrefix)]")
            return LocalDataSource()
        }
    }

    public static func findInAppFileProvider(for url: URL) -> FileProvider? {
        if url.isWebDAVFileURL {
            return .keepassiumWebDAV
        } else if url.isOneDriveFileURL {
            return .keepassiumOneDrive
        }
        return nil
    }
}
