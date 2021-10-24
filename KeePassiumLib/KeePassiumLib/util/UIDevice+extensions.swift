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
        let keyWindow = AppGroup.applicationShared?.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let keyWindow = keyWindow else {
            return false
        }
        return keyWindow.safeAreaInsets.bottom.isZero
        #endif
    }
}
