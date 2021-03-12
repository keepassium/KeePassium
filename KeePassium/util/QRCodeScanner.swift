//
//  QRCodeScanner.swift
//  KeePassium
//
//  Created by Igor Kulman on 12.03.2021.
//  Copyright © 2021 Andrei Popleteev. All rights reserved.
//

import Foundation
import KeePassiumLib

protocol QRCodeScanner: AnyObject {
    var deviceSupportsQRScanning: Bool { get }

    func scanQrCode(presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void)
}

final class YubiKitQRCodeScanner: QRCodeScanner {
    var deviceSupportsQRScanning: Bool {
        return YubiKitDeviceCapabilities.supportsQRCodeScanning
    }

    private let session = YKFQRReaderSession()

    func scanQrCode(presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void) {
        Diag.debug("Showing QR code scanner")

        session.scanQrCode(withPresenter: presenter) { (data, error) in
            if let error = error {
                Diag.error("Scaning QR code failed with \(error)")
                completion(.failure(error))
                return
            }

            if let data = data {
                Diag.debug("QR code scanning successful")
                completion(.success(data))
                return
            }

            Diag.error("Invalid state with no data and no error")
        }
    }
}
