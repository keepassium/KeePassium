//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class AppGroup {
    public static let id = "group.com.keepassium"
    
    public static let appURLScheme = "keepassium"
    
    public static let upgradeToPremiumURL = URL(string: appURLScheme + ":upgradeToPremium")! 
    
    public static var isMainApp: Bool {
        return applicationShared != nil
    }
    
    public static weak var applicationShared: UIApplication?
}
