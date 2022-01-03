//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

protocol FileAccessCoordinator {
    func coordinate(
        with intents: [NSFileAccessIntent],
        queue: OperationQueue,
        byAccessor accessor: @escaping (Error?) -> Void
    )
    func cancel()
}

class PassthroughFileAccessCoordinator: FileAccessCoordinator {
    func coordinate(
        with intents: [NSFileAccessIntent],
        queue: OperationQueue,
        byAccessor accessor: @escaping (Error?) -> Void
    ) {
        queue.addOperation {
            accessor(nil)
        }
    }
    func cancel() {
    }
}

extension NSFileCoordinator: FileAccessCoordinator {
}
