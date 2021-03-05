//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class TemporaryFileURL {
    public private(set) var url: URL
    
    private var isErased = false
    
    public init(fileName: String) throws {
        let fileManager = FileManager.default
        let tmpFileDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        url = tmpFileDir.appendingPathComponent(fileName, isDirectory: false)
        do {
            try fileManager.createDirectory(
                at: tmpFileDir,
                withIntermediateDirectories: true,
                attributes: nil)
        } catch {
            Diag.error("Failed to create temporary file [error: \(error.localizedDescription)]")
            throw error
        }
    }
    
    deinit {
        cleanup()
    }
    
    public func cleanup() {
        guard !isErased else {
            return
        }
        Diag.verbose("Will remove temporary file")
        try? FileManager.default.removeItem(at: url)
        isErased = true
        Diag.debug("Temporary file removed")
    }
}
