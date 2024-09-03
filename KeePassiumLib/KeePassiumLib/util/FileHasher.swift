//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import CryptoKit

final class FileHasher {
    private static let chunkSize = 65536

    public static func sha256(fileURL: URL) throws -> SHA256Digest {
        assert(!Thread.isMainThread)
        assert(fileURL.isFileURL)
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        var hasher = SHA256()
        var isDone = false
        repeat {
            try autoreleasepool {
                if let chunk = try fileHandle.read(upToCount: chunkSize),
                   !chunk.isEmpty
                {
                    hasher.update(data: chunk)
                } else {
                    isDone = true
                }
            }
        } while !isDone
        let digest = hasher.finalize()
        return digest
    }
}

public extension SHA256Digest {
    var asHexString: String {
        self.map { String(format: "%02hhx", $0) }.joined()
    }
}
