//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension DatabaseIconSet {
    var assetPath: String {
        switch self {
        case .keepassium:
            return "db-icons/keepassium"
        case .keepass:
            return "db-icons/keepass"
        case .keepassxc:
            return "db-icons/keepassxc"
        }
    }

    public func getIcon(_ iconID: IconID) -> UIImage? {
        let name = String(format: "%@/%02d", assetPath, iconID.rawValue)
        return UIImage(named: name)?.withRenderingMode(renderingMode)
    }

    public var renderingMode: UIImage.RenderingMode {
        switch self {
        case .keepassium:
            return .alwaysTemplate
        case .keepass, .keepassxc:
            return .alwaysOriginal
        }
    }
}
