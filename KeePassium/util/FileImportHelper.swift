//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UniformTypeIdentifiers
#if INTUNE
import IntuneMAMSwift
#endif

final class FileImportHelper: NSObject {
    var handler: ((_ selectedURL: URL?) -> Void)?

    public func importFile(
        contentTypes: [UTType],
        presenter viewController: UIViewController
    ) {
        assert(handler != nil, "The `handler` callback must be defined for processing user choice")

        guard ManagedAppConfig.shared.areSystemFileProvidersAllowed else {
            Diag.error("Import from local file system is forbidden by organizational policy.")
            viewController.showManagedFeatureBlockedNotification()
            return
        }
        #if INTUNE
        let accountID = IntuneMAMEnrollmentManager.instance().enrolledAccountId()
        if let policy = IntuneMAMPolicyManager.instance().policy(forAccountId: accountID) {
            guard policy.isDocumentPickerAllowed(.import) else {
                Diag.error("Document picker is blocked by Intune policy.")
                IntuneMAMUIHelper.showSharingBlockedMessage { [weak self] in
                    self?.handler?(nil)
                }
                return
            }
        }
        #endif
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
