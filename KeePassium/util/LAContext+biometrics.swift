//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication

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

    var symbolName: SymbolName? {
        switch self {
        case .faceID:
            return SymbolName.faceID
        case .touchID:
            return SymbolName.touchID
        default:
            return nil
        }
    }
}
