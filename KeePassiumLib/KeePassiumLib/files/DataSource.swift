//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public typealias FileOperationResult<T> = Result<T, FileAccessError>
public typealias FileOperationCompletion<T> = (FileOperationResult<T>) -> Void

protocol DataSource {

    func getAccessCoordinator() -> FileAccessCoordinator

    func readFileInfo(
        at url: URL,
        fileProvider: FileProvider?,
        canUseCache: Bool,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<FileInfo>
    )

    func read(
        _ url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<ByteArray>
    )

    func write(
        _ data: ByteArray,
        to url: URL,
        fileProvider: FileProvider?,
        timeout: Timeout,
        queue: OperationQueue,
        completionQueue: OperationQueue,
        completion: @escaping FileOperationCompletion<Void>
    )
}
