//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

enum BiometricsHelper {
    public static var biometricPromptLastSeenTime = Date.distantPast
    private static let biometricPromptFadeDuration = 1.0

    public static var delayBeforeKeyboardAvailable: TimeInterval {
        let result: TimeInterval
        let timeSinceBiometricPromptSeen = -biometricPromptLastSeenTime.timeIntervalSinceNow
        if timeSinceBiometricPromptSeen > biometricPromptFadeDuration {
            result = 0.0
        } else {
            result = biometricPromptFadeDuration - timeSinceBiometricPromptSeen
        }
        return result
    }
}
