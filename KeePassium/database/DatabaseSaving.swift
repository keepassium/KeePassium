//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseSaving: class {
    var databaseExporterTemporaryURL: TemporaryFileURL? { get set }
    
    func exportDataAsFile(
        _ data: ByteArray,
        fileName: String,
        parent viewController: UIViewController
    )
}

extension DatabaseSaving {
    
    private func getErrorDetails(_ error: Error) -> String? {
        guard let localizedError = error as? LocalizedError else {
            return nil
        }
        
        let parts = [localizedError.failureReason, localizedError.recoverySuggestion]
        return parts.compactMap{ $0 }.joined(separator: "\n\n")
    }
    
    func showDatabaseSavingError(
        _ error: Error,
        fileName: String,
        diagnosticsHandler: (()->Void)?,
        exportableData: ByteArray?,
        parent viewController: UIViewController
    ) {
        StoreReviewSuggester.registerEvent(.trouble)
        
        let errorAlert = UIAlertController.make(
            title: error.localizedDescription,
            message: getErrorDetails(error),
            dismissButtonTitle: LString.actionDismiss)
        if let diagnosticsHandler = diagnosticsHandler {
            errorAlert.addAction(title: LString.actionShowDetails, style: .default) { _ in
                diagnosticsHandler()
            }
        }
        if let data = exportableData {
            errorAlert.addAction(title: LString.actionExport, style: .default) {
                [weak self, weak viewController] _ in
                guard let viewController = viewController else { return }
                self?.exportDataAsFile(data, fileName: fileName, parent: viewController)
            }
        }
        viewController.present(errorAlert, animated: true, completion: nil)
    }
    
    func exportDataAsFile(
        _ data: ByteArray,
        fileName: String,
        parent viewController: UIViewController
    ) {
        assert(databaseExporterTemporaryURL == nil)
        do {
            let tmpURL = try TemporaryFileURL(fileName: fileName)
            databaseExporterTemporaryURL = tmpURL
            try data.write(to: tmpURL.url, options: .completeFileProtection)
            let popoverAnchor = PopoverAnchor(
                sourceView: viewController.view,
                sourceRect: viewController.view.bounds
            )
            FileExportHelper.showFileExportSheet(tmpURL.url, at: popoverAnchor, parent: viewController) {
                [weak self] (_, _, _, _) in
                self?.databaseExporterTemporaryURL = nil
            }
        } catch {
            Diag.error("Failed to save temporary file [message: \(error.localizedDescription)")
            databaseExporterTemporaryURL = nil
        }
    }
}
