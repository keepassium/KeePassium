//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIApplication {

    var currentScene: UIWindowScene? {
        connectedScenes
            .first { $0.activationState == .foregroundActive }
            as? UIWindowScene
    }

    public func getKeyWindow() -> UIWindow? {
        return windows.first { $0.isKeyWindow }
    }
}
