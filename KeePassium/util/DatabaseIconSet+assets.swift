//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension DatabaseIconSet {

    public func getIcon(_ iconID: IconID) -> UIImage? {
        let assetPath: String
        switch self {
        case .keepassium:
            assetPath = "db-icons/keepassium"
        case .keepass:
            assetPath = "db-icons/keepass"
        case .keepassxc:
            assetPath = "db-icons/keepassxc"
        case .sfSymbols:
            return UIImage(systemName: iconID.sfSymbolName) ?? UIImage(named: iconID.sfSymbolName)
        }
        let name = String(format: "%@/%02d", assetPath, iconID.rawValue)
        return UIImage(named: name)?.withRenderingMode(renderingMode)
    }

    public var renderingMode: UIImage.RenderingMode {
        switch self {
        case .keepassium:
            return .alwaysTemplate
        case .keepass, .keepassxc:
            return .alwaysOriginal
        case .sfSymbols:
            return .alwaysTemplate
        }
    }
}

fileprivate extension IconID {
    var sfSymbolName: String {
        switch self {
        case .key:
            return "key"
        case .globe:
            return "globe"
        case .warning:
            return "exclamationmark.triangle"
        case .server:
            return "server.rack"
        case .folderMark:
            return "checkmark.square"
        case .user:
            return "bubble.left"
        case .pie_chart:
            return "chart.pie"
        case .notepad:
            return "note.text"
        case .globeSocket:
            return "network"
        case .businessCard:
            return "person.text.rectangle"
        case .sheetStar:
            return "text.badge.star"
        case .camera:
            return "camera"
        case .wifi:
            return "wifi"
        case .keys:
            return "key.diagonal"
        case .plug:
            return "powerplug"
        case .scanner:
            return "scanner"
        case .globeStar:
            return "star.circle"
        case .opticalDisc:
            return "opticaldisc"
        case .display:
            return "display"
        case .envelopeOpen:
            return "envelope.open"
        case .gear:
            return "gearshape"
        case .clipboardMark:
            return "list.clipboard"
        case .sheet:
            return "clipboard"
        case .window:
            return "macwindow"
        case .socketLightning:
            return "bolt"
        case .folderEnvelope:
            return "envelope.badge"
        case .floppy:
            return "sdcard"
        case .networkFolder:
            return "externaldrive.connected.to.line.below"
        case .video_player:
            return "play.square"
        case .terminal:
            return "lock.display"
        case .windowConsole:
            return "terminal"
        case .printer:
            return "printer"
        case .windowIcons:
            return "square.grid.2x2"
        case .startFlag:
            return "flag.checkered"
        case .wrench:
            return "wrench"
        case .computerGlobe:
            return "rectangle.connected.to.line.below"
        case .archive:
            return "archivebox"
        case .percent:
            return "percent"
        case .networkFolderWindows:
            return "squareshape.split.2x2"
        case .clock:
            return "clock"
        case .envelopeSearch:
            return "rectangle.and.text.magnifyingglass"
        case .flag:
            return "flag"
        case .chip:
            return "memorychip"
        case .trashBin:
            return "trash"
        case .note:
            return "note"
        case .x:
            return "xmark"
        case .question:
            return "questionmark"
        case .box:
            return "shippingbox"
        case .folder:
            return "folder"
        case .folderOpen:
            return "folder.fill"
        case .folderBox:
            return "folder.badge.gearshape"
        case .lockOpen:
            return "lock.open"
        case .sheetLock:
            return "lock.square"
        case .checkmark:
            return "checkmark"
        case .pen:
            return "pencil"
        case .photo:
            return "photo.artframe"
        case .book:
            return "book"
        case .list:
            return "list.bullet.rectangle"
        case .userKey:
            return "person.badge.key"
        case .hammer:
            return "hammer"
        case .home:
            return "house"
        case .star:
            return "star"
        case .tux:
            return "triangle"
        case .feather:
            return "leaf"
        case .apple:
            return "applelogo"
        case .wiki:
            return "w.square"
        case .currency:
            return "dollarsign.circle"
        case .certificate:
            return "creditcard"
        case .phone:
            return "iphone"
        }
    }
}
