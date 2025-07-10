//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public enum DatabaseIconSet: Int, CaseIterable {
    case sfSymbols = 3
    case keepassium = 0
    case keepass = 1
    case keepassxc = 2

    public var title: String {
        switch self {
        case .sfSymbols:
            return LString.titleDatabaseIconSetSystem
        case .keepassium:
            return "KeePassium" 
        case .keepass:
            return "KeePass" 
        case .keepassxc:
            return "KeePassXC" 
        }
    }
}

extension LString {
    public static let titleDatabaseIconSetSystem = NSLocalizedString(
        "[Database/IconSet/System/title]",
        bundle: Bundle.framework,
        value: "System",
        comment: "Title of an icon collection: icons provided by the system"
    )
}
