//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices

final public class QuickTypeAutoFillRecord {
    private static let separator: Character = ":"

    private let formatVersion: Int
    public let fileProvider: FileProvider
    public let fileDescriptor: URLReference.Descriptor
    public let itemID: UUID
    public var recordIdentifier: String { toString() }

    convenience init(context: DatabaseFile, itemID: UUID) {
        self.init(
            fileProvider: context.fileProvider ?? .other(id: ""),
            fileDescriptor: context.descriptor!,
            itemID: itemID
        )
    }

    private init(fileProvider: FileProvider, fileDescriptor: URLReference.Descriptor, itemID: UUID) {
        self.formatVersion = 0
        self.fileProvider = fileProvider
        self.fileDescriptor = fileDescriptor
        self.itemID = itemID
    }

    public func toString() -> String {
        assert(formatVersion == 0, "Unexpected format version")
        let parts = [String(formatVersion), fileProvider.rawValue, fileDescriptor, itemID.uuidString]
        return parts.joined(separator: String(QuickTypeAutoFillRecord.separator))
    }

    public static func parse(_ string: String) -> QuickTypeAutoFillRecord? {
        let parts = string.split(separator: QuickTypeAutoFillRecord.separator)
        guard parts.count == 4 else {
            return nil
        }
        guard let formatVersion = Int(parts[0]) else {
            return nil
        }
        guard formatVersion == 0 else {
            Diag.warning("Unexpected format version, ignoring")
            assertionFailure()
            return nil
        }
        let fileProvider = FileProvider(rawValue: String(parts[1]))
        let fileDescriptor = String(parts[2])
        guard let itemID = UUID(uuidString: String(parts[3])) else {
            assertionFailure("Failed to parse UUID")
            return nil
        }
        return QuickTypeAutoFillRecord(
            fileProvider: fileProvider,
            fileDescriptor: fileDescriptor,
            itemID: itemID
        )
    }
}
