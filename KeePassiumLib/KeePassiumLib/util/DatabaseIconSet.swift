//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


public enum DatabaseIconSet: Int {
    public static let allValues = [keepassium, keepass, keepassxc]
    case keepassium
    case keepass
    case keepassxc
    
    public var title: String {
        switch self {
        case .keepassium:
            return "KeePassium" 
        case .keepass:
            return "KeePass" 
        case .keepassxc:
            return "KeePassXC" 
        }
    }
}
