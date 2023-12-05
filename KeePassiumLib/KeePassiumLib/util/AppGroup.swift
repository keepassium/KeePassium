//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class AppGroup {
    public static var id: String = {
        if BusinessModel.isIntuneEdition {
            return "group.com.keepassium.intune"
        } else {
            return "group.com.keepassium"
        }
    }()

    public static let appURLScheme: String = {
        if BusinessModel.isIntuneEdition {
            return "keepassium.org"
        }
        switch BusinessModel.type {
        case .freemium:
            return "keepassium"
        case .prepaid:
            return "keepassium.pro"
        }
    }()

    public static let upgradeToPremiumURL = URL(string: appURLScheme + "://upgradeToPremium")! 

    public static let donateURL = URL(string: appURLScheme + "://donate")! 

    public static var isMainApp: Bool {
        return applicationShared != nil
    }

    public static var isAppExtension: Bool {
        return !isMainApp
    }

    public static weak var applicationShared: UIApplication?
}
