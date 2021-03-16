//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 12.03.2021.

import Foundation
import KeePassiumLib

protocol QRCodeScanner: AnyObject {
    var deviceSupportsQRScanning: Bool { get }

    func scanQRCode(presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void)
}

final class YubiKitQRCodeScanner: QRCodeScanner {
    var deviceSupportsQRScanning: Bool {
        return YubiKitDeviceCapabilities.supportsQRCodeScanning
    }

    private let session = YKFQRReaderSession()

    func scanQRCode(presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void) {
        Diag.debug("Showing QR code scanner")

        session.scanQrCode(withPresenter: presenter) { (data, error) in
            if let error = error {
                Diag.error("Scanning QR code failed [message: \(error.localizedDescription)]")
                HapticFeedback.play(.error)
                completion(.failure(error))
                return
            }

            if let data = data {
                Diag.debug("QR code scanning successful")
                HapticFeedback.play(.qrCodeScanned)
                completion(.success(data))
                return
            }

            Diag.error("Invalid state with no data and no error")
            assertionFailure()
        }
    }
}
