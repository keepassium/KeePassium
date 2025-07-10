//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

public extension LString {
    static let qrScannerCallToAction = NSLocalizedString(
        "[QRCodeScanner/Info/callToAction]",
        bundle: Bundle.main,
        value: "Point the camera at a QR code.",
        comment: "Call to action/instruction for QR code scanner.")

    static let qrScannerCameraPermissionDescription = NSLocalizedString(
        "[QRCodeScanner/CameraPermission/description]",
        bundle: Bundle.main,
        value: "KeePassium needs camera access to scan QR codes.",
        comment: "Explanation why the app needs camera access permission.")
}
