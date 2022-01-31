//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
        let windows = AppGroup.applicationShared?
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let keyWindow = windows?.first(where: { $0.isKeyWindow }) else {
            return false
        }
        return keyWindow.safeAreaInsets.bottom.isZero
        #endif
    }
}
