//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class HapticFeedback {
    enum Kind {
        case appUnlocked
        case databaseUnlocked
        case wrongPassword
        case error
    }
    
    static func play(_ kind: Kind) {
        guard Settings.current.isHapticFeedbackEnabled else { return }
        
        switch kind {
        case .appUnlocked, .databaseUnlocked:
            let tactileGenerator = UIImpactFeedbackGenerator()
            tactileGenerator.impactOccurred()
        case .wrongPassword:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.warning)
        case .error:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.warning)
        }
    }
    
}

