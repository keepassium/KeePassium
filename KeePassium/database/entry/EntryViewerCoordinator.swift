//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryViewerCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator)
}

final class EntryViewerCoordinator: NSObject, Coordinator, DatabaseSaving, Refreshable {
    var childCoordinators = [Coordinator]()

    weak var delegate: EntryViewerCoordinatorDelegate?
    
    var dismissHandler: CoordinatorDismissHandler?
    private let router: NavigationRouter
    
    private var database: Database
    private var entry: Entry
    private var isHistoryEntry: Bool
    
    private let fieldViewerVC: EntryFieldViewerVC
    private let fileViewerVC: EntryFileViewerVC
    private let historyViewerVC: EntryHistoryViewerVC
    
    
    private var filePreviewController = UIDocumentInteractionController()
    private var fileExportTemporaryURL: TemporaryFileURL?
    
    private weak var progressHost: ProgressViewHost?
    var databaseExporterTemporaryURL: TemporaryFileURL?
    
    init(
        entry: Entry,
        database: Database,
        isHistoryEntry: Bool,
        router: NavigationRouter,
        progressHost: ProgressViewHost
    ) {
        self.entry = entry
        self.database = database
        self.isHistoryEntry = isHistoryEntry
        self.router = router
        self.progressHost = progressHost
        
        fieldViewerVC = EntryFieldViewerVC.instantiateFromStoryboard()
        fileViewerVC = EntryFileViewerVC.instantiateFromStoryboard()
        historyViewerVC = EntryHistoryViewerVC.instantiateFromStoryboard()
        
        super.init()

        fieldViewerVC.delegate = self
        fileViewerVC.delegate = self
        historyViewerVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        entry.touch(.accessed)
        router.push(historyViewerVC, animated: isHistoryEntry, replacePlaceholder: true, onPop: {
            [weak self] viewController in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
    }
    
    public func setEntry(_ entry: Entry, database: Database, isHistoryEntry: Bool) {
        self.entry = entry
        self.database = database
        self.isHistoryEntry = isHistoryEntry
        refresh()
    }
    
    func refresh() {
        refresh(animated: false)
    }
    
    func refresh(animated: Bool) {
        let category = ItemCategory.get(for: entry)
        let fields = ViewableEntryFieldFactory.makeAll(
            from: entry,
            in: database,
            excluding: [.title, .emptyValues]
        )
        fieldViewerVC.setFields(fields, category: category)
        fileViewerVC.setAttachments(entry.attachments, animated: animated)
        
        historyViewerVC.setEntryHistory(from: entry, isHistoryEntry: isHistoryEntry)
    }
}

extension EntryViewerCoordinator {
    private func showNewAttachmentPicker(in viewController: UIViewController) {
        let picker = UIDocumentPickerViewController(
            documentTypes: FileType.attachmentUTIs,
            in: .import)
        picker.modalPresentationStyle = .formSheet
        picker.delegate = self
        viewController.present(picker, animated: true, completion: nil)
    }
    
    private func loadAttachment(from url: URL, success: @escaping (ByteArray)->Void) {
        Diag.info("Loading new attachment file")
        progressHost?.showProgressView(
            title: NSLocalizedString(
                "[Entry/Files/Add] Loading attachment file",
                value: "Loading attachment file",
                comment: "Status message: loading file to be attached to an entry"),
            allowCancelling: false)
        
        let doc = BaseDocument(fileURL: url, fileProvider: nil) 
        doc.open { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                DispatchQueue.main.async {
                    success(docData)
                }
            case .failure(let fileAccessError):
                Diag.error("Failed to open file to be attached [message: \(fileAccessError.localizedDescription)]")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.progressHost?.hideProgressView() 
                    let vc = self.router.navigationController
                    vc.showErrorAlert(fileAccessError)
                }
            }
        }
    }
    
    private func addAttachment(name: String, data: ByteArray) {
        entry.backupState()
        
        let newAttachment = database.makeAttachment(name: name, data: data)
        if !entry.isSupportsMultipleAttachments {
            entry.attachments.removeAll()
        }
        entry.attachments.append(newAttachment)
        Diag.info("Attachment added OK")

        refresh(animated: true)
        
        saveDatabase()
    }
}
    
extension EntryViewerCoordinator {
    private func showExportDialog(
        for value: String,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        var items: [Any] = [value]
        if value.isOpenableURL, let url = URL(string: value) {
            items = [url]
        }
        
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        popoverAnchor.apply(to: activityVC.popoverPresentationController)
        viewController.present(activityVC, animated: true)
    }
    
    private func showExportDialog(
        for attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        Diag.debug("Will export attachment")
        do {
            let temporaryURL = try saveToTemporaryURL(attachment) 
            FileExportHelper.showFileExportSheet(temporaryURL.url, at: popoverAnchor, parent: viewController)
            
            self.fileExportTemporaryURL = temporaryURL
        } catch {
            Diag.error("Failed to export attachment [reason: \(error.localizedDescription)]")
            viewController.showErrorAlert(error, title: LString.titleFileExportError)
        }
    }
    
    private func showPreview(
        for attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        Diag.debug("Will present file preview")
        do {
            let temporaryURL = try saveToTemporaryURL(attachment) 
            
            self.fileExportTemporaryURL = temporaryURL
            filePreviewController.url = temporaryURL.url
            filePreviewController.delegate = self
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                assert(popoverAnchor.kind == .viewRect)
                if !self.filePreviewController.presentPreview(animated: true) {
                    Diag.debug("Preview not available, showing menu")
                    self.filePreviewController.presentOptionsMenu(
                        from: popoverAnchor.sourceRect!,
                        in: popoverAnchor.sourceView!,
                        animated: true
                    )
                }
            }
        } catch {
            Diag.error("Failed to export attachment [reason: \(error.localizedDescription)]")
            viewController.showErrorAlert(error, title: LString.titleFileExportError)
        }
    }
    
    private func saveToTemporaryURL(_ attachment: Attachment) throws -> TemporaryFileURL {
        guard let encodedFileName = attachment.name
                .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let fileName = URL(string: encodedFileName)?.lastPathComponent
        else {
            Diag.warning("Failed to create a URL from attachment name [name: \(attachment.name)]")
            throw CocoaError.error(.fileWriteInvalidFileName)
        }
        
        do {
            let uncompressedBytes: ByteArray
            if attachment.isCompressed {
                uncompressedBytes = try attachment.data.gunzipped() 
            } else {
                uncompressedBytes = attachment.data
            }
            let temporaryFileURL = try TemporaryFileURL(fileName: fileName)
            try uncompressedBytes.write(to: temporaryFileURL.url, options: [.completeFileProtection])
            return temporaryFileURL
        } catch {
            Diag.error(error.localizedDescription)
            throw error
        }
    }
}

extension EntryViewerCoordinator {
    private func showEntryFieldEditor() {
        guard let parent = entry.parent else {
            Diag.warning("Entry's parent group is undefined")
            assertionFailure()
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: nil)
        let entryFieldEditorCoordinator = EntryFieldEditorCoordinator(
            router: modalRouter,
            database: database,
            parent: parent,
            target: entry
        )
        entryFieldEditorCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        entryFieldEditorCoordinator.delegate = self
        entryFieldEditorCoordinator.start()
        modalRouter.dismissAttemptDelegate = entryFieldEditorCoordinator
        
        router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(entryFieldEditorCoordinator)
    }
    
    private func showHistoryEntry(_ entry: Entry) {
        guard let progressHost = progressHost else { return }
        
        let historyEntryViewerCoordinator = EntryViewerCoordinator(
            entry: entry,
            database: database,
            isHistoryEntry: true,
            router: router,
            progressHost: progressHost
        )
        historyEntryViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        historyEntryViewerCoordinator.delegate = self
        historyEntryViewerCoordinator.start()
        addChildCoordinator(historyEntryViewerCoordinator)
    }
    
    private func showDiagnostics() {
        let modalRouter = NavigationRouter.createModal(style: .pageSheet)
        let diagnosticsCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsCoordinator.start()
        router.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsCoordinator)
    }
    
    private func saveDatabase() {
        entry.touch(.modified, updateParents: false)
        
        delegate?.didUpdateEntry(entry, in: self)
        EntryChangeNotifications.post(entryDidChange: entry)
        
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
}

extension EntryViewerCoordinator: EntryFieldViewerDelegate {
    func canEditEntry(in viewController: EntryFieldViewerVC) -> Bool {
        return !entry.isDeleted
    }
    
    func didPressEdit(
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        showEntryFieldEditor()
    }
    
    func didPressCopyField(
        text: String,
        from viewableField: ViewableField,
        in viewController: EntryFieldViewerVC
    ) {
        entry.touch(.accessed)
        Clipboard.general.insert(text)
    }
    
    func didPressExportField(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        showExportDialog(for: text, at: popoverAnchor, in: viewController)
    }
}

extension EntryViewerCoordinator: EntryFileViewerDelegate {
    
    func didPressAddFile(in viewController: EntryFileViewerVC) {
        showNewAttachmentPicker(in: viewController)
    }
    
    func shouldReplaceExistingFile(in viewController: EntryFileViewerVC) -> Bool {
        assert(canEditFiles(in: viewController), "Asked to replace file in non-editable entry")
        let canAddWithoutReplacement = entry.attachments.isEmpty || entry.isSupportsMultipleAttachments
        return !canAddWithoutReplacement
    }
    
    func canEditFiles(in viewController: EntryFileViewerVC) -> Bool {
        return !isHistoryEntry
    }
    
    func didRenameFile(
        _ attachment: Attachment,
        to newName: String,
        in viewController: EntryFileViewerVC
    ) {
        attachment.name = newName
        fileViewerVC.refresh()
        saveDatabase()
    }
    
    func didPressViewFile(
        _ attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    ) {
        let isPreviewAllowed = PremiumManager.shared.isAvailable(feature: .canPreviewAttachments)
        if isPreviewAllowed {
            showPreview(for: attachment, at: popoverAnchor, in: viewController)
        } else {
            showExportDialog(for: attachment, at: popoverAnchor, in: viewController)
        }
    }
    
    func didPressDeleteFile(_ attachment: Attachment, in viewController: EntryFileViewerVC) {
        entry.backupState()
        entry.attachments.removeAll(where: { $0 === attachment })
        refresh(animated: true)
        Diag.info("Attachment deleted OK")

        saveDatabase()
    }
}

extension EntryViewerCoordinator: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        loadAttachment(from: url, success: { [weak self] (fileData) in
            self?.addAttachment(name: url.lastPathComponent, data: fileData)
        })
    }
}

extension EntryViewerCoordinator: UIDocumentInteractionControllerDelegate {
    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        return router.navigationController
    }
}

extension EntryViewerCoordinator: EntryHistoryViewerDelegate {
    func didSelectHistoryEntry(_ entry: Entry, in viewController: EntryHistoryViewerVC) {
        showHistoryEntry(entry)
    }
}

extension EntryViewerCoordinator: EntryViewerCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator) {
        assertionFailure("History entries cannot be modified")
    }
}

extension EntryViewerCoordinator: EntryFieldEditorCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator) {
        fieldViewerVC.refresh()
        delegate?.didUpdateEntry(entry, in: self)
    }
}

extension EntryViewerCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        progressHost?.showProgressView(title: LString.databaseStatusSaving, allowCancelling: true)
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        progressHost?.updateProgressView(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        progressHost?.hideProgressView()
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        progressHost?.hideProgressView()
    }
    
    func databaseManager(database urlRef: URLReference, savingError error: Error, data: ByteArray?) {
        DatabaseManager.shared.removeObserver(self)
        progressHost?.hideProgressView()
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: { [weak self] in self?.showDiagnostics() },
            exportableData: data,
            parent: router.navigationController 
        )
    }
}
