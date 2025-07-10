//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import PhotosUI
#if INTUNE
import IntuneMAMSwift
#endif

final class GalleryPhotoPicker: PhotoPicker {
    let picker: PHPickerViewController

    override init() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        picker = PHPickerViewController(configuration: configuration)
        super.init()

        picker.delegate = self
        picker.presentationController?.delegate = self
    }

    override internal func _pickImageInternal() {
        _presenter?.present(picker, animated: true, completion: nil)
    }

    override class func isAllowed() -> Bool {
        #if INTUNE
        let accountID = IntuneMAMEnrollmentManager.instance().enrolledAccountId()
        if let policy = IntuneMAMPolicyManager.instance().policy(forAccountId: accountID) {
            guard policy.isOpenFromAllowed(for: .photos, withAccountId: accountID) else {
                Diag.error("Gallery is blocked by Intune policy")
                return false
            }
        }
        #endif
        return true
    }
}

extension GalleryPhotoPicker: UIAdaptivePresentationControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first,
              result.itemProvider.canLoadObject(ofClass: UIImage.self)
        else {
            _presenter?.dismiss(animated: true) { [weak self] in
                self?._completion?(.success(nil))
            }
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) {
            [weak self, weak itemProvider = result.itemProvider] image, error in
            assert(!Thread.isMainThread)
            guard let self else { return }
            if let error {
                Diag.error("Picking image with PHPickerViewController failed [message: \(error.localizedDescription)]")
                DispatchQueue.main.async { [weak self] in
                    self?._presenter?.dismiss(animated: true) { [weak self] in
                        self?._completion?(.failure(error))
                    }
                }
                return
            }
            #if INTUNE
            let accountID = IntuneMAMEnrollmentManager.instance().enrolledAccountId()
            if let policy = IntuneMAMPolicyManager.instance().policy(forAccountId: accountID) {
                guard let itemProvider,
                      policy.canReceiveSharedItemProvider(itemProvider)
                else {
                    Diag.error("Gallery is blocked by Intune policy")
                    DispatchQueue.main.async { [weak self] in
                        self?._presenter?.dismiss(animated: true) { [weak self] in
                            self?._completion?(.failure(FileAccessError.managedAccessDenied))
                        }
                    }
                    return
                }
            }
            #endif

            let pickedImage = PhotoPickerImage.from(
                image as? UIImage,
                name: result.itemProvider.suggestedName
            )
            DispatchQueue.main.async { [weak self] in
                self?._presenter?.dismiss(animated: true) { [weak self] in
                    self?._completion?(.success(pickedImage))
                }
            }
        }
    }
}

extension GalleryPhotoPicker: PHPickerViewControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        _completion?(.success(nil))
    }
}
