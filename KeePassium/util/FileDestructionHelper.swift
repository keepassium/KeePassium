//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

public enum DestructiveFileAction {
    case remove
    case delete
    
    public static func get(for location: URLReference.Location) -> DestructiveFileAction {
        switch location {
        case .external:
            return .remove
        case .internalDocuments,
             .internalBackup,
             .internalInbox:
            return .delete
        }
    }
    
    var title: String {
        switch self {
        case .remove:
            return LString.actionRemoveFile
        case .delete:
            return LString.actionDeleteFile
        }
    }
    
    public func getConfirmationText(for fileType: FileType) -> String {
        switch (fileType, self) {
        case (.database, .remove):
            return LString.confirmDatabaseRemoval
        case (.database, .delete):
            return LString.confirmDatabaseDeletion
        case (.keyFile, .remove):
            return LString.confirmKeyFileRemoval
        case (.keyFile, .delete):
            return LString.confirmKeyFileDeletion
        }
    }
}

class FileDestructionHelper {
    
    typealias CompletionHandler = (Bool) -> ()
    
    public static func destroyFile(
        _ urlRef: URLReference,
        fileType: FileType,
        withConfirmation: Bool,
        at popoverAnchor: PopoverAnchor?,
        parent: UIViewController,
        completion: CompletionHandler?)
    {
        if urlRef.hasError {
            destroyFileNow(
                urlRef,
                fileType: fileType,
                parent: parent,
                completion: completion)
            return
        }
        
        let action = DestructiveFileAction.get(for: urlRef.location)
        let confirmationAlert = UIAlertController.make(
            title: urlRef.visibleFileName,
            message: action.getConfirmationText(for: fileType),
            dismissButtonTitle: LString.actionCancel)
            .addAction(title: action.title, style: .destructive) { alert in
                destroyFileNow(urlRef, fileType: fileType, parent: parent, completion: completion)
            }
        popoverAnchor?.apply(to: confirmationAlert.popoverPresentationController)
        parent.present(confirmationAlert, animated: true, completion: nil)
    }
    
    
    private static func destroyFileNow(
        _ urlRef: URLReference,
        fileType: FileType,
        parent: UIViewController,
        completion: CompletionHandler?)
    {
        let action = DestructiveFileAction.get(for: urlRef.location)
        let fileKeeper = FileKeeper.shared
        do {
            switch action {
            case .remove:
                fileKeeper.removeExternalReference(urlRef, fileType: fileType)
            case .delete:
                try fileKeeper.deleteFile(urlRef, fileType: fileType, ignoreErrors: urlRef.hasError)
            }
            if fileType == .database {
                DatabaseSettingsManager.shared.removeSettings(for: urlRef, onlyIfUnused: true)
            }
            completion?(true)
        } catch {
            Diag.error("Failed to delete file [type: \(fileType), reason: \(error.localizedDescription)]")
            completion?(false)
            parent.showErrorAlert(error)
        }
    }
}
