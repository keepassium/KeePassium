//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryFieldEditorCoordinatorDelegate: AnyObject {
    func didUpdateEntry(_ entry: Entry, in coordinator: EntryFieldEditorCoordinator)
}

final class EntryFieldEditorCoordinator: Coordinator, DatabaseSaving {
    private typealias RollbackRoutine = () -> Void
    
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: EntryFieldEditorCoordinatorDelegate?
    
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
    
    private var isModified = false{
        didSet {
            if #available(iOS 13, *) {
                fieldEditorVC.isModalInPresentation = isModified
            }
        }
    }
    
    internal var databaseExporterTemporaryURL: TemporaryFileURL?
        
    init(router: NavigationRouter, database: Database, parent: Group, target: Entry?) {
        self.router = router
        self.database = database
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
        entry.touch(.accessed)
        fields = EditableFieldFactory.makeAll(from: entry, in: database)
        
        fieldEditorVC = EntryFieldEditorVC.instantiateFromStoryboard()
        fieldEditorVC.delegate = self
        fieldEditorVC.fields = fields
        fieldEditorVC.entryIcon = UIImage.kpIcon(forEntry: entry)
        fieldEditorVC.allowsCustomFields = entry.isSupportsExtraFields
        fieldEditorVC.itemCategory = ItemCategory.get(for: entry)
        fieldEditorVC.shouldFocusOnTitleField = isCreationMode
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        router.push(fieldEditorVC, animated: true, onPop: {
            [weak self] viewController in
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
        
        let databaseManager = DatabaseManager.shared
        databaseManager.addObserver(self)
        databaseManager.startSavingDatabase()
    }
    
    private func setOTPCode(data: String) {
        guard TOTPGeneratorFactory.isValid(data) else {
            fieldEditorVC.showNotification(LString.otpQRCodeNotValid)
            return
        }

        entry.setField(name: EntryField.otp, value: data, isProtected: true)
        isModified = true

        if !fields.contains(where: { $0.internalName == EntryField.otp }) {
            fields = EditableFieldFactory.makeAll(from: entry, in: database)
            fieldEditorVC.fields = fields
        }
        refresh()
    }
    
    private func showPasswordGenerator(
        at popoverAnchor: PopoverAnchor,
        completion: @escaping (String?)->Void
    ) {
        let vc = PasswordGeneratorVC.make(completion: completion)
        router.push(vc, animated: true, onPop: nil)
    }
    
    private func showUserNameGenerator(
        at popoverAnchor: PopoverAnchor,
        completion: @escaping (String?)->Void
    ) {
        let namePicker = UIAlertController(
            title: LString.fieldUserName,
            message: nil,
            preferredStyle: .actionSheet)
        let userNames = UserNameHelper.getUserNameSuggestions(from: database, count: 4)
        userNames.forEach { userName in
            namePicker.addAction(title: userName, style: .default) { _ in
                completion(userName)
            }
        }
        
        let randomUserName = UserNameHelper.getRandomUserName()
        let randomTitle = LString.directionAwareConcatenate(["🎲", " ", randomUserName])
        namePicker.addAction(title: randomTitle, style: .default) { _ in
            completion(randomUserName)
        }
        
        namePicker.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        
        namePicker.modalPresentationStyle = .popover
        if let popover = namePicker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
            popover.permittedArrowDirections = [.up, .down]
        }
        router.present(namePicker, animated: true, completion: nil)
    }
    
    private func showDiagnostics() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        diagnosticsViewerCoordinator.start()
        addChildCoordinator(diagnosticsViewerCoordinator)
    }
    
    func showIconPicker(at popoverAnchor: PopoverAnchor) {
        let iconPickerCoordinator = ItemIconPickerCoordinator(router: router, database: database)
        iconPickerCoordinator.item = entry
        iconPickerCoordinator.dismissHandler = { [weak self] (coordinator) in
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
        let isCompatibleHardware = qrCodeScanner.deviceSupportsQRScanning
        let isCompatibleDatabase = database is Database2
        return isCompatibleHardware && isCompatibleDatabase
    }
    
    func didPressScanQRCode(in viewController: EntryFieldEditorVC) {
        qrCodeScanner.scanQRCode(presenter: viewController) {
            [weak self] result in
            switch result {
            case .failure(let error):
                self?.fieldEditorVC.showNotification(error.localizedDescription)
            case .success(let data):
                self?.setOTPCode(data: data)
            }
        }
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
        alert.addAction(title: LString.actionDiscard, style: .destructive) {
            [weak self] _ in
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
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldEditorVC
    ) {
        showPasswordGenerator(at: popoverAnchor) {
            [weak self, weak field] password in
            guard let self = self,
                  let field = field,
                  password != nil else { return }
            field.value = password
            self.isModified = true
            self.fieldEditorVC.revalidate()
        }
    }
    
    func didPressUserNameGenerator(
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldEditorVC
    ) {
        showUserNameGenerator(at: popoverAnchor, completion: {
            [weak self, weak field] (userName) in
            guard let self = self,
                  let field = field,
                  userName != nil else { return }
            field.value = userName
            self.isModified = true
            self.refresh()
        })
    }
    
    func didPressPickIcon(at popoverAnchor: PopoverAnchor, in viewController: EntryFieldEditorVC) {
        showIconPicker(at: popoverAnchor)
    }
}

extension EntryFieldEditorCoordinator: ItemIconPickerCoordinatorDelegate {
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator) {
        guard standardIcon != entry.iconID else { return }
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

extension EntryFieldEditorCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        router.showProgressView(title: LString.databaseStatusSaving, allowCancelling: true)
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        rollbackPreSaveActions?()
        rollbackPreSaveActions = nil
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        isModified = false

        let changedEntry = originalEntry ?? entry
        delegate?.didUpdateEntry(changedEntry, in: self)
        EntryChangeNotifications.post(entryDidChange: changedEntry)

        router.hideProgressView()
        router.pop(animated: true)
    }
    
    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?)
    {
        DatabaseManager.shared.removeObserver(self)
        router.hideProgressView()
        
        rollbackPreSaveActions?()
        rollbackPreSaveActions = nil
        
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: { [weak self] in
                self?.showDiagnostics()
            },
            exportableData: data,
            parent: fieldEditorVC
        )
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
