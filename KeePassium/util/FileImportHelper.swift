//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UniformTypeIdentifiers

final class FileImportHelper: NSObject {
    var handler: ((_ selectedURL: URL?) -> Void)?

    public func importFile(
        contentTypes: [UTType],
        presenter viewController: UIViewController
    ) {
        assert(handler != nil, "The `handler` callback must be defined for processing user choice")

        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        documentPicker.delegate = self
        documentPicker.modalPresentationStyle = .formSheet
        viewController.present(documentPicker, animated: true)
    }
}

extension FileImportHelper: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        handler?(nil)
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else {
            Diag.warning("No file selected")
            handler?(nil)
            return
        }
        handler?(url)
    }
}
