//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol EditEntryFieldsDelegate: class {
    func entryEditor(entryDidChange entry: Entry)
}


class EditEntryTitleCell: UITableViewCell {
    public static let storyboardID = "TitleCell"
    
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleTextField: ValidatingTextField!
    @IBOutlet weak var changeIconButton: UIButton!
    
    fileprivate weak var entryEditor: EditEntryVC?
    @IBAction func didPressChangeIcon(_ sender: Any) {
        entryEditor?.showIconChooser()
    }
}

class EditEntryVC: UITableViewController, Refreshable {
    private static let storyboardID = "EditEntryFieldsVC"
    @IBOutlet weak var addFieldButton: UIBarButtonItem!
    
    private weak var entry: Entry? {
        didSet {
            rememberOriginalState()
            addFieldButton.isEnabled = entry?.isSupportsExtraFields ?? false
        }
    }
    weak private var delegate: EditEntryFieldsDelegate?
    private var fields: [EditableEntryField]!
    private var isModified = false 
    private var savingOverlay: UIAlertController?
    
    public enum Mode {
        case create
        case edit
    }
    private var mode: Mode = .edit
    
    static func make(parent group: Group, popoverSource: UIView?, delegate: EditEntryFieldsDelegate?) -> UIViewController {
        let newEntry = group.createEntry()
        newEntry.populateStandardFields()
        newEntry.title = String.Localized.defaultNewEntryName
        return make(mode: .create, entry: newEntry, popoverSource: popoverSource, delegate: delegate)
    }
    
    static func make(mode: Mode, entry: Entry, popoverSource: UIView?, delegate: EditEntryFieldsDelegate?) -> UIViewController {
        let editEntryVC = AppStoryboard.entry.instance.instantiateViewController(withIdentifier: EditEntryVC.storyboardID) as! EditEntryVC
        editEntryVC.mode = .edit
        editEntryVC.entry = entry
        editEntryVC.delegate = delegate
        editEntryVC.fields = EditableEntryField.extractAll(from: entry)
        
        let navVC = ProgressNavigationController(rootViewController: editEntryVC)
        navVC.modalPresentationStyle = .formSheet
        if let popover = navVC.popoverPresentationController, let popoverSource = popoverSource {
            popover.sourceView = popoverSource
            popover.sourceRect = popoverSource.bounds
        }
        return navVC
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }
    
    
    private var originalEntry: Entry? 
    
    func rememberOriginalState() {
        guard let entry = entry else { preconditionFailure() }
        originalEntry = entry.clone()
    }
    
    func restoreOriginalState() {
        if let entry = entry, let originalEntry = originalEntry {
            originalEntry.apply(to: entry)
        }
    }

    
    @IBAction func onCancelAction(_ sender: Any) {
        if isModified {
            let alertController = UIAlertController(title: nil, message: String.Localized.messageUnsavedChanges, preferredStyle: .alert)
            let discardAction = UIAlertAction(title: String.Localized.actionDiscard, style: .destructive, handler: { _ in
                self.restoreOriginalState()
                self.dismiss(animated: true, completion: nil)
            })
            let editAction = UIAlertAction(title: String.Localized.actionEdit, style: .cancel, handler: nil)
            alertController.addAction(editAction)
            alertController.addAction(discardAction)
            present(alertController, animated: true, completion: nil)
        } else {
            self.dismiss(animated: true, completion: nil)
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
        let newField = entry2.makeEntryField(name: String.Localized.defaultNewCustomFieldName,
                                             value: "",
                                             isProtected: true)
        entry2.fields.append(newField)
        fields.append(EditableEntryField(field: newField))
        
        let newIndexPath = IndexPath(row: fields.count - 1, section: 0)
        tableView.beginUpdates()
        tableView.insertRows(at: [newIndexPath], with: .fade)
        tableView.endUpdates()
        tableView.scrollToRow(at: newIndexPath, at: .top, animated: false) 
        let insertedCell = tableView.cellForRow(at: newIndexPath)
        insertedCell?.becomeFirstResponder()
        (insertedCell as? EditEntryCustomFieldCell)?.selectNameText()
        
        isModified = true
        revalidate()
    }
    
    func didPressDeleteField(at indexPath: IndexPath) {
        guard let entry2 = entry as? Entry2 else {
            assertionFailure("Tried to remove a field from an entry which does not support custom fields")
            return
        }

        let fieldNumber = indexPath.row
        let visibleField = fields[fieldNumber]
        
        entry2.removeField(visibleField.field)
        fields.remove(at: fieldNumber)

        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
        
        isModified = true
        revalidate()
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startObservingWatchdog()
        refresh()
    }
    override func onWatchdogTimeout() {
        self.dismiss(animated: false, completion: nil)
    }
    override func viewDidDisappear(_ animated: Bool) {
        stopObservingWatchdog()
        super.viewDidDisappear(animated)
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("fields.count: \(fields.count)")
        return fields.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let entry = entry else { fatalError() }
        
        let fieldNumber = indexPath.row
        let field = fields[fieldNumber]
        if field.internalName == EntryField.title {
            let cell = tableView.dequeueReusableCell(withIdentifier: EditEntryTitleCell.storyboardID, for: indexPath) as! EditEntryTitleCell
            cell.entryEditor = self // to forward "Choose Icon" action
            cell.iconView.image = UIImage.kpIcon(forEntry: entry, large: true)
            cell.titleTextField.text = field.value
            cell.titleTextField.validityDelegate = self
            return cell
        }
        
        if !field.isFixed {
            let cell = tableView.dequeueReusableCell(withIdentifier: EditEntryCustomFieldCell.storyboardID, for: indexPath) as! EditEntryCustomFieldCell
            cell.delegate = self
            cell.field = field
            field.cell = cell
            return cell
        } else if field.isSingleline {
            let cell = tableView.dequeueReusableCell(withIdentifier: EditEntrySingleLineCell.storyboardID, for: indexPath) as! EditEntrySingleLineCell
            cell.delegate = self
            cell.field = field
            field.cell = cell
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: EditEntryMultiLineCell.storyboardID, for: indexPath) as! EditEntryMultiLineCell
            cell.delegate = self
            cell.field = field
            field.cell = cell
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let fieldNumber = indexPath.row
        return !fields[fieldNumber].isFixed
    }
    
    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.delete
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            didPressDeleteField(at: indexPath)
        } else if editingStyle == .insert {
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
            if let cell = field.cell {
                cell.validate()
            }
        }
        navigationItem.rightBarButtonItem?.isEnabled = isAllFieldsValid
    }

    func applyChangesAndSaveDatabase() {
        guard let entry = entry else { return }
        _ = entry.backupState()
        
        let dbm = DatabaseManager.shared
        dbm.delegate = self
        DispatchQueue.global(qos: .userInitiated).async {
            dbm.saveDatabase()
        }
    }
}

extension EditEntryVC: ValidatingTextFieldDelegate {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        entry?.title = text
        isModified = true
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return sender.text?.isNotEmpty ?? false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        revalidate()
    }
}

extension EditEntryVC: EditEntryFieldDelegate {

    func editEntryCell(_ sender: EditEntryTableCell, fieldDidChange field: EditableEntryField) {
        isModified = true
        revalidate()
    }
    
    func isFieldValid(field: EditableEntryField) -> Bool {
        if field.internalName.isEmpty {
            return false
        }
        if field.isFixed { 
            return true
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

extension EditEntryVC: DatabaseManagerDelegate {
    
    func databaseWillLoad() {} 
    func databaseDidLoad() {}  
    func databaseLoadError(isCancelled: Bool, message: String, reason: String?) {} 
    func databaseInvalidMasterKey(message: String) {}  
    
    func databaseWillSave() {
        DatabaseManager.shared.progress.addObserver(self, forKeyPath: Progress.fractionCompletedKey, options: .new, context: nil)
        DispatchQueue.main.async {
            self.savingOverlay = UIAlertController(title: String.Localized.databaseStatusSaving, message: nil, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: String.Localized.actionCancel, style: .cancel, handler: { _ in
                DatabaseManager.shared.progress.cancel()
            })
            self.savingOverlay!.addAction(cancelAction)
            self.present(self.savingOverlay!, animated: true, completion: nil)
        }
    }
    
    func databaseDidSave() {
        DatabaseManager.shared.progress.removeObserver(self, forKeyPath: Progress.fractionCompletedKey)
        DispatchQueue.main.async {
            self.savingOverlay?.dismiss(animated: true, completion: {
                self.savingOverlay = nil
                self.dismiss(animated: true, completion: nil)
                if let entry = self.entry {
                    self.delegate?.entryEditor(entryDidChange: entry)
                    EntryChangeNotification.post(entryDidChange: entry)
                }
            })
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == Progress.fractionCompletedKey else { return }
        let progress = object as! ProgressEx
        let fractionCompleted = Float(progress.fractionCompleted)
        DispatchQueue.main.async {
            let progressStatus = progress.localizedDescription ?? ""
            print("Saving progress: \(String(format:"%.3f", fractionCompleted)) - \(progressStatus)")
            self.savingOverlay?.message = progressStatus
        }
    }
    
    func databaseSaveError(isCancelled: Bool, message: String, reason: String?) {
        DatabaseManager.shared.progress.removeObserver(self, forKeyPath: Progress.fractionCompletedKey)
        DispatchQueue.main.async {
            if isCancelled {
                self.savingOverlay?.dismiss(animated: true, completion: nil)
            } else {
                self.savingOverlay?.dismiss(animated: false, completion: {
                    let errorAlert = UIAlertController(title: message, message: reason, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: String.Localized.actionDismiss, style: .cancel, handler: nil))
                    self.present(errorAlert, animated: true, completion: nil)
                })
            }
        }
    }
}

extension EditEntryVC: IconChooserDelegate {
    func showIconChooser() {
        let iconChooser = ChooseIconVC.make(selectedIconID: entry?.iconID, delegate: self)
        navigationController?.pushViewController(iconChooser, animated: true)
    }
    func iconChooser(didChooseIcon iconID: IconID?) {
        guard let entry = entry, let iconID = iconID else { return }
        guard iconID != entry.iconID else { return }
        
        entry.iconID = iconID
        isModified = true
        refresh()
    }
}
