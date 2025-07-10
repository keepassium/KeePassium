//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class KPApplication: UIApplication {

    override func sendEvent(_ event: UIEvent) {
        super.sendEvent(event)

        switch event.type {
        case .touches:
            guard let allTouches = event.allTouches else { return }
            if allTouches.contains(where: { $0.phase == .began }) {
                Watchdog.shared.restart()
            }
        case .scroll:
            Watchdog.shared.restart()
        default:
            return
        }
    }
}
