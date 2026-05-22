//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UIKit

extension DatabaseViewerCoordinator {
    func _canDropFiles(_ files: [UIDragItem], onto entry: Entry, in viewController: GroupViewerVC) -> Bool {
        let permissions = DatabaseViewerPermissionManager.getPermissions(for: entry, in: _databaseFile)
        guard permissions.contains(.editItem) else {
            return false
        }
        return entry.canAcceptNewAttachments(count: files.count)
    }

    func _didDropFiles(_ droppedFiles: [UIDragItem], onto entry: Entry, in viewController: GroupViewerVC) {
        Diag.debug("Will add \(droppedFiles.count) dropped file(s) to entry")
        showProgressView(
            title: LString.statusLoadingAttachmentFile,
            allowCancelling: false,
            animated: true)

        let dispatchGroup = DispatchGroup()
        var loadedAttachments = [Attachment]()
        var failedAttachmentCount = 0
        for droppedFile in droppedFiles {
            dispatchGroup.enter()
            _database.makeAttachment(from: droppedFile) { result in
                assert(Thread.isMainThread)
                switch result {
                case .success(let attachment):
                    loadedAttachments.append(attachment)
                case .failure:
                    failedAttachmentCount += 1
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self else { return }
            guard loadedAttachments.count > 0 else {
                Diag.debug("No attachments loaded, aborting")
                hideProgressView(animated: true)
                DispatchQueue.main.async { [weak self] in
                    self?._showDroppedAttachmentsFailure()
                }
                return
            }

            _addAttachments(loadedAttachments, to: entry)
            Diag.debug("Incoming attachments added, saving database")

            if failedAttachmentCount > 0 {
                Diag.warning("Some incoming attachments failed to load (\(failedAttachmentCount) of \(droppedFiles.count))")
                _showDroppedAttachmentsFailure()
            }

            if _splitViewController.isCollapsed {
                saveDatabase(_databaseFile)
            } else {
                _selectEntry(entry)
                _entryViewerCoordinator?.switchToFilesTab()
                saveDatabase(_databaseFile)
            }
        }
    }

    private func _showDroppedAttachmentsFailure() {
        _presenterForModals.showNotification(
            LString.someIncomingAttachmentsFailedToLoad,
            image: .symbol(.exclamationMarkTriangle)
        )
    }

    private func _addAttachments(_ attachments: [Attachment], to entry: Entry) {
        guard let firstAttachment = attachments.first else {
            assertionFailure("Expected at least one attachment")
            return
        }

        entry.backupState()
        if entry.isSupportsMultipleAttachments {
            entry.attachments.append(contentsOf: attachments)
            Diag.info("Added \(attachments.count) attachments")
        } else {
            entry.attachments.removeAll()
            entry.attachments.append(firstAttachment)
            Diag.info("Added 1 of \(attachments.count) attachments")
        }
    }
}
