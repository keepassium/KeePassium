//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol EntryFieldEditorCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator)

    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

final class EntryFieldEditorCoordinator: BaseCoordinator {
    private typealias RollbackRoutine = () -> Void

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

    private var qrCodeScanner = { QRCodeScanner() }()

    private let fieldEditorVC: EntryFieldEditorVC

    private var isModified = false {
        didSet {
            fieldEditorVC.isModalInPresentation = isModified
        }
    }

    let faviconDownloader = FaviconDownloader()

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return _router }
    var saveSuccessHandler: (() -> Void)?

    private var tagsField: EntryField?

    init(router: NavigationRouter, databaseFile: DatabaseFile, parent: Group, target: Entry?) {
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.parent = parent
        self.originalEntry = target
        fieldEditorVC = EntryFieldEditorVC.instantiateFromStoryboard()

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

        super.init(router: router)
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
        fieldEditorVC.mostCommonCustomFields = getMostCommonCustomFields()
    }

    private func getMostCommonCustomFields() -> [String] {
        let ignoredCustomFields = [
            EntryField.otpConfig1,
            EntryField.otpConfig2Seed,
            EntryField.otpConfig2Settings,
            EntryField.timeOtpLength,
            EntryField.timeOtpPeriod,
            EntryField.timeOtpPeriod,
            EntryField.timeOtpSecret,
            EntryField.timeOtpAlgorithm,
            EntryField.passkeyCredentialID,
            EntryField.passkeyRelyingParty,
            EntryField.passkeyPrivateKeyPEM,
            EntryField.passkeyUserHandle,
            EntryField.passkeyUsername
        ]

        var names: [String: Int] = [:]
        database.root?.applyToAllChildren(
            groupHandler: nil,
            entryHandler: { entry in
                entry.fields.forEach { field in
                    guard !field.isStandardField else { return }
                    guard !ignoredCustomFields.contains(field.name) else { return }
                    guard !field.isExtraURL else { return }

                    names[field.name, default: 0] += 1
            }
        })
        return names.sorted { $0.value > $1.value }.prefix(5).map { $0.key }
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

    override func start() {
        super.start()
        _pushInitialViewController(fieldEditorVC, animated: true)
        refresh()
    }

    override func refresh() {
        super.refresh()
        fieldEditorVC.entryIcon = UIImage.kpIcon(forEntry: entry)
        fieldEditorVC.refresh()
    }

    private func abortAndDismiss() {
        _router.pop(animated: true)
    }

    private func startSaving() {
        fieldEditorVC.view.endEditing(true)

        let isURLChanged = originalEntry == nil || originalEntry?.resolvedURL != entry.resolvedURL
        let shouldDownloadFavicon =
                isURLChanged
                && !isIconModified()
                && Settings.current.isAutoDownloadFaviconsEnabled
                && Settings.current.isNetworkAccessAllowed
        if shouldDownloadFavicon,
           let websiteURL = URL.from(malformedString: entry.resolvedURL)
        {
            Diag.debug("Auto-downloading favicon")
            fieldEditorVC.isDownloadingFavicon = true
            refresh()
            downloadFavicon(for: websiteURL, in: fieldEditorVC) { [weak self, weak fieldEditorVC] image in
                guard let self, let fieldEditorVC else { return }
                fieldEditorVC.isDownloadingFavicon = false
                if let image {
                    changeIcon(image: image)
                }
                finishSaving()
            }
        } else {
            finishSaving()
        }
    }

    private func finishSaving() {
        entry.touch(.modified, updateParents: false)
        if let originalEntry {
            if originalEntryBeforeSaving == nil {
                originalEntryBeforeSaving = originalEntry.clone(makeNewUUID: false)
                originalEntry.backupState()
            }
            entry.applyPreservingHistory(to: originalEntry, makeNewUUID: false)
            rollbackPreSaveActions = { [weak self] in
                guard let self else { return }
                self.originalEntryBeforeSaving?.apply(to: self.originalEntry!, makeNewUUID: false)
            }
        } else {
            parent.add(entry: entry)
            rollbackPreSaveActions = { [weak self] in
                guard let self else { return }
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

        fieldEditorVC.showNotification(
            LString.actionDone,
            image: .symbol(.clock),
            duration: 1
        )
    }

    private func setOTPConfig(unfilteredSeed: String) {
        if TOTPGeneratorFactory.isValidURI(unfilteredSeed) {
            setOTPConfig(uri: unfilteredSeed, isQRBased: false)
            return
        }
        let seed = unfilteredSeed.replacingOccurrences(of: " ", with: "")
        let otpauthURI = TOTPGeneratorFactory.makeOtpauthURI(
            base32Seed: seed,
            issuer: entry.resolvedTitle.isEmpty ? AppInfo.name : entry.resolvedTitle,
            accountName: entry.resolvedUserName.isEmpty ? nil : entry.resolvedUserName
        )
        setOTPConfig(uri: otpauthURI.absoluteString, isQRBased: false)
    }

    func showPasswordGenerator(
        for textInput: TextInputView,
        quickMode: Bool,
        in viewController: UIViewController
    ) {
        let passGenCoordinator = PasswordGeneratorCoordinator(
            router: _router,
            quickMode: quickMode,
            hasTarget: true
        )
        passGenCoordinator.delegate = self
        passGenCoordinator.context = textInput
        passGenCoordinator.start()
        addChildCoordinator(passGenCoordinator, onDismiss: nil)
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
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: _router)
        diagnosticsViewerCoordinator.start()
        addChildCoordinator(diagnosticsViewerCoordinator, onDismiss: nil)
    }

    private func isIconModified() -> Bool {
        let newIconID = entry.iconID
        let newCustomIconUUID = (entry as? Entry2)?.customIconUUID
        let origIconID = originalEntry?.iconID
        let origCustomIconUUID = (originalEntry as? Entry2)?.customIconUUID
        if let origIconID {
            return newIconID != origIconID || newCustomIconUUID != origCustomIconUUID
        } else {
            let parent2 = parent as? Group2
            return
                (newIconID != Entry.defaultIconID && newIconID != parent.iconID)
                || (newCustomIconUUID != parent2?.customIconUUID)
                || newCustomIconUUID != .ZERO
        }
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
            router: _router,
            databaseFile: databaseFile,
            customFaviconUrl: URL.from(malformedString: entry.resolvedURL)
        )
        iconPickerCoordinator.item = entry
        iconPickerCoordinator.delegate = self
        iconPickerCoordinator.start()
        addChildCoordinator(iconPickerCoordinator, onDismiss: nil)
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

    func shouldProvideAvailableQRSources(for viewController: EntryFieldEditorVC) -> Set<QRCodeSource> {
        return qrCodeScanner.getSupportedSources()
    }

    func didPressPickOTPQRCode(from source: QRCodeSource, in viewController: EntryFieldEditorVC) {
        qrCodeScanner.pickQRCode(source: source, presenter: viewController) {
            [weak self, weak viewController] result in
            guard let self, let viewController else { return }

            switch result {
            case .success(let scannedText):
                if let scannedText {
                    setOTPConfig(uri: scannedText, isQRBased: true)
                }
            case .failure(let scannerError):
                viewController.showNotification(
                    scannerError.localizedDescription,
                    image: .symbol(.exclamationMarkTriangle, tint: .errorMessage),
                    hidePrevious: true
                )
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
            _router.pop(animated: true)
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: LString.messageUnsavedChanges,
            preferredStyle: .alert)
        alert.addAction(title: LString.actionEdit, style: .cancel, handler: nil)
        alert.addAction(title: LString.actionDiscard, style: .destructive) { [weak self] _ in
            self?._router.pop(animated: true)
        }
        _router.present(alert, animated: true, completion: nil)
    }

    func didPressDone(in viewController: EntryFieldEditorVC) {
        startSaving()
    }

    func didModifyContent(in viewController: EntryFieldEditorVC) {
        isModified = true
    }

    func didPressAddField(name: String?, in viewController: EntryFieldEditorVC) -> EntryField? {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Tried to add custom field to an entry which does not support them")
            return nil
        }
        let newField = entry2.makeEntryField(
            name: name ?? LString.defaultNewCustomFieldName,
            value: "",
            isProtected: true)
        entry2.fields.append(newField)
        fields.append(EditableField(field: newField))
        fieldEditorVC.fields = fields
        isModified = true
        return newField
    }

    func didPressAddURLField(in viewController: EntryFieldEditorVC) -> EntryField? {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Tried to add custom field to an entry which does not support them")
            return nil
        }
        let newURLField = entry2.makeExtraURLField(value: "https://")

        entry2.fields.append(newURLField)
        fields.append(EditableField(field: newURLField))
        fieldEditorVC.fields = fields
        isModified = true
        return newURLField
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
            router: _router
        )
        tagsCoordinator.delegate = self
        tagsCoordinator.start()
        addChildCoordinator(tagsCoordinator, onDismiss: { [weak self, weak tagsCoordinator] _ in
            guard let self, let tagsCoordinator else { return }
            applyTags(tags: tagsCoordinator.selectedTags)
        })
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

        _router.pop(animated: true)
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
