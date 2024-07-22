//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public final class DatabaseReloadContext: Eraseable {
    public let compositeKey: CompositeKey
    public var groupUUID: UUID?

    public convenience init(for database: Database) {
        self.init(key: database.compositeKey.clone())
    }

    public init(key: CompositeKey) {
        self.compositeKey = key
    }

    deinit {
        erase()
    }

    public func erase() {
        compositeKey.erase()
        groupUUID?.erase()
    }
}
