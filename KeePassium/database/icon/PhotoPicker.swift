//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 19.03.2021.

import Foundation
import PhotosUI
import KeePassiumLib

typealias PhotoPickerCompletion = (Result<UIImage?, Error>) ->Void

protocol PhotoPicker {
    func pickImage(from viewController: UIViewController, completion: @escaping PhotoPickerCompletion)
}

final class PhotoPickerFactory {

    static func makePhotoPicker() -> PhotoPicker {
        if #available(iOS 14, *) {
            return PHPickerViewControllerPhotoPicker()
        } else {
            return UIImagePickerControllerPhotoPicker()
        }
    }
}

private final class UIImagePickerControllerPhotoPicker:
    NSObject,
    PhotoPicker,
    UIImagePickerControllerDelegate & UINavigationControllerDelegate
{
    var viewController: UIViewController?
    var completion: PhotoPickerCompletion?
    let imagePicker = UIImagePickerController()

    override init() {
        imagePicker.sourceType = .savedPhotosAlbum
        imagePicker.allowsEditing = false
        imagePicker.modalPresentationStyle = .overCurrentContext

        super.init()
        imagePicker.delegate = self
    }

    func pickImage(
        from viewController: UIViewController,
        completion: @escaping PhotoPickerCompletion
    ) {
        self.viewController = viewController
        self.completion = completion

        viewController.present(imagePicker, animated: true, completion: nil)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
    {
        imagePicker.dismiss(animated: true) { [weak self] in
            self?.completion?(.success(info[UIImagePickerController.InfoKey.originalImage] as? UIImage))
        }
    }
}

@available(iOS 14, *)
private final class PHPickerViewControllerPhotoPicker: PhotoPicker, PHPickerViewControllerDelegate {
    let picker: PHPickerViewController
    var viewController: UIViewController?
    var completion: PhotoPickerCompletion?

    init() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
    }

    func pickImage(
        from viewController: UIViewController,
        completion: @escaping PhotoPickerCompletion
    ) {
        self.viewController = viewController
        self.completion = completion

        viewController.present(picker, animated: true, completion: nil)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first,
              result.itemProvider.canLoadObject(ofClass: UIImage.self)
        else {
            viewController?.dismiss(animated: true) { [weak self] in
                self?.completion?(.success(nil))
            }
            return
        }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            if let error = error {
                Diag.error("Picking icon with PHPickerViewController failed [message: \(error.localizedDescription)]")
                DispatchQueue.main.async { [weak self] in
                    self?.viewController?.dismiss(animated: true) { [weak self] in
                        self?.completion?(.failure(error))
                    }
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.viewController?.dismiss(animated: true) { [weak self] in
                    self?.completion?(.success(image as? UIImage))
                }
            }
        }
    }
}
