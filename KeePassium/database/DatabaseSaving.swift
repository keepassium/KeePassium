//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseSaving: DatabaseSaverDelegate {
    var fileExportHelper: FileExportHelper? { get set }

    var databaseSaver: DatabaseSaver? { get set }
    var savingProgressHost: ProgressViewHost? { get }
    var saveSuccessHandler: (() -> Void)? { get set }

    func saveDatabase(
        _ databaseFile: DatabaseFile,
        timeoutDuration: TimeInterval,
        onSuccess: (() -> Void)?)

    func willStartSaving(databaseFile: DatabaseFile)
    func canCancelSaving(databaseFile: DatabaseFile) -> Bool
    func didCancelSaving(databaseFile: DatabaseFile)
    func didSave(databaseFile: DatabaseFile)
    func didFailSaving(databaseFile: DatabaseFile)

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL)

    func getDiagnosticsHandler() -> (() -> Void)?
    func getDatabaseSavingErrorParent() -> UIViewController
}

extension DatabaseSaving {
    func saveDatabase(
        _ databaseFile: DatabaseFile,
        timeoutDuration: TimeInterval = FileDataProvider.defaultTimeoutDuration,
        onSuccess: (() -> Void)? = nil
    ) {
        assert(databaseSaver == nil)
        saveSuccessHandler = onSuccess

        var tasksToSkip = [DatabaseSaver.RelatedTasks]()
        if let fileRef = databaseFile.fileReference,
           DatabaseSettingsManager.shared.getExternalUpdateBehavior(fileRef) == .dontCheck
        {
            tasksToSkip.append(.updateChecksum)
        }

        databaseSaver = DatabaseSaver(
            databaseFile: databaseFile,
            timeoutDuration: timeoutDuration,
            delegate: self)
        databaseSaver!.save()
    }

    fileprivate func saveToAnotherFile(databaseFile: DatabaseFile) {
        assert(databaseFile.data.count > 0, "Database content should be ready")
        assert(fileExportHelper == nil)
        assert(databaseSaver == nil, "Should be deallocated by caller")
        fileExportHelper = FileExportHelper(
            data: databaseFile.data,
            fileName: databaseFile.fileURL.lastPathComponent)
        fileExportHelper!.handler = { [weak self] newURL in
            guard let self = self else { return }
            self.fileExportHelper = nil
            self.savingProgressHost?.hideProgressView(animated: true)
            guard let newURL = newURL else { 
                return
            }
            databaseFile.setData(databaseFile.data, updateHash: true)
            self.didSave(databaseFile: databaseFile)
            self.didRelocate(databaseFile: databaseFile, to: newURL)
        }
        fileExportHelper!.saveAs(presenter: getDatabaseSavingErrorParent())
    }

    func databaseSaver(_ databaseSaver: DatabaseSaver, willSave databaseFile: DatabaseFile) {
        willStartSaving(databaseFile: databaseFile)
        savingProgressHost?.showProgressView(
            title: LString.databaseStatusSaving,
            allowCancelling: canCancelSaving(databaseFile: databaseFile),
            animated: true
        )
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didChangeProgress progress: ProgressEx,
        for databaseFile: DatabaseFile
    ) {
        savingProgressHost?.updateProgressView(with: progress)
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didCancelSaving databaseFile: DatabaseFile
    ) {
        self.databaseSaver = nil
        savingProgressHost?.hideProgressView(animated: true)
        didCancelSaving(databaseFile: databaseFile)
    }

    func databaseSaverResolveConflict(
        _ databaseSaver: DatabaseSaver,
        local: DatabaseFile,
        remoteURL: URL,
        remoteData: ByteArray,
        completion: @escaping DatabaseSaver.ConflictResolutionHandler
    ) {
        let alert = SyncConflictAlert.instantiateFromStoryboard()
        alert.setData(local: local, remote: remoteURL)
        alert.responseHandler = { [weak self, completion] strategy in
            guard let self = self else { return }
            switch strategy {
            case .cancelSaving:
                completion(.cancel)
            case .overwriteRemote:
                completion(.overwrite(local.data))
            case .merge:
                assertionFailure("Not implemented")
                completion(.cancel)
            case .saveAs:
                completion(.considerExported)
                self.databaseSaver = nil 
                self.saveToAnotherFile(databaseFile: local) 
            }
        }

        let viewController = getDatabaseSavingErrorParent()
        viewController.present(alert, animated: true, completion: nil)
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didSave databaseFile: DatabaseFile
    ) {
        self.databaseSaver = nil
        savingProgressHost?.hideProgressView(animated: true)
        DatabaseSettingsManager.shared.updateSettings(for: databaseFile) { dbSettings in
            dbSettings.maybeSetMasterKey(of: databaseFile.database)
        }
        didSave(databaseFile: databaseFile)
        saveSuccessHandler?()
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didFailSaving databaseFile: DatabaseFile,
        with error: Error
    ) {
        self.databaseSaver = nil
        savingProgressHost?.hideProgressView(animated: true)

        showDatabaseSavingError(
            error,
            fileName: databaseFile.visibleFileName,
            databaseFile: databaseFile,
            diagnosticsHandler: getDiagnosticsHandler(),
            parent: getDatabaseSavingErrorParent()
        )
    }
}

extension DatabaseSaving {
    func willStartSaving(databaseFile: DatabaseFile) { }
    func canCancelSaving(databaseFile: DatabaseFile) -> Bool { return true }
    func didCancelSaving(databaseFile: DatabaseFile) { }
    func didSave(databaseFile: DatabaseFile) { }
    func didFailSaving(databaseFile: DatabaseFile) { }
    func getDiagnosticsHandler() -> (() -> Void)? {
        return nil
    }
}

extension DatabaseSaving {
    private func getErrorDetails(_ error: Error) -> String? {
        guard let localizedError = error as? LocalizedError else {
            return nil
        }

        let parts = [localizedError.failureReason, localizedError.recoverySuggestion]
        return parts.compactMap { $0 }.joined(separator: "\n\n")
    }

    func showDatabaseSavingError(
        _ error: Error,
        fileName: String,
        databaseFile: DatabaseFile,
        diagnosticsHandler: (() -> Void)?,
        parent viewController: UIViewController
    ) {
        StoreReviewSuggester.registerEvent(.trouble)
        let errorAlert = UIAlertController(
            title: error.localizedDescription,
            message: getErrorDetails(error),
            preferredStyle: .alert
        )
        if let diagnosticsHandler = diagnosticsHandler {
            errorAlert.addAction(title: LString.actionShowDetails, style: .default) { [weak self] _ in
                self?.didFailSaving(databaseFile: databaseFile)
                diagnosticsHandler()
            }
        }
        if databaseFile.data.count > 0 {
            errorAlert.addAction(title: LString.actionFileSaveAs, style: .default) { [weak self] _ in
                self?.saveToAnotherFile(databaseFile: databaseFile) 
            }
        }
        errorAlert.addAction(title: LString.actionCancel, style: .cancel) { [weak self] _ in
            self?.didFailSaving(databaseFile: databaseFile)
        }
        viewController.present(errorAlert, animated: true, completion: nil)
    }
}
