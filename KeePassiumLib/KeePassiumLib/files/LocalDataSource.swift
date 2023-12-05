//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public final class LocalDataSource: DataSource {

    public static var urlSchemePrefix: String?
    public static var urlSchemes: [String] = ["file"]

    func getAccessCoordinator() -> FileAccessCoordinator {
        return NSFileCoordinator()
    }

    public func readFileInfo(
        at url: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<FileInfo>
    ) {
        if let inputStream = InputStream(url: url) {
            defer {
                inputStream.close()
            }
            var dummyBuffer = [UInt8](repeating: 0, count: 8)
            inputStream.read(&dummyBuffer, maxLength: dummyBuffer.count)
        } else {
            Diag.warning("Failed to fetch the file")
        }
        url.readLocalFileInfo(
            canUseCache: canUseCache,
            completionQueue: completionQueue,
            completion: completion
        )
    }

    public func read(
        _ url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ByteArray>
    ) {
        do {
            let fileData = try ByteArray(contentsOf: url, options: [.uncached, .mappedIfSafe])
            completionQueue.addOperation {
                completion(.success(fileData))
            }
        } catch {
            Diag.error("Failed to read file [message: \(error.localizedDescription)]")
            let fileAccessError = FileAccessError.systemError(error)
            completionQueue.addOperation {
                completion(.failure(fileAccessError))
            }
        }
    }

    public func write(
        _ data: ByteArray,
        to url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    ) {
        do {
            try data.write(to: url, options: [])
            completionQueue.addOperation {
                completion(.success)
            }
        } catch {
            Diag.error("Failed to write file [message: \(error.localizedDescription)")
            let fileAccessError = FileAccessError.systemError(error)
            completionQueue.addOperation {
                completion(.failure(fileAccessError))
            }
        }
    }
}
