//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 12.03.2021.

import AVFoundation
import KeePassiumLib

final class QRCodeScanner {
    var deviceSupportsQRScanning: Bool {
        return AVCaptureDevice.default(for: .video) != nil
    }

    func scanQRCode(presenter: UIViewController, completion: @escaping (Result<String, QRScannerError>) -> Void) {
        assert(Thread.isMainThread)
        guard deviceSupportsQRScanning else {
            Diag.error("QR code scanning not supported on this device.")
            completion(.failure(.noCameraDevice))
            return
        }

        Diag.debug("Initializing internal QR code scanner")
        let scannerVC = QRCodeScannerVC()
        scannerVC.completion = { [weak scannerVC] result in
            scannerVC?.dismiss(animated: true) {
                switch result {
                case .success(let qrCode):
                    completion(.success(qrCode))
                case .failure(let scannerError):
                    if case QRScannerError.userCancelled = scannerError {
                        return
                    }
                    completion(.failure(scannerError))
                }
            }
        }

        presenter.present(scannerVC, animated: true)
    }
}
