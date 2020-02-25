//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public enum ChallengeResponseError: LocalizedError {
    case notSupportedByDeviceOrSystem(interface: String)
    case notSupportedByDatabaseFormat
    case notAvailableInAutoFill
    case keyNotConnected
    case keyNotConfigured
    
    case cancelled
    
    case communicationError(message: String)
    
    
    public var errorDescription: String? {
        switch self {
        case .notSupportedByDeviceOrSystem(let interface):
            return String.localizedStringWithFormat(
                NSLocalizedString(
                    "[ChallengeResponseError] notSupportedByDeviceOrSystem",
                    bundle: Bundle.framework,
                    value: "This device or iOS version does not support hardware keys (%@)",
                    comment: "Error message when trying to use a hardware challenge-response key on unsupported device/iOS version. %@ will be the name of the hardware interface, such as `NFC` or `Lightning`."),
                interface)
        case .notSupportedByDatabaseFormat:
            return NSLocalizedString(
                "[ChallengeResponseError] notSupportedByDatabaseFormat",
                bundle: Bundle.framework,
                value: "Hardware keys are not supported by this database format.",
                comment: "Error message when trying to use challenge-response with a kdb database.")
        case .notAvailableInAutoFill:
            return NSLocalizedString(
                "[ChallengeResponseError] notAvailableInAutoFill",
                bundle: Bundle.framework,
                value: "Hardware keys are not available in AutoFill.",
                comment: "Error message when trying to use challenge-response hardware in AutoFill.")
        case .keyNotConnected:
            return NSLocalizedString(
                "[ChallengeResponseError] keyNotConnected",
                bundle: Bundle.framework,
                value: "Hardware key is not connected.",
                comment: "Error message when the hardware key is not plugged in.")
        case .keyNotConfigured:
            return NSLocalizedString(
                "[ChallengeResponseError] slotNotConfigured",
                bundle: Bundle.framework,
                value: "Hardware key is not configured for challenge-response.",
                comment: "Error message: the hardware key (or its slot) was not configured for challenge-response operations.")
        case .cancelled:
            return NSLocalizedString(
                "[ChallengeResponseError] cancelled",
                bundle: Bundle.framework,
                value: "Cancelled by the user.",
                comment: "Error message when the challenge-response communication has been cancelled by the user.")
        case .communicationError(let message):
            return message
        }
    }
}

public typealias ChallengeHandler =
    (_ challenge: SecureByteArray, _ responseHandler: @escaping ResponseHandler) -> Void

public typealias ResponseHandler =
    (_ response: SecureByteArray, _ error: ChallengeResponseError?) -> Void
