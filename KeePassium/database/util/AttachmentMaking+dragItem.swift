//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UniformTypeIdentifiers

extension AttachmentMaking {
    typealias DropHandler = (Result<Attachment, FileAccessError>) -> Void

    func makeAttachment(
        from dragItem: UIDragItem,
        completion: @escaping DropHandler
    ) {
        let timeout = Timeout(duration: URLReference.defaultTimeoutDuration)
        let completionQueue = OperationQueue.main
        createURLReference(from: dragItem) { refResult in
            switch refResult {
            case .success(let fileRef):
                FileDataProvider.read(fileRef, timeout: timeout) { result in
                    switch result {
                    case .success(let fileData):
                        Diag.debug("Dropped file loaded [size: \(fileData.count)]")
                        let attachment = makeAttachment(name: fileRef.visibleFileName, data: fileData)
                        completionQueue.addOperation { completion(.success(attachment)) }
                    case .failure(let fileAccessError):
                        Diag.error("Failed to load dropped file [error: \(fileAccessError)]")
                        completionQueue.addOperation { completion(.failure(fileAccessError)) }
                    }
                }
            case .failure(let fileAccessError):
                completionQueue.addOperation { completion(.failure(fileAccessError)) }
            }
        }
    }

    private func createURLReference(
        from dragItem: UIDragItem,
        completion: @escaping URLReference.CreateCallback
    ) {
        let completionQueue = OperationQueue.main
        dragItem.itemProvider.loadInPlaceFileRepresentation(forTypeIdentifier: UTType.item.identifier) {
            fileURL, _, error in
            if let error {
                Diag.error("Failed to load dropped file [error: \(error.localizedDescription)]")
                completionQueue.addOperation { completion(.failure(.systemError(error))) }
                return
            }
            guard let fileURL else {
                Diag.error("Dropped file URL is nil")
                assertionFailure()
                completionQueue.addOperation { completion(.failure(.internalError)) }
                return
            }
            URLReference.create(for: fileURL, location: .external, completion: completion)
        }
    }
}
