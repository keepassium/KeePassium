//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

public struct FileInfo: Equatable {
    public typealias Attributes = [Attribute: Bool?]
    public typealias ContentHash = String

    public var fileName: String
    public var fileSize: Int64?
    public var creationDate: Date?
    public var modificationDate: Date?
    public var attributes = Attributes()
    public var isHidden: Bool?
    public var isInTrash: Bool
    public var hash: ContentHash?

    public init(
        fileName: String,
        fileSize: Int64? = nil,
        creationDate: Date? = nil,
        modificationDate: Date? = nil,
        attributes: Attributes = [:],
        isInTrash: Bool,
        hash: ContentHash?
    ) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.attributes = attributes
        self.isInTrash = isInTrash
        self.hash = hash
    }

    public static func == (lhs: FileInfo, rhs: FileInfo) -> Bool {
        return lhs.fileName == rhs.fileName
            && lhs.fileSize == rhs.fileSize
            && lhs.creationDate == rhs.creationDate
            && lhs.modificationDate == rhs.modificationDate
            && lhs.isInTrash == rhs.isInTrash
            && lhs.attributes.allSatisfy { rhs.attributes[$0.key] == $0.value }
            && lhs.hash == rhs.hash
    }
}

extension FileInfo {
    public enum Attribute: String, CaseIterable {
        case excludedFromBackup
        case hidden

        public var title: String {
            switch self {
            case .excludedFromBackup:
                LString.titleExcludeFromBackup
            case .hidden:
                LString.titleHiddenFileAttribute
            }
        }

        public var asURLResourceKey: URLResourceKey {
            switch self {
            case .excludedFromBackup:
                return .isExcludedFromBackupKey
            case .hidden:
                return .isHiddenKey
            }
        }
        public func fromURLResourceValues(_ resourceValues: URLResourceValues?) -> Bool? {
            switch self {
            case .excludedFromBackup:
                return resourceValues?.isExcludedFromBackup
            case .hidden:
                return resourceValues?.isHidden
            }
        }
        public func apply(_ value: Bool, to resourceValues: inout URLResourceValues) {
            switch self {
            case .excludedFromBackup:
                resourceValues.isExcludedFromBackup = value
            case .hidden:
                resourceValues.isHidden = value
            }
        }
    }
}
