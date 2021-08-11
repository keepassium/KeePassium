//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import QuickLook

protocol EntryViewerCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator)
}

final class EntryViewerCoordinator: NSObject, Coordinator, DatabaseSaving, Refreshable {
    private enum Pages: Int {
        static let count = 3
        
        case fields = 0
        case files = 1
        case history = 2
    }
    
    var childCoordinators = [Coordinator]()

    weak var delegate: EntryViewerCoordinatorDelegate?
    
    var dismissHandler: CoordinatorDismissHandler?
    private let router: NavigationRouter
    
    private var database: Database
    private var entry: Entry
    private var isHistoryEntry: Bool
    private var canEditEntry: Bool
    
    private let pagesVC: EntryViewerPagesVC
    
    private let fieldViewerVC: EntryFieldViewerVC
    private let fileViewerVC: EntryFileViewerVC
    private let historyViewerVC: EntryHistoryViewerVC
    
    private var previewController: QLPreviewController? 
    private var temporaryAttachmentURLs = [TemporaryFileURL]()
    private var photoPicker: PhotoPicker? 
    
    private let settingsNotifications: SettingsNotifications
    private weak var progressHost: ProgressViewHost?
    private var toastHost: UIViewController {
        router.navigationController
    }
    var databaseExporterTemporaryURL: TemporaryFileURL?
    
    private var expiryDateEditorModalRouter: NavigationRouter?
    
    
    init(
        entry: Entry,
        database: Database,
        isHistoryEntry: Bool,
        canEditEntry: Bool,
        router: NavigationRouter,
        progressHost: ProgressViewHost
    ) {
        self.entry = entry
        self.database = database
        self.isHistoryEntry = isHistoryEntry
        self.canEditEntry = canEditEntry
        self.router = router
        self.progressHost = progressHost
        settingsNotifications = SettingsNotifications()
        
        fieldViewerVC = EntryFieldViewerVC.instantiateFromStoryboard()
        fileViewerVC = EntryFileViewerVC.instantiateFromStoryboard()
        historyViewerVC = EntryHistoryViewerVC.instantiateFromStoryboard()
        pagesVC = EntryViewerPagesVC.instantiateFromStoryboard()
        
        super.init()

        fieldViewerVC.delegate = self
        fileViewerVC.delegate = self
        historyViewerVC.delegate = self
        pagesVC.dataSource = self

        settingsNotifications.observer = self
    }
    
    deinit {
        dismissPreview(animated: false)
        temporaryAttachmentURLs.removeAll()
        settingsNotifications.stopObserving()
        
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        settingsNotifications.startObserving()
        entry.touch(.accessed)
        let topVC = router.navigationController.topViewController
        let hasPlaceholderOnTop = topVC != nil && topVC is PlaceholderVC
        router.push(
            pagesVC,
            animated: isHistoryEntry,
            replaceTopViewController: hasPlaceholderOnTop,
            onPop: { [weak self] in
                guard let self = self else { return }
                self.removeAllChildCoordinators()
                self.dismissHandler?(self)
            }
        )
        refresh()
    }
    
    public func dismiss(animated: Bool) {
        previewController?.dismiss(animated: animated, completion: nil)
        router.pop(viewController: pagesVC, animated: animated)
    }
    
    public func setEntry(_ entry: Entry, database: Database, isHistoryEntry: Bool, canEditEntry: Bool) {
        dismissPreview(animated: false)
        if let existingEntryViewerCoo = childCoordinators.first(where: { $0 is EntryViewerCoordinator }) {
            let historyEntryViewer = existingEntryViewerCoo as! EntryViewerCoordinator
            historyEntryViewer.dismiss(animated: true)
        }
        
        self.entry = entry
        self.database = database
        self.isHistoryEntry = isHistoryEntry
        self.canEditEntry = canEditEntry
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
        fieldViewerVC.setContents(
            fields,
            category: category,
            isHistoryEntry: isHistoryEntry,
            canEditEntry: canEditEntry)
        fileViewerVC.setContents(
            entry.attachments,
            canEditEntry: canEditEntry,
            animated: animated)
        historyViewerVC.setContents(
            from: entry,
            isHistoryEntry: isHistoryEntry,
            canEditEntry: canEditEntry,
            animated: animated)
        pagesVC.setContents(
            from: entry,
            isHistoryEntry: isHistoryEntry,
            canEditEntry: canEditEntry)
        pagesVC.refresh()
    }
}

extension EntryViewerCoordinator: EntryViewerPagesDataSource {
    func getPageCount(for viewController: EntryViewerPagesVC) -> Int {
        return Pages.count
    }
    
    func getPage(index: Int, for viewController: EntryViewerPagesVC) -> UIViewController? {
        guard let page = Pages(rawValue: index) else {
            return nil
        }
        
        switch page {
        case .fields:
            return fieldViewerVC
        case .files:
            return fileViewerVC
        case .history:
            return historyViewerVC
        }
    }
    
    func getPageIndex(of page: UIViewController, for viewController: EntryViewerPagesVC) -> Int? {
        switch page {
        case fieldViewerVC:
            return Pages.fields.rawValue
        case fileViewerVC:
            return Pages.files.rawValue
        case historyViewerVC:
            return Pages.history.rawValue
        default:
            assertionFailure("Unexpected page VC")
            return nil
        }
    }
}

extension EntryViewerCoordinator {
    private func showFileAttachmentPicker(in viewController: UIViewController) {
        assert(canEditEntry)
        let picker = UIDocumentPickerViewController(
            documentTypes: FileType.attachmentUTIs,
            in: .import)
        picker.modalPresentationStyle = .formSheet
        picker.delegate = self
        viewController.present(picker, animated: true, completion: nil)
    }
    
    private func showPhotoAttachmentPicker(
        fromCamera: Bool,
        in viewController: UIViewController
    ) {
        assert(canEditEntry)
        assert(photoPicker == nil)

        if fromCamera {
            photoPicker = PhotoPickerFactory.makeCameraPhotoPicker()
        } else {
            photoPicker = PhotoPickerFactory.makePhotoPicker()
        }
        photoPicker?.pickImage(from: viewController) { [weak self] result in
            guard let self = self else { return }
            self.photoPicker = nil
            switch result {
            case .success(let pickerImage):
                guard let pickerImage = pickerImage else { 
                    return
                }
                Diag.debug("Converting image data to jpeg")
                guard let imageData = pickerImage.image.jpegData(compressionQuality: 0.9) else {
                    Diag.error("Failed to conver image to JPEG")
                    return
                }
                let fileName = (pickerImage.name ?? LString.defaultNewPhotoAttachmentName) + ".jpg"
                self.addAttachment(name: fileName, data: ByteArray(data: imageData))
            case .failure(let error):
                Diag.error("Failed to add photo attachment [message: \(error.localizedDescription)]")
                viewController.showErrorAlert(error)
            }
        }
    }

    private func loadAttachmentFile(from url: URL, success: @escaping (ByteArray)->Void) {
        Diag.info("Loading new attachment file")
        progressHost?.showProgressView(
            title: NSLocalizedString(
                "[Entry/Files/Add] Loading attachment file",
                value: "Loading attachment file",
                comment: "Status message: loading file to be attached to an entry"),
            allowCancelling: false,
            animated: true)
        
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
                    self.progressHost?.hideProgressView(animated: false) 
                    let vc = self.router.navigationController
                    vc.showErrorAlert(fileAccessError)
                }
            }
        }
    }
    
    private func addAttachment(name: String, data: ByteArray) {
        assert(canEditEntry)
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
            
            self.temporaryAttachmentURLs = [temporaryURL]
        } catch {
            Diag.error("Failed to export attachment [reason: \(error.localizedDescription)]")
            viewController.showErrorAlert(error, title: LString.titleFileExportError)
        }
    }
    
    private func showPreview(
        for attachments: [Attachment],
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        Diag.debug("Will present file preview")
        let urls = attachments.compactMap { attachment -> TemporaryFileURL? in
            do {
                let temporaryURL = try saveToTemporaryURL(attachment) 
                return temporaryURL
            } catch {
                Diag.error("Failed to export attachment [reason: \(error.localizedDescription)]")
                return nil
            }
        }
        
        temporaryAttachmentURLs = urls
        
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        self.previewController = previewController 
        if ProcessInfo.isRunningOnMac {
            viewController.present(previewController, animated: true, completion: nil)
        } else {
            router.push(previewController, animated: true, onPop: {
                self.temporaryAttachmentURLs.removeAll()
            })
        }
    }
    
    private func dismissPreview(animated: Bool) {
        guard let previewController = previewController else { return }
        if ProcessInfo.isRunningOnMac {
            previewController.dismiss(animated: animated, completion: nil)
        } else {
            router.pop(viewController: previewController, animated: animated)
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
        guard canEditEntry else {
            assertionFailure()
            Diag.warning("Tried to modify a non-editable entry")
            return
        }
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
            canEditEntry: false,
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
    
    private func showExpiryDateEditor(
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        assert(expiryDateEditorModalRouter == nil)
        let modalRouter = NavigationRouter.createModal(style: .popover)
        let expiryDateEditor = ExpiryDateEditorVC.instantiateFromStoryboard()
        expiryDateEditor.delegate = self
        expiryDateEditor.canExpire = entry.canExpire
        expiryDateEditor.expiryDate = entry.expiryTime
        popoverAnchor.apply(to: modalRouter.navigationController.popoverPresentationController)
        modalRouter.push(expiryDateEditor, animated: false, onPop: { [weak self] in
            self?.expiryDateEditorModalRouter = nil
        })
        viewController.present(modalRouter, animated: true, completion: nil)
        expiryDateEditorModalRouter = modalRouter
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
        guard canEditEntry else {
            Diag.warning("Tried to save non-editable entry, aborting")
            assertionFailure()
            return
        }
        entry.touch(.modified, updateParents: false)
        
        delegate?.didUpdateEntry(entry, in: self)
        EntryChangeNotifications.post(entryDidChange: entry)
        
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
}

extension EntryViewerCoordinator: EntryFieldViewerDelegate {
    func didPressEdit(
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry")
            assertionFailure()
            return
        }
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
    
    func didPressAddFile(at popoverAnchor: PopoverAnchor, in viewController: EntryFileViewerVC) {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry")
            assertionFailure()
            return
        }
        showFileAttachmentPicker(in: viewController)
    }
    
    func didPressAddPhoto(
        fromCamera: Bool,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    ) {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry")
            assertionFailure()
            return
        }
        showPhotoAttachmentPicker(fromCamera: fromCamera, in: viewController)
    }
    
    func shouldReplaceExistingFile(in viewController: EntryFileViewerVC) -> Bool {
        assert(canEditEntry, "Asked to replace file in non-editable entry")
        let canAddWithoutReplacement = entry.attachments.isEmpty || entry.isSupportsMultipleAttachments
        return !canAddWithoutReplacement
    }
    
    func didPressRename(
        file attachment: Attachment,
        to newName: String,
        in viewController: EntryFileViewerVC
    ) {
        assert(canEditEntry)
        attachment.name = newName
        viewController.refresh()
        saveDatabase()
    }
    
    func canPreviewFiles(in viewController: EntryFileViewerVC) -> Bool {
        return PremiumManager.shared.isAvailable(feature: .canPreviewAttachments)
    }
    
    func didPressView(
        file attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    ) {
        if canPreviewFiles(in: viewController) {
            showPreview(for: [attachment], at: popoverAnchor, in: viewController)
        } else {
            showExportDialog(for: attachment, at: popoverAnchor, in: viewController)
        }
    }
    func didPressViewAll(
        files attachments: [Attachment],
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    ) {
        showPreview(for: attachments, at: popoverAnchor, in: viewController)
    }
    
    func didPressDelete(
        files attachmentsToDelete: [Attachment],
        in viewController: EntryFileViewerVC
    ) {
        Diag.debug("Deleting attached files")
        assert(canEditEntry, "Tried to delete file from non-editable entry")
        
        entry.backupState()
        let newAttachments = entry.attachments.compactMap { attachment -> Attachment? in
            let shouldBeDeleted = attachmentsToDelete.contains(where: { $0 === attachment })
            return shouldBeDeleted ? nil : attachment
        }
        entry.attachments = newAttachments
        refresh(animated: true)
        Diag.info("Attachments deleted OK")

        saveDatabase()
    }
}

extension EntryViewerCoordinator: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        loadAttachmentFile(from: url, success: { [weak self] (fileData) in
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
    func didPressEditExpiryDate(
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryHistoryViewerVC
    ) {
        showExpiryDateEditor(at: popoverAnchor, in: viewController)
    }
    
    func didPressRestore(historyEntry: Entry2, in viewController: EntryHistoryViewerVC) {
        Diag.debug("Restoring historical entry")
        assert(canEditEntry)
        guard let entry2 = entry as? Entry2 else {
            Diag.error("Unexpected entry format")
            assertionFailure()
            return
        }
        entry2.backupState()
        historyEntry.applyPreservingHistory(to: entry2, makeNewUUID: false)
        entry2.touch(.modified)
        refresh(animated: true)
        Diag.info("Historical entry restored")
        toastHost.showNotification(LString.previousItemVersionRestored)
        saveDatabase()
    }
    
    func didPressDelete(
        historyEntries historyEntriesToDelete: [Entry2],
        in viewController: EntryHistoryViewerVC
    ) {
        Diag.debug("Deleting historical entries")
        assert(canEditEntry)
        guard let entry2 = entry as? Entry2 else {
            Diag.error("Unexpected entry format")
            assertionFailure()
            return
        }
        let newHistory = entry2.history.compactMap { entry -> Entry2? in
            let shouldBeDeleted = historyEntriesToDelete.contains(where: { $0 === entry })
            return shouldBeDeleted ? nil : entry
        }
        entry2.history = newHistory
        refresh(animated: true)
        Diag.info("Historical entries deleted")
        saveDatabase()
    }
    
    func didSelectHistoryEntry(_ entry: Entry2, in viewController: EntryHistoryViewerVC) {
        showHistoryEntry(entry)
    }
}

extension EntryViewerCoordinator: ExpiryDateEditorDelegate {
    func didPressCancel(in viewController: ExpiryDateEditorVC) {
        expiryDateEditorModalRouter?.dismiss(animated: true)
        expiryDateEditorModalRouter = nil
    }
    
    func didChangeExpiryDate(
        _ expiryDate: Date,
        canExpire: Bool,
        in viewController: ExpiryDateEditorVC
    ) {
        expiryDateEditorModalRouter?.dismiss(animated: true)
        expiryDateEditorModalRouter = nil
        entry.expiryTime = expiryDate
        entry.canExpire = canExpire
        refresh(animated: true)
        saveDatabase()
    }
}

extension EntryViewerCoordinator: EntryViewerCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator) {
        assertionFailure("History entries cannot be modified")
    }
}

extension EntryViewerCoordinator: EntryFieldEditorCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator) {
        refresh()
        delegate?.didUpdateEntry(entry, in: self)
    }
}

extension EntryViewerCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        assert(canEditEntry)
        progressHost?.showProgressView(
            title: LString.databaseStatusSaving,
            allowCancelling: true,
            animated: true
        )
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        progressHost?.updateProgressView(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        progressHost?.hideProgressView(animated: true)
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        progressHost?.hideProgressView(animated: true)
    }
    
    func databaseManager(database urlRef: URLReference, savingError error: Error, data: ByteArray?) {
        DatabaseManager.shared.removeObserver(self)
        progressHost?.hideProgressView(animated: true)
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: { [weak self] in self?.showDiagnostics() },
            exportableData: data,
            parent: router.navigationController 
        )
    }
}

extension EntryViewerCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else {
            return
        }
        refresh()
    }
}

extension EntryViewerCoordinator: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return temporaryAttachmentURLs.count
    }
    
    func previewController(
        _ controller: QLPreviewController,
        previewItemAt index: Int
    ) -> QLPreviewItem {
        let fileURL = temporaryAttachmentURLs[index].url
        return fileURL as QLPreviewItem
    }
}

extension EntryViewerCoordinator: QLPreviewControllerDelegate {
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        previewController = nil
    }
}
