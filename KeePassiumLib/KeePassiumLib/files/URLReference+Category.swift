//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

extension URLReference {

    struct Category {
        static let startDatabase = Self("startupDatabase")
        static let freemiumDocumentsDir = Self("documentsDirURLReference")
        static let proDocumentsDir = Self("documentsDirURLReferencePro")

        static var documentsDir: Self {
            if BusinessModel.type == .prepaid {
                return proDocumentsDir
            } else {
                return freemiumDocumentsDir
            }
        }

        public let rawValue: String

        private static var mainAppPrefix: String {
            if BusinessModel.type == .prepaid {
                return "com.keepassium.pro.recentFiles"
            } else {
                return "com.keepassium.recentFiles"
            }
        }

        private static var autoFillExtensionPrefix: String {
            if FileKeeper.platformSupportsSharedReferences {
                return mainAppPrefix
            }

            if BusinessModel.type == .prepaid {
                return "com.keepassium.pro.autoFill.recentFiles"
            } else {
                return "com.keepassium.autoFill.recentFiles"
            }
        }

        private static let internalDatabases = ".internal.databases"
        private static let internalKeyFiles = ".internal.keyFiles"
        private static let externalDatabases = ".external.databases"
        private static let externalKeyFiles = ".external.keyFiles"

        private init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        init(for fileType: FileType, external isExternal: Bool, autoFill: Bool = !AppGroup.isMainApp) {
            let suffix: String
            switch fileType {
            case .database:
                suffix = isExternal ? Self.externalDatabases : Self.internalDatabases
            case .keyFile:
                suffix = isExternal ? Self.externalKeyFiles : Self.internalKeyFiles
            }

            let prefix = autoFill ? Self.autoFillExtensionPrefix : Self.mainAppPrefix
            self.init(prefix + suffix)
        }
    }
}
