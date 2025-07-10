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

final class CameraPhotoPicker: PhotoPicker {
    let imagePicker = UIImagePickerController()

    override init() {
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = false
        imagePicker.imageExportPreset = .compatible
        imagePicker.modalPresentationStyle = .overFullScreen

        super.init()
        imagePicker.delegate = self
    }

    override func _pickImageInternal() {
        _presenter?.present(imagePicker, animated: true, completion: nil)
    }

    override class func isAllowed() -> Bool {
        #if INTUNE
        let accountID = IntuneMAMEnrollmentManager.instance().enrolledAccountId()
        if let policy = IntuneMAMPolicyManager.instance().policy(forAccountId: accountID) {
            guard policy.isOpenFromAllowed(for: .camera, withAccountId: accountID) else {
                Diag.error("Gallery is blocked by Intune policy")
                return false
            }
        }
        #endif
        return true
    }
}

extension CameraPhotoPicker: UIImagePickerControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        imagePicker.dismiss(animated: true) { [weak self] in
            let pickedImage = PhotoPickerImage.from(info)
            self?._completion?(.success(pickedImage))
        }
    }
}

extension CameraPhotoPicker: UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        _completion?(.success(nil))
    }
}
