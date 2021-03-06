//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension UIWindow {
    
    func setScreen(_ screen: UIScreen) {
        #if !targetEnvironment(macCatalyst)
        self.screen = screen
        #endif
    }
}
