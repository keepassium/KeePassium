//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

class HapticFeedback {
    enum Kind {
        case appUnlocked
        case databaseUnlocked
        case contextMenuOpened
        case copiedToClipboard
        case credentialsPasted
        case wrongPassword
        case error
        case qrCodeScanned
        case passwordGenerated
        case deviceShaken
    }

    static func play(_ kind: Kind) {
        guard Settings.current.isHapticFeedbackEnabled else { return }

        switch kind {
        case .appUnlocked,
             .databaseUnlocked,
             .contextMenuOpened,
             .passwordGenerated:
            let tactileGenerator = UIImpactFeedbackGenerator()
            tactileGenerator.impactOccurred()
        case .copiedToClipboard:
            let tactileGenerator = UISelectionFeedbackGenerator()
            tactileGenerator.selectionChanged()
        case .credentialsPasted:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.success)
        case .wrongPassword:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.warning)
        case .error:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.warning)
        case .qrCodeScanned:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.success)
        case .deviceShaken:
            let tactileGenerator = UINotificationFeedbackGenerator()
            tactileGenerator.notificationOccurred(.warning)
        }
    }

}
