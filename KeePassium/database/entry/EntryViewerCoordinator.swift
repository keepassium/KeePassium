//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import QuickLook

protocol EntryViewerCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator)
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
    func didPressOpenLinkedDatabase(_ info: LinkedDatabaseInfo, in coordinator: EntryViewerCoordinator)
}

final class EntryViewerCoordinator: NSObject, Coordinator, Refreshable {
    private enum Pages: Int, CaseIterable {
        case fields = 0
        case files = 1
        case history = 2
        case extra = 3
    }

    var childCoordinators = [Coordinator]()

    weak var delegate: EntryViewerCoordinatorDelegate?

    var dismissHandler: CoordinatorDismissHandler?
    private let router: NavigationRouter

    private let databaseFile: DatabaseFile
    private let database: Database
    private var entry: Entry
    private var isHistoryEntry: Bool
    private var canEditEntry: Bool

    private let pagesVC: EntryViewerPagesVC

    private let fieldViewerVC: EntryFieldViewerVC
    private let fileViewerVC: EntryFileViewerVC
    private let historyViewerVC: EntryHistoryViewerVC
    private let extraViewerVC: EntryExtraViewerVC

    private let specialEntryParser = SpecialEntryParser()
    private var previewController: QLPreviewController?
    private var temporaryAttachmentURLs = [TemporaryFileURL]()
    private var photoPicker: PhotoPicker? 

    private let settingsNotifications: SettingsNotifications
    private weak var progressHost: ProgressViewHost?
    private var toastHost: UIViewController {
        router.navigationController
    }

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return progressHost }
    var saveSuccessHandler: (() -> Void)?

    private var expiryDateEditorModalRouter: NavigationRouter?

    private var tagsField: EntryField?

    init(
        entry: Entry,
        databaseFile: DatabaseFile,
        isHistoryEntry: Bool,
        canEditEntry: Bool,
        router: NavigationRouter,
        progressHost: ProgressViewHost
    ) {
        self.entry = entry
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.isHistoryEntry = isHistoryEntry
        self.canEditEntry = canEditEntry
        self.router = router
        self.progressHost = progressHost
        settingsNotifications = SettingsNotifications()

        fieldViewerVC = EntryFieldViewerVC.instantiateFromStoryboard()
        fileViewerVC = EntryFileViewerVC.instantiateFromStoryboard()
        historyViewerVC = EntryHistoryViewerVC.instantiateFromStoryboard()
        pagesVC = EntryViewerPagesVC.instantiateFromStoryboard()
        extraViewerVC = EntryExtraViewerVC()

        super.init()

        fieldViewerVC.delegate = self
        fileViewerVC.delegate = self
        historyViewerVC.delegate = self
        extraViewerVC.delegate = self
        pagesVC.dataSource = self
        pagesVC.delegate = self

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
        setEntry(entry, isHistoryEntry: isHistoryEntry, canEditEntry: canEditEntry)
    }

    public func dismiss(animated: Bool) {
        previewController?.dismiss(animated: animated, completion: nil)
        router.pop(viewController: pagesVC, animated: animated)
    }

    public func setEntry(_ entry: Entry, isHistoryEntry: Bool, canEditEntry: Bool) {
        dismissPreview(animated: false)
        if let existingEntryViewerCoo = childCoordinators.first(where: { $0 is EntryViewerCoordinator }) {
            let historyEntryViewer = existingEntryViewerCoo as! EntryViewerCoordinator
            historyEntryViewer.dismiss(animated: true)
        }

        self.entry = entry
        self.isHistoryEntry = isHistoryEntry
        self.canEditEntry = canEditEntry
        refresh()
    }

    func refresh() {
        refresh(animated: false)
    }

    func refresh(animated: Bool) {
        let category = ItemCategory.get(for: entry)
        var fields = ViewableEntryFieldFactory.makeAll(
            from: entry,
            in: database,
            excluding: [.title, .emptyValues, .otpConfig, .passkeyConfig]
        )
        if database is Database2,
           let (entry, field) = ViewableEntryFieldFactory.makeTags(
                from: entry,
                parent: entry.parent,
                includeEmpty: false)
        {
            self.tagsField = entry
            fields.append(field)
        }

        fieldViewerVC.setContents(
            fields,
            category: category,
            tags: entry.resolvingTags(),
            linkedDBInfo: specialEntryParser.extractLinkedDatabaseInfo(from: entry),
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
        extraViewerVC.setContents(
            for: entry,
            property: makeExtraProperties(),
            canEditEntry: canEditEntry,
            animated: animated)
        pagesVC.setContents(
            from: entry,
            hasAttachments: !entry.attachments.isEmpty,
            isHistoryEntry: isHistoryEntry,
            canEditEntry: canEditEntry)
        pagesVC.refresh()
    }

    private func makeExtraProperties() -> [EntryExtraViewerVC.Property] {
        guard let entry2 = entry as? Entry2 else {
            return []
        }

        return [
            .audit(entry2.qualityCheck),
            .autoFill(entry2.autoType.isEnabled),
            entry2.browserHideEntry.flatMap({ .autoFillThirdParty($0) })
        ].compactMap { $0 }
    }
}

extension EntryViewerCoordinator: EntryViewerPagesDataSource {
    func getPageCount(for viewController: EntryViewerPagesVC) -> Int {
        return Pages.allCases.count
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
        case .extra:
            return extraViewerVC
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
        case extraViewerVC:
            return Pages.extra.rawValue
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
            forOpeningContentTypes: FileType.attachmentUTIs,
            asCopy: true 
        )
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
                self.refresh(animated: true)
                self.saveDatabase()
            case .failure(let error):
                Diag.error("Failed to add photo attachment [message: \(error.localizedDescription)]")
                viewController.showErrorAlert(error)
            }
        }
    }

    private func loadAttachmentFile(from url: URL, success: @escaping (ByteArray) -> Void) {
        Diag.info("Loading new attachment file")
        progressHost?.showProgressView(
            title: LString.statusLoadingAttachmentFile,
            allowCancelling: false,
            animated: true)

        let fileProvider = FileProvider.find(for: url) 
        FileDataProvider.read(
            url,
            fileProvider: fileProvider,
            timeout: Timeout(duration: FileDataProvider.defaultTimeoutDuration),
            completionQueue: .main
        ) { [weak self] result in
            assert(Thread.isMainThread)
            guard let self = self else { return }
            switch result {
            case .success(let docData):
                success(docData)
            case .failure(let fileAccessError):
                Diag.error("Failed to open file to be attached [message: \(fileAccessError.localizedDescription)]")
                self.progressHost?.hideProgressView(animated: false) 
                let vc = self.router.navigationController
                vc.showErrorAlert(fileAccessError)
            }
        }
    }

    private func addAttachment(name: String, data: ByteArray) {
        assert(canEditEntry)
        assert(Thread.isMainThread)
        entry.backupState()

        let newAttachment = database.makeAttachment(name: name, data: data)
        if !entry.isSupportsMultipleAttachments {
            entry.attachments.removeAll()
        }
        entry.attachments.append(newAttachment)
        Diag.info("Attachment added OK")
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

    private func showSaveDialog(
        for attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        Diag.debug("Will save attachment")
        assert(fileExportHelper == nil)

        let uncompressedBytes: ByteArray
        do {
            if attachment.isCompressed {
                uncompressedBytes = try attachment.data.gunzipped() 
            } else {
                uncompressedBytes = attachment.data
            }
        } catch {
            Diag.error("Failed to decompress the attachment [message: \(error.localizedDescription)]")
            return
        }

        fileExportHelper = FileExportHelper(data: uncompressedBytes, fileName: attachment.name)
        fileExportHelper!.handler = { finalURL in
            self.fileExportHelper = nil 
            guard finalURL != nil else { return }

            Diag.info("Attachment saved OK")
            viewController.showSuccessNotification(
                LString.actionDone,
                icon: ProcessInfo.isRunningOnMac ? .squareAndArrowDown : .squareAndArrowUp
            )
        }
        fileExportHelper!.saveAs(presenter: viewController)
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
            databaseFile: databaseFile,
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
            databaseFile: databaseFile,
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

    private func showLargeType(
        text: String,
        at popoverAnchor: PopoverAnchor,
        in viewController: UIViewController
    ) {
        let largeTypeVC = LargeTypeVC(text: text, maxSize: viewController.view.frame.size)

        let estimatedRowCount = largeTypeVC.getEstimatedRowCount(atSize: viewController.view.frame.size)
        if router.isHorizontallyCompact && (estimatedRowCount > 3) {
            largeTypeVC.modalPresentationStyle = .pageSheet
            if let sheet = largeTypeVC.sheetPresentationController {
                sheet.prefersEdgeAttachedInCompactHeight = true
                sheet.detents = largeTypeVC.detents(for: viewController.view.frame.size)
            }
        } else {
            largeTypeVC.modalPresentationStyle = .popover
            guard let popoverPresentationController = largeTypeVC.popoverPresentationController else {
                  assertionFailure()
                  return
            }
            popoverPresentationController.permittedArrowDirections = [.up, .down]
            popoverAnchor.apply(to: popoverPresentationController)
            popoverPresentationController.delegate = largeTypeVC
        }

        viewController.present(largeTypeVC, animated: true, completion: nil)
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

        saveDatabase(databaseFile)
    }

    private func copyText(text: String) {
        entry.touch(.accessed)
        Clipboard.general.copyWithTimeout(text)
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
        copyText(text: text)
    }

    func didPressExportField(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        showExportDialog(for: text, at: popoverAnchor, in: viewController)
    }

    func didPressCopyFieldReference(
        from viewableField: ViewableField,
        in viewController: EntryFieldViewerVC
    ) {
        guard let entryField = viewableField.field,
              let refString = EntryFieldReference.make(for: entryField, in: entry)
        else {
            assertionFailure("Tried to create a reference to non-referenceable field")
            return
        }
        Clipboard.general.copyWithTimeout(refString)
        HapticFeedback.play(.copiedToClipboard)
        viewController.showNotification(LString.fieldReferenceCopiedToClipboard)
    }

    func didPressShowLargeType(
        text: String,
        from viewableField: ViewableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldViewerVC
    ) {
        showLargeType(text: text, at: popoverAnchor, in: viewController)
    }

    func didPressOpenLinkedDatabase(_ info: LinkedDatabaseInfo, in viewController: EntryFieldViewerVC) {
        performPremiumActionOrOfferUpgrade(for: .canOpenLinkedDatabases, in: viewController) { [weak self] in
            guard let self else { return }
            delegate?.didPressOpenLinkedDatabase(info, in: self)
        }
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

    func didPressSave(
        file attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    ) {
        showSaveDialog(for: attachment, at: popoverAnchor, in: viewController)
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

    func didPressView(
        file attachment: Attachment,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFileViewerVC
    ) {
        showPreview(for: [attachment], at: popoverAnchor, in: viewController)
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

extension EntryViewerCoordinator: EntryExtraViewerVCDelegate {
    func didPressCopyField(text: String, in viewController: EntryExtraViewerVC) {
        copyText(text: text)
    }

    func didPressExportField(text: String, at popoverAnchor: PopoverAnchor, in viewController: EntryExtraViewerVC) {
        showExportDialog(for: text, at: popoverAnchor, in: viewController)
    }

    func didPressShowLargeType(text: String, at popoverAnchor: PopoverAnchor, in viewController: EntryExtraViewerVC) {
        showLargeType(text: text, at: popoverAnchor, in: viewController)
    }

    func didUpdateProperties(properties: [EntryExtraViewerVC.Property], in viewController: EntryExtraViewerVC) {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Requires Entry2, this should be blocked in UI.")
            return
        }

        let action = { [weak self] in
            guard let self = self else {
                return
            }

            properties.forEach {
                switch $0 {
                case .audit(let value):
                    entry2.qualityCheck = value
                case .autoFill(let value):
                    entry2.autoType.isEnabled = value
                case .autoFillThirdParty(let value):
                    entry2.browserHideEntry = value
                }
            }

            entry2.touch(.modified)
            self.saveDatabase(self.databaseFile)
            self.refresh()
        }

        let willUpdateAuditOption = properties.contains(where: { $0 == .audit(!entry2.qualityCheck) })
        if willUpdateAuditOption {
            requestFormatUpgradeIfNecessary(
                in: viewController,
                for: database,
                and: .qualityCheckFlag
            ) {
                action()
            }
        } else {
            action()
        }
    }
}

extension EntryViewerCoordinator: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        loadAttachmentFile(from: url, success: { [weak self] fileData in
            self?.addAttachment(name: url.lastPathComponent, data: fileData)
            self?.refresh(animated: true)
            self?.saveDatabase()
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
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: url)
    }

    func didUpdateEntry(_ entry: Entry, in coordinator: EntryViewerCoordinator) {
        assertionFailure("History entries cannot be modified")
    }

    func didPressOpenLinkedDatabase(
        _ info: LinkedDatabaseInfo,
        in coordinator: EntryViewerCoordinator
    ) {
        delegate?.didPressOpenLinkedDatabase(info, in: self)
    }
}

extension EntryViewerCoordinator: EntryFieldEditorCoordinatorDelegate {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator) {
        refresh()
        delegate?.didUpdateEntry(entry, in: self)
    }
}

extension EntryViewerCoordinator: DatabaseSaving {
    func willStartSaving(databaseFile: DatabaseFile) {
        assert(canEditEntry)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return router.navigationController
    }

    func getDiagnosticsHandler() -> (() -> Void)? {
        return showDiagnostics
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
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

extension EntryViewerCoordinator: EntryViewerPagesVCDelegate {
    func canDropFiles(_ files: [UIDragItem]) -> Bool {
        guard canEditEntry else {
            return false
        }

        if entry.isSupportsMultipleAttachments {
            return true
        }

        let isTooCrowded = files.count > 1 || entry.attachments.count > 0
        return !isTooCrowded
    }

    func didDropFiles(_ files: [TemporaryFileURL]) {
        let dispatchGroup = DispatchGroup()
        for file in files {
            dispatchGroup.enter()

            loadAttachmentFile(from: file.url) { [weak self] fileData in
                self?.addAttachment(name: file.url.lastPathComponent, data: fileData)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            Diag.debug("Dropped files added, refreshing and saving")
            self?.refresh(animated: true)
            self?.saveDatabase()
        }
    }
}
