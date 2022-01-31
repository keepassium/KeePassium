//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum IconID: UInt32 {
    public static let all: [IconID] = [
        .key, .globe, .warning, .server, .folderMark, .user, .pie_chart, .notepad, .globeSocket,
        .businessCard, .sheetStar, .camera, .wifi, .keys, .plug, .scanner, .globeStar, .opticalDisc,
        .display, .envelopeOpen, .gear, .clipboardMark, .sheet, .window, .socketLightning,
        .folderEnvelope, .floppy, .networkFolder, .video_player, .terminal, .windowConsole,
        .printer, .windowIcons, .startFlag, .wrench, .computerGlobe, .archive, .percent,
        .networkFolderWindows, .clock, .envelopeSearch, .flag, .chip, .trashBin, .note, .x,
        .question, .box, .folder, .folderOpen, .folderBox, .lockOpen, .sheetLock, .checkmark,
        .pen, .photo, .book, .list, .userKey, .hammer, .home, .star, .tux, .feather, .apple,
        .wiki, .currency, .certificate, .phone]
    
    public static let withZeroID: IconID = .key
    
    case key              =  0
    case globe            =  1
    case warning          =  2
    case server           =  3
    case folderMark       =  4
    case user             =  5
    case pie_chart        =  6
    case notepad          =  7
    case globeSocket      =  8
    case businessCard     =  9
    case sheetStar        = 10
    case camera           = 11
    case wifi             = 12
    case keys             = 13
    case plug             = 14
    case scanner          = 15
    case globeStar        = 16
    case opticalDisc      = 17
    case display          = 18
    case envelopeOpen     = 19
    case gear             = 20
    case clipboardMark    = 21
    case sheet            = 22
    case window           = 23
    case socketLightning  = 24
    case folderEnvelope   = 25
    case floppy           = 26
    case networkFolder    = 27
    case video_player     = 28
    case terminal         = 29
    case windowConsole    = 30
    case printer          = 31
    case windowIcons      = 32
    case startFlag        = 33
    case wrench           = 34
    case computerGlobe    = 35
    case archive          = 36
    case percent          = 37
    case networkFolderWindows = 38
    case clock            = 39
    case envelopeSearch   = 40
    case flag             = 41
    case chip             = 42
    case trashBin         = 43
    case note             = 44
    case x                = 45
    case question         = 46
    case box              = 47
    case folder           = 48
    case folderOpen       = 49
    case folderBox        = 50
    case lockOpen         = 51
    case sheetLock        = 52
    case checkmark        = 53
    case pen              = 54
    case photo            = 55
    case book             = 56
    case list             = 57
    case userKey          = 58
    case hammer           = 59
    case home             = 60
    case star             = 61
    case tux              = 62
    case feather          = 63
    case apple            = 64
    case wiki             = 65
    case currency         = 66
    case certificate      = 67
    case phone            = 68
    init?(_ string: String?) {
        guard let raw = UInt32(string) else { return nil }
        self.init(rawValue: raw)
    }
}
