//
//  QRCodeScanner.swift
//  KeePassium
//
//  Created by Igor Kulman on 12.03.2021.
//  Copyright © 2021 Andrei Popleteev. All rights reserved.
//

import Foundation

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
        session.scanQrCode(withPresenter: presenter) { (data, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let data = data {
                completion(.success(data))
                return
            }

            print("Invalid state with no data and no error")
        }
    }
}
