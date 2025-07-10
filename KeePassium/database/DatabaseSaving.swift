//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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
            guard let self else { return }
            self.fileExportHelper = nil
            self.savingProgressHost?.hideProgressView(animated: true)
            guard let newURL else {
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
            guard let self else { return }
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
        savingProgressHost?.hideProgressView(animated: true)

        askDatabaseSavingErrorResolution(
            error,
            databaseFile: databaseFile,
            parent: getDatabaseSavingErrorParent()
        ) { [weak self] resolution in
            guard let self else { return }
            switch resolution {
            case .retry:
                Diag.info("Will retry saving")
                self.databaseSaver!.save()
            case .saveAs:
                self.databaseSaver = nil
                saveToAnotherFile(databaseFile: databaseFile)
            case .showDiagnostics:
                self.databaseSaver = nil
                didFailSaving(databaseFile: databaseFile)
                let showDiagnosticInfo = getDiagnosticsHandler()
                showDiagnosticInfo?()
            case .cancel:
                self.databaseSaver = nil
                didFailSaving(databaseFile: databaseFile)
            }
            assert(self.databaseSaver == nil || resolution == .retry, "databaseSaver must be deallocated")
        }
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

private enum DatabaseSavingErrorResolution {
    case retry
    case saveAs
    case showDiagnostics
    case cancel
}

extension DatabaseSaving {
    private func getErrorDetails(_ error: Error) -> String? {
        guard let localizedError = error as? LocalizedError else {
            return nil
        }

        let parts = [localizedError.failureReason, localizedError.recoverySuggestion]
        return parts.compactMap { $0 }.joined(separator: "\n\n")
    }

    private func askDatabaseSavingErrorResolution(
        _ error: Error,
        databaseFile: DatabaseFile,
        parent viewController: UIViewController,
        completion: @escaping (DatabaseSavingErrorResolution) -> Void
    ) {
        StoreReviewSuggester.registerEvent(.trouble)
        let errorAlert = UIAlertController(
            title: error.localizedDescription,
            message: getErrorDetails(error),
            preferredStyle: .alert
        )
        if databaseFile.data.count > 0 {
            errorAlert.addAction(title: LString.actionRetry, style: .default, preferred: true) { _ in
                completion(.retry)
            }
            errorAlert.addAction(title: LString.actionFileSaveAs, style: .default) { _ in
                completion(.saveAs)
            }
        }
        errorAlert.addAction(title: LString.actionShowDetails, style: .default) { _ in
            completion(.showDiagnostics)
        }
        errorAlert.addAction(title: LString.actionCancel, style: .cancel) { _ in
            completion(.cancel)
        }
        viewController.present(errorAlert, animated: true, completion: nil)
    }
}
