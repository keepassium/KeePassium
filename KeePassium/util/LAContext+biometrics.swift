//  KeePassium Password Manager
//  Copyright © 2018–2023 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import LocalAuthentication
import KeePassiumLib

extension LAContext {
    public static func getBiometryType() -> LABiometryType {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.canEvaluatePolicy(policy, error: nil)
        return context.biometryType
    }
    
    public static func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        let canUseBiometrics = context.canEvaluatePolicy(policy, error: nil)
        return canUseBiometrics
    }
}

extension LABiometryType {
    var name: String? {
        switch self {
        case .touchID:
            return LString.biometricsTypeTouchID
        case .faceID:
            return LString.biometricsTypeFaceID
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
