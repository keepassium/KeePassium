//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AVFoundation
import KeePassiumLib

enum QRScannerError: LocalizedError {
    case noCameraDevice
    case cameraBusy
    case userCancelled
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .noCameraDevice:
            return NSLocalizedString(
                "[QRCodeScanner/Error/NoCameraDevice]",
                bundle: Bundle.main,
                value: "No camera device found.",
                comment: "Error message when no camera is available for QR scanning.")
        case .cameraBusy:
            return NSLocalizedString(
                "[QRCodeScanner/Error/CameraBusy]",
                bundle: Bundle.main,
                value: "Camera is already in use.",
                comment: "Error message when the app cannot use the camera.")
        case .userCancelled:
            return NSLocalizedString(
                "[QRCodeScanner/Error/UserCancelled]",
                bundle: Bundle.main,
                value: "QR code scanning was cancelled by the user.",
                comment: "Error message when user cancels QR code scanning.")
        case .other(let systemError):
            return systemError.localizedDescription
        }
    }
}
