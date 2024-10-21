//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryFieldEditorCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator)

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

final class EntryFieldEditorCoordinator: Coordinator {
    private typealias RollbackRoutine = () -> Void

    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: EntryFieldEditorCoordinatorDelegate?

    public var isCreating: Bool {
        originalEntry == nil
    }

    private let databaseFile: DatabaseFile
    private let database: Database
    private let parent: Group 
    private let originalEntry: Entry? 

    private var entry: Entry
    private var fields = [EditableField]()

    private var originalEntryBeforeSaving: Entry?
    private var rollbackPreSaveActions: RollbackRoutine?

    private var qrCodeScanner = { YubiKitQRCodeScanner() }()

    private let router: NavigationRouter
    private let fieldEditorVC: EntryFieldEditorVC

    private var isModified = false {
        didSet {
            fieldEditorVC.isModalInPresentation = isModified
        }
    }

    let faviconDownloader = FaviconDownloader()

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }
    var saveSuccessHandler: (() -> Void)?

    private var tagsField: EntryField?

    init(router: NavigationRouter, databaseFile: DatabaseFile, parent: Group, target: Entry?) {
        self.router = router
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.parent = parent
        self.originalEntry = target

        let isCreationMode: Bool
        if let _target = target {
            isCreationMode = false
            entry = _target.clone(makeNewUUID: false)
        } else {
            isCreationMode = true
            entry = parent.createEntry(detached: true)
            entry.populateStandardFields()
            entry.rawUserName = (database as? Database2)?.defaultUserName ?? ""
            entry.rawTitle = LString.defaultNewEntryName
        }

        fieldEditorVC = EntryFieldEditorVC.instantiateFromStoryboard()
        fieldEditorVC.title = isCreationMode ? LString.titleNewEntry : LString.titleEntry

        entry.touch(.accessed)
        (fields, tagsField) = setupFields(entry: entry)

        fieldEditorVC.delegate = self
        fieldEditorVC.fields = fields
        fieldEditorVC.entryIcon = UIImage.kpIcon(forEntry: entry)
        fieldEditorVC.allowsCustomFields = entry.isSupportsExtraFields
        fieldEditorVC.supportsFaviconDownload = database is Database2
        fieldEditorVC.itemCategory = ItemCategory.get(for: entry)
        fieldEditorVC.shouldFocusOnTitleField = isCreationMode
    }

    private func setupFields(entry: Entry) -> ([EditableField], EntryField?) {
        var fields = EditableFieldFactory.makeAll(from: entry, in: database)
        var tagsField: EntryField?
        if database is Database2,
           let (entryField, _) = ViewableEntryFieldFactory.makeTags(
                from: entry,
                parent: originalEntry?.parent,
                includeEmpty: true)
        {
            tagsField = entryField
            fields.append(EditableField(field: entryField))
        }
        return (fields, tagsField)
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(fieldEditorVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        refresh()
    }

    private func refresh() {
        fieldEditorVC.entryIcon = UIImage.kpIcon(forEntry: entry)
        fieldEditorVC.refresh()
    }

    private func abortAndDismiss() {
        router.pop(animated: true)
    }

    private func saveChangesAndDismiss() {
        entry.touch(.modified, updateParents: false)
        fieldEditorVC.view.endEditing(true)

        if let originalEntry = originalEntry {
            if originalEntryBeforeSaving == nil {
                originalEntryBeforeSaving = originalEntry.clone(makeNewUUID: false)
                originalEntry.backupState()
            }
            entry.applyPreservingHistory(to: originalEntry, makeNewUUID: false)
            rollbackPreSaveActions = { [weak self] in
                guard let self = self else { return }
                self.originalEntryBeforeSaving?.apply(to: self.originalEntry!, makeNewUUID: false)
            }
        } else {
            parent.add(entry: entry)
            rollbackPreSaveActions = { [weak self] in
                guard let self = self else { return }
                self.parent.remove(entry: self.entry)
            }
        }
        saveDatabase(databaseFile)
    }

    private func setOTPConfig(uri: String, isQRBased: Bool) {
        guard TOTPGeneratorFactory.isValidURI(uri) else {
            fieldEditorVC.showNotification(
                isQRBased ? LString.otpQRCodeNotValid : LString.otpInvalidSecretCode,
                image: .symbol(.exclamationMarkTriangle, tint: .errorMessage)
            )
            return
        }

        entry.setField(name: EntryField.otp, value: uri, isProtected: true)
        isModified = true

        if !fields.contains(where: { $0.internalName == EntryField.otp }) {
            (fields, tagsField) = setupFields(entry: entry)
            fieldEditorVC.fields = fields
        }
        refresh()
    }

    private func setOTPConfig(unfilteredSeed: String) {
        if TOTPGeneratorFactory.isValidURI(unfilteredSeed) {
            setOTPConfig(uri: unfilteredSeed, isQRBased: false)
            return
        }
        let seed = unfilteredSeed.replacingOccurrences(of: " ", with: "")
        let otpauthURI = TOTPGeneratorFactory.makeOtpauthURI(base32Seed: seed)
        setOTPConfig(uri: otpauthURI.absoluteString, isQRBased: false)
    }

    func showPasswordGenerator(
        for textInput: TextInputView,
        quickMode: Bool,
        in viewController: UIViewController
    ) {
        let passGenCoordinator = PasswordGeneratorCoordinator(
            router: router,
            quickMode: quickMode,
            hasTarget: true
        )
        passGenCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        passGenCoordinator.delegate = self
        passGenCoordinator.context = textInput
        passGenCoordinator.start()
        addChildCoordinator(passGenCoordinator)
    }

    private func makeUserNameGeneratorMenu(for field: EditableField) -> UIMenu {
        let applyUserName: UIActionHandler = { action in
            field.value = action.title
            self.isModified = true
            self.refresh()
        }

        let frequentUserNames = UserNameHelper.getUserNameSuggestions(from: database, count: 4)
        let frequentNamesMenuItems = frequentUserNames.map { userName -> UIAction in
            UIAction(title: userName, image: nil, handler: applyUserName)
        }
        let frequentNamesMenu = UIMenu.make(
            reverse: false, 
            options: .displayInline,
            children: frequentNamesMenuItems
        )

        let randomUserNames = UserNameHelper.getRandomUserNames(count: 3)
        let randomNamesMenuItems = randomUserNames.map { userName -> UIAction in
            UIAction(
                title: userName,
                image: .symbol(.dieFace3),
                handler: applyUserName
            )
        }
        let randomNamesMenu = UIMenu.make(options: .displayInline, children: randomNamesMenuItems)

        return UIMenu.make(
            title: LString.fieldUserName,
            children: [frequentNamesMenu, randomNamesMenu])
    }

    private func showDiagnostics() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()
        addChildCoordinator(diagnosticsViewerCoordinator)
    }

    private func changeIcon(image: UIImage) {
        guard let db2 = database as? Database2, let entry2 = entry as? Entry2 else {
            return
        }

        guard let customIcon = db2.addCustomIcon(image) else {
            Diag.error("Failed to add custom icon, cancelling")
            return
        }
        db2.setCustomIcon(customIcon, for: entry2)
        fieldEditorVC.shouldHighlightIcon = true
        isModified = true
    }

    func showIconPicker() {
        let iconPickerCoordinator = ItemIconPickerCoordinator(
            router: router,
            databaseFile: databaseFile,
            customFaviconUrl: URL.from(malformedString: entry.resolvedURL)
        )
        iconPickerCoordinator.item = entry
        iconPickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        iconPickerCoordinator.delegate = self
        iconPickerCoordinator.start()
        addChildCoordinator(iconPickerCoordinator)
    }
}

extension EntryFieldEditorCoordinator: NavigationRouterDismissAttemptDelegate {
    func didAttemptToDismiss(navigationRouter: NavigationRouter) {
        didPressCancel(in: fieldEditorVC)
    }
}

extension EntryFieldEditorCoordinator: EntryFieldEditorDelegate {
    func isTOTPSetupAvailable(_ viewController: EntryFieldEditorVC) -> Bool {
        return database is Database2
    }

    func isQRScannerAvailable(_ viewController: EntryFieldEditorVC) -> Bool {
        return qrCodeScanner.deviceSupportsQRScanning
    }

    func didPressQRCodeOTPSetup(in viewController: EntryFieldEditorVC) {
        qrCodeScanner.scanQRCode(presenter: viewController) { [weak self] result in
            switch result {
            case .failure(let error):
                self?.fieldEditorVC.showNotification(error.localizedDescription)
            case .success(let scannedText):
                self?.setOTPConfig(uri: scannedText, isQRBased: true)
            }
        }
    }

    func didPressManualOTPSetup(in viewController: EntryFieldEditorVC) {
        let alert = UIAlertController.make(
            title: LString.otpEnterSecretCodeTitle,
            message: nil,
            dismissButtonTitle: LString.actionCancel)
        alert.addTextField { textField in
            textField.placeholder = LString.otpSecretCodePlaceholder
        }
        alert.addAction(title: LString.actionDone, style: .default) { [weak self, weak alert] _ in
            guard let self, let alert else { return }
            guard let textField = alert.textFields?.first,
                  let text = textField.text
            else {
                return
            }
            self.setOTPConfig(unfilteredSeed: text)
        }

        viewController.present(alert, animated: true)
    }

    func didPressCancel(in viewController: EntryFieldEditorVC) {
        guard isModified else {
            router.pop(animated: true)
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: LString.messageUnsavedChanges,
            preferredStyle: .alert)
        alert.addAction(title: LString.actionEdit, style: .cancel, handler: nil)
        alert.addAction(title: LString.actionDiscard, style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.router.pop(animated: true)
        }
        router.present(alert, animated: true, completion: nil)
    }

    func didPressDone(in viewController: EntryFieldEditorVC) {
        saveChangesAndDismiss()
    }

    func didModifyContent(in viewController: EntryFieldEditorVC) {
        isModified = true
    }

    func didPressAddField(in viewController: EntryFieldEditorVC) {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Tried to add custom field to an entry which does not support them")
            return
        }
        let newField = entry2.makeEntryField(
            name: LString.defaultNewCustomFieldName,
            value: "",
            isProtected: true)
        entry2.fields.append(newField)
        fields.append(EditableField(field: newField))
        fieldEditorVC.fields = fields
        isModified = true
    }

    func didPressDeleteField(_ field: EditableField, in viewController: EntryFieldEditorVC) {
        guard let entry2 = entry as? Entry2,
              let fieldIndex = fields.firstIndex(where: { $0 === field }),
              let entryField = field.field
        else {
            assertionFailure()
            return
        }
        entry2.removeField(entryField)
        fields.remove(at: fieldIndex)
        fieldEditorVC.fields = fields
        isModified = true
    }

    func didPressPasswordGenerator(
        for input: TextInputView,
        viaMenu: Bool,
        in viewController: EntryFieldEditorVC
    ) {
        showPasswordGenerator(for: input, quickMode: viaMenu, in: viewController)
    }

    func getUserNameGeneratorMenu(
        for field: EditableField,
        in viewController: EntryFieldEditorVC
    ) -> UIMenu? {
        return makeUserNameGeneratorMenu(for: field)
    }

    func didPressPickIcon(in viewController: EntryFieldEditorVC) {
        showIconPicker()
    }

    func didPressDownloadFavicon(for field: EditableField, in viewController: EntryFieldEditorVC) {
        guard let value = field.resolvedValue,
              let url = URL.from(malformedString: value)
        else {
            return
        }

        viewController.isDownloadingFavicon = true
        refresh() 
        downloadFavicon(for: url, in: viewController) { [weak self, weak viewController] image in
            guard let self, let viewController else { return }
            viewController.isDownloadingFavicon = false
            if let image {
                self.changeIcon(image: image)
            }
            refresh()
        }
    }

    func didPressTags(in viewController: EntryFieldEditorVC) {
        guard database is Database2 else {
            assertionFailure("Tried to edit tags in KDB file, this must be blocked by UI")
            return
        }

        let tagsCoordinator = TagSelectorCoordinator(
            item: entry,
            parent: originalEntry?.parent,
            databaseFile: databaseFile,
            router: router
        )
        tagsCoordinator.delegate = self
        tagsCoordinator.dismissHandler = { [weak self, tagsCoordinator] coordinator in
            self?.applyTags(tags: tagsCoordinator.selectedTags)
            self?.removeChildCoordinator(coordinator)
        }
        tagsCoordinator.start()
        addChildCoordinator(tagsCoordinator)
    }

    private func applyTags(tags: [String]) {
        assert(database is Database2)
        guard entry.tags != tags else {
            return
        }
        entry.tags = tags
        isModified = true
        refreshTags()
    }

    private func refreshTags() {
        guard let (updatedField, _) = ViewableEntryFieldFactory.makeTags(
            from: entry,
            parent: originalEntry?.parent,
            includeEmpty: true
        ) else {
            return
        }

        guard updatedField.value != tagsField?.value else {
            return
        }
        tagsField?.value = updatedField.value
        fieldEditorVC.refresh()
    }
}

extension EntryFieldEditorCoordinator: TagSelectorCoordinatorDelegate {
    func didUpdateTags(in coordinator: TagSelectorCoordinator) {
        refreshTags()
        delegate?.didUpdateEntry(entry, in: self)
    }
}

extension EntryFieldEditorCoordinator: ItemIconPickerCoordinatorDelegate {
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: url)
    }

    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator) {
        entry.iconID = standardIcon
        if let entry2 = entry as? Entry2 {
            entry2.customIconUUID = .ZERO
        }
        isModified = true
        refresh()
    }

    func didSelectIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator) {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Entry does not support custom icons")
            return
        }
        guard entry2.customIconUUID != customIcon else {
            return
        }
        entry2.customIconUUID = customIcon
        isModified = true
        refresh()
    }

    func didDeleteIcon(customIcon: UUID, in coordinator: ItemIconPickerCoordinator) {
        if let entry2 = entry as? Entry2,
           entry2.customIconUUID == customIcon
        {
            delegate?.didUpdateEntry(entry, in: self)
            refresh()
        }
    }
}

extension EntryFieldEditorCoordinator: PasswordGeneratorCoordinatorDelegate {
    func didAcceptPassword(_ password: String, in coordinator: PasswordGeneratorCoordinator) {
        guard let context = coordinator.context,
              let targetInput = context as? TextInputView
        else {
            assertionFailure("There is no target for the generated password")
            return
        }
        targetInput.replaceText(in: targetInput.selectedOrFullTextRange, withText: password)
        self.isModified = true
        fieldEditorVC.revalidate()
        fieldEditorVC.refresh()
    }
}

extension EntryFieldEditorCoordinator: FaviconDownloading {
    var faviconDownloadingProgressHost: ProgressViewHost? { return nil }
}

extension EntryFieldEditorCoordinator: DatabaseSaving {
    func didCancelSaving(databaseFile: DatabaseFile) {
        rollbackPreSaveActions?()
        rollbackPreSaveActions = nil
    }

    func didSave(databaseFile: DatabaseFile) {
        isModified = false

        let changedEntry = originalEntry ?? entry
        delegate?.didUpdateEntry(changedEntry, in: self)

        router.pop(animated: true)
    }

    func didFailSaving(databaseFile: DatabaseFile) {
        rollbackPreSaveActions?()
        rollbackPreSaveActions = nil
    }

    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return fieldEditorVC
    }

    func getDiagnosticsHandler() -> (() -> Void)? {
        return showDiagnostics
    }
}


extension Entry {
    public func applyPreservingHistory(to target: Entry, makeNewUUID: Bool) {
        guard let target2 = target as? Entry2 else {
            self.apply(to: target, makeNewUUID: makeNewUUID)
            return
        }
        let originalHistory = target2.history
        self.apply(to: target2, makeNewUUID: makeNewUUID)
        target2.history = originalHistory
    }
}
