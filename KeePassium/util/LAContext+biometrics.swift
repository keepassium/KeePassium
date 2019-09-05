//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import LocalAuthentication
import UIKit

extension LAContext {
    public static func getBiometryType() -> LABiometryType {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.canEvaluatePolicy(policy, error: nil)
        return context.biometryType
    }
}

extension LABiometryType {
    var name: String? {
        switch self {
        case .touchID:
            return NSLocalizedString(
                "[BiometricAuthType] Touch ID",
                value: "Touch ID",
                comment: "Name of biometric authentication method. Trademarked, do not translate unless Apple traslated it to your language.")
        case .faceID:
            return NSLocalizedString(
                "[BiometricAuthType] Face ID",
                value: "Face ID",
                comment: "Name of biometric authentication method. Trademarked, do not translate unless Apple traslated it to your language.")
        default:
            return nil
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .faceID:
            return UIImage(asset: .biometryFaceIDListitem)
        case .touchID:
            return UIImage(asset: .biometryTouchIDListitem)
        default:
            return nil
        }
    }
}
