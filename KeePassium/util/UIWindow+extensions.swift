//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIWindow {

    func setScreen(_ screen: UIScreen) {
        #if !targetEnvironment(macCatalyst)
        self.screen = screen
        #endif
    }

    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }

    func findFirstResponder() -> UIResponder? {
        return findFirstResponder(in: self)
    }

    private func findFirstResponder(in view: UIView) -> UIResponder? {
        for subview in view.subviews {
            if subview.isFirstResponder {
                return subview
            }

            if let responder = findFirstResponder(in: subview) {
                return responder
            }
        }
        return nil
    }
}
