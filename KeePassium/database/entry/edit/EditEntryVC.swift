//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol EditEntryFieldsDelegate: class {
    func entryEditor(entryDidChange entry: Entry)
}

final class EditEntryVC: UITableViewController, Refreshable {
    @IBOutlet private weak var addFieldButton: UIBarButtonItem!
    @IBOutlet private weak var scanOTPButton: UIButton!

    private weak var entry: Entry? {
        didSet {
            rememberOriginalState()
            addFieldButton.isEnabled = entry?.isSupportsExtraFields ?? false
        }
    }
    private weak var delegate: EditEntryFieldsDelegate?
    private var fields = [EditableField]()
    private var isModified = false {
        didSet {
            if #available(iOS 13.0, *) {
                isModalInPresentation = isModified
            }
        }
    }
    public enum Mode {
        case create
        case edit
    }
    private var mode: Mode = .edit

    private let qrCodeScanner = YubiKitQRCodeScanner()
    
    var itemIconPickerCoordinator: ItemIconPickerCoordinator? 
    var diagnosticsViewerCoordinator: DiagnosticsViewerCoordinator?
    
    static func make(
        createInGroup group: Group,
        popoverSource: UIView?,
        delegate: EditEntryFieldsDelegate?
        ) -> UIViewController
    {
        let newEntry = group.createEntry()
        newEntry.populateStandardFields()
        if group.iconID == Group.defaultIconID || group.iconID == Group.defaultOpenIconID {
            newEntry.iconID = Entry.defaultIconID
        } else {
            newEntry.iconID = group.iconID
        }
        
        if let newEntry2 = newEntry as? Entry2, let group2 = group as? Group2 {
            newEntry2.customIconUUID = group2.customIconUUID
            newEntry2.rawUserName = (group2.database as? Database2)?.defaultUserName ?? ""
        }
        newEntry.rawTitle = LString.defaultNewEntryName
        return make(mode: .create, entry: newEntry, popoverSource: popoverSource, delegate: delegate)
    }
    
    static func make(
        entry: Entry,
        popoverSource: UIView?,
        delegate: EditEntryFieldsDelegate?
        ) -> UIViewController
    {
        return make(mode: .edit, entry: entry, popoverSource: popoverSource, delegate: delegate)
    }

    private static func make(
        mode: Mode,
        entry: Entry,
        popoverSource: UIView?,
        delegate: EditEntryFieldsDelegate?
        ) -> UIViewController
    {
        let editEntryVC = EditEntryVC.instantiateFromStoryboard()
        editEntryVC.mode = mode
        editEntryVC.entry = entry
        guard let database = entry.database else { fatalError() }
        editEntryVC.fields = EditableFieldFactory.makeAll(from: entry, in: database)
        editEntryVC.delegate = delegate

        let navVC = UINavigationController(rootViewController: editEntryVC)
        navVC.modalPresentationStyle = .formSheet
        navVC.presentationController?.delegate = editEntryVC
        if let popover = navVC.popoverPresentationController, let popoverSource = popoverSource {
            popover.sourceView = popoverSource
            popover.sourceRect = popoverSource.bounds
        }
        return navVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0

        if !qrCodeScanner.deviceSupportsQRScanning {
            tableView.tableFooterView = nil
        }

        scanOTPButton.setTitle(LString.otpScanQRCodeForSetup, for: .normal)
        
        entry?.touch(.accessed)
        
        refresh()
        if mode == .create {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.8)
            {
                [weak self] in
                let firstRow = IndexPath(row: 0, section: 0)
                let titleCell = self?.tableView.cellForRow(at: firstRow) as? EditEntryTitleCell
                _ = titleCell?.becomeFirstResponder()
            }
        }
    }
    
    deinit {
        itemIconPickerCoordinator = nil
        diagnosticsViewerCoordinator = nil
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        resignFirstResponder()
        super.dismiss(animated: flag, completion: { [weak self] in
            self?.itemIconPickerCoordinator = nil
            self?.diagnosticsViewerCoordinator = nil
            completion?()
        })
    }
    
    private var originalEntry: Entry? 
    
    func rememberOriginalState() {
        guard let entry = entry else { fatalError() }
        if mode == .edit {
            entry.backupState() 
        }
        originalEntry = entry.clone(makeNewUUID: false)
    }
    
    func restoreOriginalState() {
        switch mode {
        case .create:
            entry?.deleteWithoutBackup()
        case .edit:
            if let entry = entry, let originalEntry = originalEntry {
                originalEntry.apply(to: entry, makeNewUUID: false)
                EntryChangeNotifications.post(entryDidChange: entry)
            }
        }
    }

    @IBAction private func onScanOTPAction(_ sender: Any) {
        guard qrCodeScanner.deviceSupportsQRScanning else {
            return
        }

        guard let otpField = fields.first(where: { $0.internalName == EntryField.otp }),
              let value = otpField.value,
              !value.isEmpty
        else {
            scanQRCode()
            return
        }

        let choiceAlert = UIAlertController(
            title: LString.titleWarning,
            message: LString.otpQRCodeOverwriteWarning,
            preferredStyle: .alert)
        choiceAlert.addAction(UIAlertAction(title: LString.actionOverwrite, style: .destructive) { [weak self] (action) in
            self?.scanQRCode()
        })
        choiceAlert.addAction(UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil))
        present(choiceAlert, animated: true, completion: nil)
    }

    private func scanQRCode() {
        qrCodeScanner.scanQRCode(presenter: self) { [weak self] result in
            switch result {
            case let .failure(error):
                self?.showError(message: error.localizedDescription, reason: nil)
            case let .success(data):
                self?.setOTPCode(data: data)
            }
        }
    }

    private func setOTPCode(data: String) {
        guard TOTPGeneratorFactory.isValid(data) else {
            showError(message: LString.otpQRCodeNotValid, reason: nil)
            return
        }

        guard let entry = entry, let database = entry.database else {
            Diag.warning("Not saving scanned OTP code because the entry or database is already nil")
            return
        }

        entry.setField(name: EntryField.otp, value: data, isProtected: true)
        isModified = true

        if !fields.contains(where: { $0.internalName == EntryField.otp }) {
            fields = EditableFieldFactory.makeAll(from: entry, in: database)
        }
        refresh()
    }

    @IBAction private func onCancelAction(_ sender: Any) {
        if isModified {
            let alertController = UIAlertController(
                title: nil,
                message: LString.messageUnsavedChanges,
                preferredStyle: .alert)
            let discardAction = UIAlertAction(title: LString.actionDiscard, style: .destructive)
            {
                [weak self] _ in
                guard let _self = self else { return }
                _self.restoreOriginalState()
                _self.dismiss(animated: true, completion: nil)
            }
            let editAction = UIAlertAction(title: LString.actionEdit, style: .cancel, handler: nil)
            alertController.addAction(editAction)
            alertController.addAction(discardAction)
            present(alertController, animated: true, completion: nil)
        } else {
            if mode == .create {
                restoreOriginalState()
            }
            dismiss(animated: true, completion: nil)
        }
    }
    
    @IBAction func onSaveAction(_ sender: Any) {
        applyChangesAndSaveDatabase()
    }
    
    @IBAction func didPressAddField(_ sender: Any) {
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
        
        let newIndexPath = IndexPath(row: fields.count - 1, section: 0)
        tableView.beginUpdates()
        tableView.insertRows(at: [newIndexPath], with: .fade)
        tableView.endUpdates()
        
        UIView.animate(
            withDuration: 0.3,
            animations: { [self] in
                self.tableView.scrollToRow(at: newIndexPath, at: .top, animated: false) 
            },
            completion: { [weak self] finished in
                let insertedCell = self?.tableView.cellForRow(at: newIndexPath)
                insertedCell?.becomeFirstResponder()
                (insertedCell as? EditEntryCustomFieldCell)?.selectNameText()
            }
        )
        
        isModified = true
        revalidate()
    }
    
    func didPressDeleteField(at indexPath: IndexPath) {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Tried to remove a field from a non-KP2 entry")
            return
        }

        let fieldNumber = indexPath.row
        let editableField = fields[fieldNumber]
        guard let entryField = editableField.field else { return }
        
        entry2.removeField(entryField)
        fields.remove(at: fieldNumber)

        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
        
        isModified = true
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fields.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        guard let entry = entry else {
            assertionFailure();
            return UITableViewCell()
        }
        
        let fieldNumber = indexPath.row
        let field = fields[fieldNumber]
        if field.internalName == EntryField.title { 
            let cell = tableView.dequeueReusableCell(
                withIdentifier: EditEntryTitleCell.storyboardID,
                for: indexPath)
                as! EditEntryTitleCell
            cell.delegate = self
            cell.icon = UIImage.kpIcon(forEntry: entry)
            cell.field = field
            return cell
        }
        
        let cell = EditableFieldCellFactory
            .dequeueAndConfigureCell(from: tableView, for: indexPath, field: field)
        cell.delegate = self
        cell.validate() 
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let fieldNumber = indexPath.row
        return !fields[fieldNumber].isFixed
    }
    
    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
        ) -> UITableViewCell.EditingStyle
    {
        return UITableViewCell.EditingStyle.delete
    }
    
    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath)
    {
        if editingStyle == .delete {
            didPressDeleteField(at: indexPath)
        }
    }

    
    func refresh() {
        guard let entry = entry else { return }
        let category = ItemCategory.get(for: entry)
        fields.sort { category.compare($0.internalName, $1.internalName)}
        revalidate()
        tableView.reloadData()
    }
    
    func revalidate() {
        var isAllFieldsValid = true
        for field in fields {
            field.isValid = isFieldValid(field: field)
            isAllFieldsValid = isAllFieldsValid && field.isValid
        }
        tableView.visibleCells.forEach {
            ($0 as? EditableFieldCell)?.validate()
        }
        navigationItem.rightBarButtonItem?.isEnabled = isAllFieldsValid
    }
    
    private func showDiagnostics() {
        assert(diagnosticsViewerCoordinator == nil)
        guard let navigationController = self.navigationController else {
            assertionFailure()
            return
        }
        let router = NavigationRouter(navigationController)
        diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator!.dismissHandler = { [weak self] coordinator in
            self?.diagnosticsViewerCoordinator = nil
        }
        diagnosticsViewerCoordinator!.start()
    }
    
    
    func applyChangesAndSaveDatabase() {
        guard let entry = entry else { return }
        entry.touch(.modified, updateParents: false)
        view.endEditing(true)
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }

    private var savingOverlay: ProgressOverlay?
    
    private func showSavingOverlay() {
        navigationController?.setNavigationBarHidden(true, animated: true)
        if #available(iOS 13, *) {
            isModalInPresentation = true 
        }
        savingOverlay = ProgressOverlay.addTo(
            navigationController?.view ?? self.view,
            title: LString.databaseStatusSaving,
            animated: true)
        savingOverlay?.isCancellable = true
    }
    
    private func hideSavingOverlay() {
        guard savingOverlay != nil else { return }
        navigationController?.setNavigationBarHidden(false, animated: true)
        savingOverlay?.dismiss(animated: true) {
            [weak self] (finished) in
            guard let _self = self else { return }
            _self.savingOverlay?.removeFromSuperview()
            _self.savingOverlay = nil
        }
    }
}

extension EditEntryVC: ValidatingTextFieldDelegate {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        entry?.rawTitle = text
        isModified = true
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return sender.text?.isNotEmpty ?? false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        revalidate()
    }
}


extension EditEntryVC: EditableFieldCellDelegate {
    func didPressButton(field: EditableField, in cell: EditableFieldCell) {
        if cell is EditEntryTitleCell {
            guard let button = (cell as! EditEntryTitleCell).changeIconButton else { fatalError() }
            let popoverAnchor = PopoverAnchor(sourceView: button, sourceRect: button.bounds)
            didPressChangeIcon(in: cell, at: popoverAnchor)
        } else if cell is EditEntrySingleLineProtectedCell {
            didPressRandomize(field: field, in: cell)
        } else if field.internalName == EntryField.userName {
            didPressChooseUserName(field: field, in: cell)
        }
    }
    
    func didPressChangeIcon(in cell: EditableFieldCell, at popoverAnchor: PopoverAnchor) {
        showIconPicker(at: popoverAnchor)
    }

    func didPressReturn(in cell: EditableFieldCell) {
        onSaveAction(self)
    }

    func didChangeField(field: EditableField, in cell: EditableFieldCell) {
        isModified = true
        revalidate()
    }
    
    func didPressRandomize(field: EditableField, in cell: EditableFieldCell) {
        let vc = PasswordGeneratorVC.make(completion: {
            [weak self] (password) in
            guard let _self = self else { return }
            guard let newValue = password else { return } 
            field.value = newValue
            _self.isModified = true
            _self.revalidate()
        })
        navigationController?.pushViewController(vc, animated: true)
    }
    
    func didPressChooseUserName(field: EditableField, in cell: EditableFieldCell) {
        guard let database = entry?.database,
            let userNameCell = cell as? EditEntrySingleLineCell
            else { return }
        
        let textField = userNameCell.textField!
        textField.becomeFirstResponder()

        let nameChooser = UIAlertController(
            title: LString.fieldUserName,
            message: nil,
            preferredStyle: .actionSheet)
        for userName in UserNameHelper.getUserNameSuggestions(from: database, count: 4) {
            let action = UIAlertAction(title: userName, style: .default) {
                [weak self, weak field, weak userNameCell] (action: UIAlertAction) in
                self?.isModified = true
                field?.value = userName
                userNameCell?.textField.text = userName
                userNameCell?.validate()
            }
            nameChooser.addAction(action)
        }
        
        let randomUserName = UserNameHelper.getRandomUserName()
        let randomTitle = LString.directionAwareConcatenate(["🎲", " ", randomUserName])
        let randomUserNameAction = UIAlertAction(title: randomTitle, style: .default) {
            [weak self, weak field, weak userNameCell] (action: UIAlertAction) in
            self?.isModified = true
            field?.value = randomUserName
            userNameCell?.textField.text = randomUserName
            userNameCell?.validate()
        }
        nameChooser.addAction(randomUserNameAction)
        
        nameChooser.addAction(
            UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil))
        
        nameChooser.modalPresentationStyle = .popover
        if let popover = nameChooser.popoverPresentationController {
            popover.sourceView = textField
            popover.sourceRect = textField.bounds
            popover.permittedArrowDirections = [.up, .down]
        }
        self.present(nameChooser, animated: true, completion: nil)
    }
    
    func isFieldValid(field: EditableField) -> Bool {
        if field.internalName == EntryField.title {
            return field.value?.isNotEmpty ?? false
        }
        
        if field.internalName.isEmpty {
            return false
        }
        
        var sameNameCount = 0
        for f in fields {
            if f.internalName == field.internalName  {
                sameNameCount += 1
            }
        }
        return (sameNameCount == 1)
    }
}

extension EditEntryVC: ItemIconPickerCoordinatorDelegate {
    func showIconPicker(at popoverAnchor: PopoverAnchor) {
        assert(itemIconPickerCoordinator == nil)
        
        let router = NavigationRouter(navigationController!)
        itemIconPickerCoordinator = ItemIconPickerCoordinator(router: router)
        itemIconPickerCoordinator!.dismissHandler = { [weak self] (coordinator) in
            self?.itemIconPickerCoordinator = nil
        }
        itemIconPickerCoordinator!.delegate = self
        itemIconPickerCoordinator!.start(selectedIconID: entry?.iconID)
    }
    
    func didSelectIcon(standardIcon: IconID, in coordinator: ItemIconPickerCoordinator) {
        guard let entry = entry else { return }
        guard standardIcon != entry.iconID else { return }
        
        entry.iconID = standardIcon
        isModified = true
        refresh()
    }
}

extension EditEntryVC: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        showSavingOverlay()
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        savingOverlay?.update(with: progress)
    }

    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        hideSavingOverlay()
        if let entry = self.entry {
            delegate?.entryEditor(entryDidChange: entry)
            EntryChangeNotifications.post(entryDidChange: entry)
        }
        dismiss(animated: true, completion: nil)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        hideSavingOverlay()
    }
    
    func databaseManager(
        database urlRef: URLReference,
        savingError message: String,
        reason: String?)
    {
        DatabaseManager.shared.removeObserver(self)
        hideSavingOverlay()
        showError(message: message, reason: reason)
    }
    
    private func showError(message: String, reason: String?) {
        let errorAlert = UIAlertController.make(
            title: message,
            message: reason,
            cancelButtonTitle: LString.actionDismiss)
        let showDetailsAction = UIAlertAction(title: LString.actionShowDetails, style: .default) {
            [weak self] _ in
            self?.showDiagnostics()
        }
        errorAlert.addAction(showDetailsAction)
        present(errorAlert, animated: true, completion: nil)
    }
}

extension EditEntryVC: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(
        _ presentationController: UIPresentationController)
    {
        guard savingOverlay == nil else {
            return
        }
        onCancelAction(presentationController) 
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onCancelAction(presentationController) 
    }
}
