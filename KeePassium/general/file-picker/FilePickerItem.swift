//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

enum FilePickerItem: Hashable {
    case announcement(_ item: AnnouncementItem)
    case noFile(_ item: TitleImage)
    case file(_ item: FileInfo)

    struct TitleImage: Hashable {
        var title: String
        var subtitle: String?
        var image: UIImage?
    }

    struct FileInfo: Hashable {
        private(set) weak var source: URLReference?
        var uuid: UUID
        var fileName: String
        var fileType: FileType
        var iconSymbol: SymbolName?
        var errorMessage: String?
        var modifiedDate: Date?
        var isBusy: Bool

        init(source: URLReference, fileType: FileType) {
            self.source = source
            let fileInfo = source.getCachedInfoSync(canFetch: false)
            self.uuid = source.runtimeUUID
            self.fileName = source.visibleFileName
            self.fileType = fileType
            self.iconSymbol = source.getIconSymbol(fileType: fileType)
            self.errorMessage = source.error?.localizedDescription
            self.modifiedDate = fileInfo?.modificationDate
            self.isBusy = source.isRefreshingInfo
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .announcement(item):
            hasher.combine(item)
        case let .noFile(item):
            hasher.combine(item)
        case let .file(item):
            hasher.combine(item.uuid)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case let (.announcement(item1), .announcement(item2)):
            return item1 == item2
        case let (.file(item1), .file(item2)):
            return item1.uuid == item2.uuid
        case let (.noFile(item1), .noFile(item2)):
            return item1 == item2
        default:
            return false
        }
    }
}
