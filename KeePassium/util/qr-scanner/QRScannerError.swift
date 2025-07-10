//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import AVFoundation
import KeePassiumLib

enum QRScannerError: LocalizedError {
    case imageSourceNotAvailable
    case cameraBusy
    case imageCorrupted
    case internalError
    case noQRCodeFound
    case other(Error)

    var errorDescription: String? {
        switch self {
        case .imageSourceNotAvailable:
            return NSLocalizedString(
                "[QRCodeScanner/Error/SourceNoAvailable]",
                bundle: Bundle.main,
                value: "Image source is not available.",
                comment: "Error message when camera/gallery/etc is either missing or forbidden.")
        case .cameraBusy:
            return NSLocalizedString(
                "[QRCodeScanner/Error/CameraBusy]",
                bundle: Bundle.main,
                value: "Camera is already in use.",
                comment: "Error message when the app cannot use the camera.")
        case .imageCorrupted:
            return NSLocalizedString(
                "[QRCodeScanner/Error/ImageCorrupted]",
                bundle: Bundle.main,
                value: "Selected image is corrupted.",
                comment: "Error message")
        case .internalError:
            return NSLocalizedString(
                "[QRCodeScanner/Error/Internal]",
                bundle: Bundle.main,
                value: "Internal error in QR code reader. Check diagnostic log for details.",
                comment: "Error message with a suggested action.")
        case .noQRCodeFound:
            return NSLocalizedString(
                "[QRCodeScanner/Error/NoQRCodeFound]",
                bundle: Bundle.main,
                value: "Looks like there’s no QR code in that image.",
                comment: "Notification message")
        case .other(let systemError):
            return systemError.localizedDescription
        }
    }
}
