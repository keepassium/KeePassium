//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIDevice {
    
    public func hasHomeButton() -> Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        if #available(iOS 11.0, *) {
            guard let keyWindow = AppGroup.applicationShared?.keyWindow else {
                return false
            }
            return keyWindow.safeAreaInsets.bottom.isZero
        }
        return true
        #endif
    }
}
