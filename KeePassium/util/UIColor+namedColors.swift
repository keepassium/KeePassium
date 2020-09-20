//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIColor {
    
    static var actionTint: UIColor {
        return UIColor(named: "ActionTint") ?? UIColor.systemBlue
    }
    static var actionText: UIColor {
        return UIColor(named: "ActionText") ?? .white
    }
    static var iconTint: UIColor {
        return UIColor(named: "iconTint") ?? UIColor.systemBlue
    }
    static var destructiveTint: UIColor {
        return UIColor(named: "DestructiveTint") ?? UIColor.systemRed
    }
    static var destructiveText: UIColor {
        return UIColor(named: "DestructiveText") ?? .white
    }
    static var highlightTint: UIColor {
        return UIColor(named: "HighlightTint") ?? UIColor.systemRed
    }
    static var highglightText: UIColor {
        return UIColor(named: "HighlightText") ?? .white
    }
    static var errorMessage: UIColor {
        return UIColor.systemRed
    }
    static var primaryText: UIColor {
        return UIColor(named: "PrimaryText") ?? .black
    }
    static var auxiliaryText: UIColor {
        return UIColor(named: "AuxiliaryText") ?? .darkGray
    }
    static var disabledText: UIColor {
        return UIColor(named: "DisabledText") ?? .darkGray
    }
    static var passwordLetters: UIColor {
        return primaryText
    }
    static var passwordDigits: UIColor {
        return UIColor(named: "PasswordDigits") ?? .systemBlue
    }
    static var passwordSymbols: UIColor {
        return UIColor(named: "PasswordSymbols") ?? .systemRed
    }


    
    static let mfiKeyActionSheetIdleColor: UIColor = .white
    
    static let mfiKeyActionSheetTouchColor =
        UIColor(red: 186/255, green: 233/255, blue: 80/255, alpha: 1)
    
    static let mfiKeyActionSheetProcessingColor =
        UIColor(red: 118/255, green: 214/255, blue: 255/255, alpha: 1)

    
    static let systemRed = UIColor(red: 255/255, green: 59/255, blue: 48/255, alpha: 1)
    static let systemOrange = UIColor(red: 255/255, green: 149/255, blue: 0/255, alpha: 1)
    static let systemYellow = UIColor(red: 255/255, green: 204/255, blue: 0/255, alpha: 1)
    static let systemGreen = UIColor(red: 76/255, green: 217/255, blue: 100/255, alpha: 1)
    static let systemTealBlue = UIColor(red: 90/255, green: 200/255, blue: 250/255, alpha: 1)
    static let systemBlue = UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1)
    static let systemPurple = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1)
    static let systemPink = UIColor(red: 255/255, green: 45/255, blue: 85/255, alpha: 1)
}
