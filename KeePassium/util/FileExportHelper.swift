//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class FileExportHelper {

    public static func showFileExportSheet(
        _ urlRef: URLReference,
        at popoverAnchor: PopoverAnchor,
        parent: UIViewController,
        completion: UIActivityViewController.CompletionWithItemsHandler?=nil)
    {
        do {
            let url = try urlRef.resolveSync()
            FileExportHelper.showFileExportSheet(url, at: popoverAnchor, parent: parent, completion: completion)
        } catch {
            Diag.error("Failed to resolve URL reference [message: \(error.localizedDescription)]")
            let alert = UIAlertController.make(
                title: LString.titleFileExportError,
                message: error.localizedDescription)
            parent.present(alert, animated: true, completion: nil)
        }
    }
    
    public static func showFileExportSheet(
        _ url: URL,
        at popoverAnchor: PopoverAnchor,
        parent: UIViewController,
        completion: UIActivityViewController.CompletionWithItemsHandler?=nil)
    {
        let exportSheet = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil)
        exportSheet.completionWithItemsHandler = completion
        if let popover = exportSheet.popoverPresentationController {
            popoverAnchor.apply(to: popover)
        }
        parent.present(exportSheet, animated: true, completion: nil)
    }
}
