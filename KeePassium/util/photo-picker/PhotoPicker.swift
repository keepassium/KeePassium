//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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
        guard let image else {
            return nil
        }
        return PhotoPickerImage(image: image, name: name)
    }
}

typealias PhotoPickerCompletion = (Result<PhotoPickerImage?, Error>) -> Void

class PhotoPicker: NSObject {
    internal weak var _presenter: UIViewController?
    internal var _completion: PhotoPickerCompletion?

    public func pickImage(from viewController: UIViewController, completion: @escaping PhotoPickerCompletion) {
        _presenter = viewController
        _completion = completion
        if Self.isAllowed() {
            _pickImageInternal()
        } else {
            viewController.showManagedFeatureBlockedNotification()
        }
    }

    class func isAllowed() -> Bool {
        fatalError("Pure abstract method, override it")
    }

    internal func _pickImageInternal() {
        fatalError("Pure abstract method, override it")
    }
}
