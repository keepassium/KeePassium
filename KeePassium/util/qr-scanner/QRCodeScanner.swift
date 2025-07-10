//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 12.03.2021.

import AVFoundation
import KeePassiumLib
import PhotosUI
import UniformTypeIdentifiers
#if INTUNE
import IntuneMAMSwift
#endif

enum QRCodeSource {
    case camera
    case imageLibrary
    case files
}

final class QRCodeScanner {
    public typealias Completion = (Result<String?, QRScannerError>) -> Void

    private var photoPicker: PhotoPicker?
    private var fileImportHelper: FileImportHelper?

    public func getSupportedSources() -> Set<QRCodeSource> {
        var result = Set<QRCodeSource>()
        if CameraPhotoPicker.isAllowed(),
           AVCaptureDevice.default(for: .video) != nil
        {
            result.insert(.camera)
        }
        if GalleryPhotoPicker.isAllowed() {
            result.insert(.imageLibrary)
        }
        if isLocalStorageAllowed() {
            result.insert(.files)
        }
        return result
    }

    public func pickQRCode(source: QRCodeSource, presenter: UIViewController, completion: @escaping Completion) {
        guard getSupportedSources().contains(source) else {
            Diag.error("QR code scanning from \(source) is either not supported by this device or not allowed by organization policies.")
            completion(.failure(.imageSourceNotAvailable))
            return
        }

        switch source {
        case .camera:
            scanQRCode(presenter: presenter, completion: completion)
        case .imageLibrary:
            pickQRCodeFromGallery(presenter: presenter, completion: completion)
        case .files:
            pickQRCodeFromFiles(presenter: presenter, completion: completion)
        }
    }

    private func scanQRCode(presenter: UIViewController, completion: @escaping Completion) {
        assert(Thread.isMainThread)

        Diag.debug("Initializing QR code scanner")
        let scannerVC = QRCodeScannerVC()
        scannerVC.completion = { [weak scannerVC] result in
            scannerVC?.dismiss(animated: true) {
                switch result {
                case .success(let qrCode):
                    completion(.success(qrCode))
                case .failure(let scannerError):
                    completion(.failure(scannerError))
                }
            }
        }

        presenter.present(scannerVC, animated: true)
    }

    private func pickQRCodeFromGallery(presenter: UIViewController, completion: @escaping Completion) {
        let picker = GalleryPhotoPicker()
        self.photoPicker = picker

        picker.pickImage(from: presenter) { [weak self] result in
            self?.photoPicker = nil

            switch result {
            case .success(let result):
                guard let image = result?.image else {
                    Diag.debug("Photo picking cancelled, aborting.")
                    completion(.success(nil))
                    return
                }
                self?.detectQRCode(in: image, completion: completion)
            case .failure(let error):
                Diag.error("Photo picking failed [message: \(error.localizedDescription)]")
                completion(.failure(.other(error)))
            }
        }
    }

    private func pickQRCodeFromFiles(presenter: UIViewController, completion: @escaping Completion) {
        fileImportHelper = FileImportHelper()
        fileImportHelper?.handler = { [weak self] url in
            self?.fileImportHelper = nil

            guard let url else {
                Diag.debug("File picking cancelled, aborting.")
                completion(.success(nil))
                return
            }

            #if INTUNE
            let accountID = IntuneMAMEnrollmentManager.instance().enrolledAccountId()
            if let policy = IntuneMAMPolicyManager.instance().policy(forAccountId: accountID) {
                guard policy.canReceiveSharedFile(url.path()) else {
                    Diag.error("File path is blocked by Intune policy")
                    completion(.failure(.other(FileAccessError.managedAccessDenied)))
                    return
                }
            }
            #endif
            assert(url.isFileURL, "This method can handle only file URLs")
            guard let image = UIImage(contentsOfFile: url.path()) else {
                Diag.error("Cannot read the selected file as an image.")
                completion(.failure(.imageCorrupted))
                return
            }
            self?.detectQRCode(in: image, completion: completion)
        }
        fileImportHelper?.importFile(contentTypes: [.image], presenter: presenter)
    }

    private func detectQRCode(in image: UIImage, completion: @escaping Completion) {
        guard let ciImage = CIImage(image: image) else {
            Diag.error("Cannot convert UIImage to CIImage for QR code detection.")
            completion(.failure(.internalError))
            return
        }

        guard let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        ) else {
            Diag.error("Cannot create QR code detector.")
            completion(.failure(.internalError))
            return
        }

        let features = detector.features(in: ciImage) as? [CIQRCodeFeature]

        guard let firstFeature = features?.first,
              let qrCodeString = firstFeature.messageString,
              !qrCodeString.isEmpty
        else {
            Diag.debug("No QR code found in the image.")
            completion(.failure(.noQRCodeFound))
            return
        }

        Diag.debug("QR code detected.")
        completion(.success(qrCodeString))
    }
}

extension QRCodeScanner {
    func isLocalStorageAllowed() -> Bool {
        #if INTUNE
        let accountID = IntuneMAMEnrollmentManager.instance().enrolledAccountId()
        if let policy = IntuneMAMPolicyManager.instance().policy(forAccountId: accountID) {
            guard policy.isOpenFromAllowed(for: .localStorage, withAccountId: accountID) else {
                Diag.error("Local storage is blocked by Intune policy")
                return false
            }
        }
        #endif
        guard FileProvider.localStorage.isAllowed else {
            Diag.error("System file providers are blocked by organization policy")
            return false
        }
        return true
    }
}
