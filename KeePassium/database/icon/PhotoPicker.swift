//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.
//
//  Created by Igor Kulman on 19.03.2021.

import Foundation
import KeePassiumLib
import PhotosUI

struct PhotoPickerImage {
    var image: UIImage
    var name: String?

    public static func from(_ info: [UIImagePickerController.InfoKey: Any]) -> PhotoPickerImage? {
        guard let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage
        else {
            return nil
        }
        let imageURL = info[UIImagePickerController.InfoKey.imageURL] as? URL
        return PhotoPickerImage(image: originalImage, name: imageURL?.lastPathComponent)
    }

    public static func from(_ image: UIImage?, name: String?) -> PhotoPickerImage? {
        guard let image = image else {
            return nil
        }
        return PhotoPickerImage(image: image, name: name)
    }
}

typealias PhotoPickerCompletion = (Result<PhotoPickerImage?, Error>) -> Void

protocol PhotoPicker {
    func pickImage(from viewController: UIViewController, completion: @escaping PhotoPickerCompletion)
}

final class PhotoPickerFactory {

    static func makePhotoPicker() -> PhotoPicker {
        return PHPickerViewControllerPhotoPicker()
    }

    static func makeCameraPhotoPicker() -> PhotoPicker {
        return UIImagePickerControllerPhotoPicker(sourceType: .camera)
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

    init(sourceType: UIImagePickerController.SourceType) {
        imagePicker.sourceType = sourceType
        imagePicker.allowsEditing = false
        imagePicker.imageExportPreset = .compatible
        if sourceType == .camera {
            imagePicker.modalPresentationStyle = .overFullScreen
        } else {
            imagePicker.modalPresentationStyle = .overCurrentContext
        }

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
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        imagePicker.dismiss(animated: true) { [weak self] in
            let pickedImage = PhotoPickerImage.from(info)
            self?.completion?(.success(pickedImage))
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        completion?(.success(nil))
    }
}

private final class PHPickerViewControllerPhotoPicker:
    NSObject,
    PhotoPicker,
    PHPickerViewControllerDelegate,
    UIAdaptivePresentationControllerDelegate
{
    let picker: PHPickerViewController
    var viewController: UIViewController?
    var completion: PhotoPickerCompletion?

    override init() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        picker = PHPickerViewController(configuration: configuration)
        super.init()

        picker.delegate = self
        picker.presentationController?.delegate = self
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

            let pickedImage = PhotoPickerImage.from(
                image as? UIImage,
                name: result.itemProvider.suggestedName
            )
            DispatchQueue.main.async { [weak self] in
                self?.viewController?.dismiss(animated: true) { [weak self] in
                    self?.completion?(.success(pickedImage))
                }
            }
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        completion?(.success(nil))
    }
}
