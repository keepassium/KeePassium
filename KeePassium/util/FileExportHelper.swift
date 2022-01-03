//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class FileExportHelper: NSObject {
    private let data: ByteArray
    private let fileName: String
    private var tmpURL: TemporaryFileURL?
    
    var handler: ((_ newURL: URL?) -> Void)?
    
    init(data: ByteArray, fileName: String) {
        self.data = data
        self.fileName = fileName
        super.init()
    }
    
    public func saveAs(presenter viewController: UIViewController) {
        assert(handler != nil, "The `handler` callback must be defined for processing user choice")
        do {
            tmpURL = try TemporaryFileURL(fileName: fileName)
            try data.write(to: tmpURL!.url, options: .completeFileProtection)

            let documentPicker = UIDocumentPickerViewController(
                forExporting: [tmpURL!.url],
                asCopy: true
            )
            documentPicker.delegate = self
            viewController.present(documentPicker, animated: true, completion: nil)
        } catch {
            Diag.error("Failed to save temporary file [message: \(error.localizedDescription)")
            tmpURL = nil
            handler?(nil)
        }
    }
}

extension FileExportHelper: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        handler?(nil)
    }
    
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else {
            Diag.warning("No target file selected")
            handler?(nil)
            return
        }
        let fileProvider = FileProvider.find(for: url) 
        FileDataProvider.write(data, to: url, fileProvider: fileProvider, completionQueue: .main) {
            [self] result in
            switch result {
            case .success:
                self.handler?(url)
            case .failure(_):
                Diag.error("Failed to save file, cancelling")
                self.handler?(nil)
            }
        }
    }
}

extension FileExportHelper {
    
    public static func revealInFinder(_ urlRef: URLReference) {
        assert(ProcessInfo.isRunningOnMac)
        let NSWorkspace = NSClassFromString("NSWorkspace") as AnyObject
        let sharedWorkspaceSelector = NSSelectorFromString("sharedWorkspace")
        let sharedWorkspaceSignature = (@convention(c)(AnyObject, Selector) -> NSObject).self
        let sharedWorkspaceMethod = unsafeBitCast(
            NSWorkspace.method(for: sharedWorkspaceSelector),
            to: sharedWorkspaceSignature
        )
        let sharedWorkspace = sharedWorkspaceMethod(NSWorkspace, sharedWorkspaceSelector)

        let activateSelector = NSSelectorFromString("activateFileViewerSelectingURLs:")
        let activateSignature = (@convention(c)(NSObject, Selector, [URL]) -> Void).self
        let activateMethod = unsafeBitCast(
            sharedWorkspace.method(for: activateSelector),
            to: activateSignature
        )
        do {
            let fileURL = try urlRef.resolveSync()
            assert(fileURL.isFileURL)
            activateMethod(sharedWorkspace, activateSelector, [fileURL])
        } catch {
            Diag.warning("Failed to reveal the file [message: \(error.localizedDescription)]")
        }
    }
    
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
