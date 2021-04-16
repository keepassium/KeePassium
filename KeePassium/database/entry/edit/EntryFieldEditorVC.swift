//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol EntryFieldEditorDelegate: class {
    func didPressCancel(in viewController: EntryFieldEditorVC)
    func didPressDone(in viewController: EntryFieldEditorVC)

    func didPressAddField(in viewController: EntryFieldEditorVC)
    func didPressDeleteField(_ field: EditableField, in viewController: EntryFieldEditorVC)

    func didModifyContent(in viewController: EntryFieldEditorVC)

    func isTOTPSetupAvailable(_ viewController: EntryFieldEditorVC) -> Bool
    func didPressScanQRCode(in viewController: EntryFieldEditorVC)

    func didPressUserNameGenerator(
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldEditorVC
    )
    func didPressPasswordGenerator(
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldEditorVC
    )
    func didPressPickIcon(
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryFieldEditorVC
    )
}

final class EntryFieldEditorVC: UITableViewController, Refreshable {
    @IBOutlet private weak var addFieldButton: UIBarButtonItem!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet private weak var scanOTPButton: UIButton!

    public var shouldFocusOnTitleField = true

    var fields = [EditableField]()
    weak var delegate: EntryFieldEditorDelegate?
    var entryIcon: UIImage?

    var itemCategory = ItemCategory.default
    var allowsCustomFields = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0

        let supportsTOTPSetup = delegate?.isTOTPSetupAvailable(self) ?? false
        if supportsTOTPSetup {
            scanOTPButton.setTitle(LString.otpSetupOTPAction, for: .normal)
        } else {
            tableView.tableFooterView = nil
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refresh()
        if shouldFocusOnTitleField {
            shouldFocusOnTitleField = false
            DispatchQueue.main.async { [weak self] in
                self?.focusOnCell(at: IndexPath(row: 0, section: 0))
            }
        }
    }

    func refresh() {
        addFieldButton.isEnabled = allowsCustomFields
        fields.sort {
            itemCategory.compare($0.internalName, $1.internalName)
        }
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
        doneButton.isEnabled = isAllFieldsValid
    }
    
    private func focusOnCell(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        _ = cell.becomeFirstResponder()
    }
    
    private func selectCustomFieldName(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? EntryFieldEditorCustomFieldCell else {
            return
        }
        cell.selectNameText()
    }

    
    @IBAction private func didPressSetupTOTP(_ sender: Any) {
        let isTOTPSetupAvailable = delegate?.isTOTPSetupAvailable(self) ?? false
        guard isTOTPSetupAvailable else {
            assertionFailure("TOTP setup option should have been hidden")
            return
        }

        guard let otpField = fields.first(where: { $0.internalName == EntryField.otp }),
              let value = otpField.value,
              !value.isEmpty
        else {
            delegate?.didPressScanQRCode(in: self)
            return
        }

        let choiceAlert = UIAlertController(
            title: LString.titleWarning,
            message: LString.otpQRCodeOverwriteWarning,
            preferredStyle: .alert)
        choiceAlert.addAction(title: LString.actionOverwrite, style: .destructive) {
            [weak self] (action) in
            guard let self = self else { return }
            self.delegate?.didPressScanQRCode(in: self)
        }
        choiceAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        present(choiceAlert, animated: true, completion: nil)
    }

    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressDone(_ sender: Any) {
        delegate?.didPressDone(in: self)
    }
    
    @IBAction func didPressAddField(_ sender: Any) {
        assert(allowsCustomFields)
        let fieldCountBefore = fields.count
        delegate?.didPressAddField(in: self) 
        let fieldCountAfter = fields.count
        
        guard fieldCountAfter > fieldCountBefore else {
            Diag.warning("Field was not added")
            assertionFailure()
            return
        }
        
        let newIndexPath = IndexPath(row: fields.count - 1, section: 0)
        tableView.beginUpdates()
        tableView.insertRows(at: [newIndexPath], with: .fade)
        tableView.endUpdates()
        
        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                self?.tableView.scrollToRow(at: newIndexPath, at: .top, animated: false)
            },
            completion: { [weak self] finished in
                self?.focusOnCell(at: newIndexPath)
                self?.selectCustomFieldName(at: newIndexPath)
            }
        )
        refresh()
    }
    
    func didPressDeleteField(at indexPath: IndexPath) {
        assert(allowsCustomFields)
        let fieldIndex = indexPath.row
        let field = fields[fieldIndex]
        let fieldCountBefore = fields.count
        delegate?.didPressDeleteField(field, in: self)
        let fieldCountAfter = fields.count
        
        guard fieldCountAfter < fieldCountBefore else {
            Diag.warning("Field was not deleted")
            assertionFailure()
            return
        }
        
        tableView.beginUpdates()
        tableView.deleteRows(at: [indexPath], with: .fade)
        tableView.endUpdates()
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
        let fieldNumber = indexPath.row
        let field = fields[fieldNumber]
        if field.internalName == EntryField.title { 
            let cell = tableView.dequeueReusableCell(
                withIdentifier: EntryFieldEditorTitleCell.storyboardID,
                for: indexPath)
                as! EntryFieldEditorTitleCell
            cell.delegate = self
            cell.icon = entryIcon
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
}

extension EntryFieldEditorVC: ValidatingTextFieldDelegate {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let titleField = fields.first(where: { $0.internalName == EntryField.title }) else {
            assertionFailure("There is no entry title field")
            sender.text = ""
            return
        }
        titleField.value = text
        delegate?.didModifyContent(in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return sender.text?.isNotEmpty ?? false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        revalidate()
    }
}

extension EntryFieldEditorVC: EditableFieldCellDelegate {
    func didPressButton(
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in cell: EditableFieldCell
    ) {
        switch cell {
        case is EntryFieldEditorTitleCell:
            didPressChangeIcon(in: cell, at: popoverAnchor)
        case is EntryFieldEditorSingleLineProtectedCell:
            didPressRandomize(field: field, at: popoverAnchor)
        default:
            if field.internalName == EntryField.userName {
                didPressChooseUserName(field: field, at: popoverAnchor)
            } else {
                assertionFailure("Button pressed in an unknown field")
            }
        }
    }
    
    func didPressChangeIcon(in cell: EditableFieldCell, at popoverAnchor: PopoverAnchor) {
        delegate?.didPressPickIcon(at: popoverAnchor, in: self)
    }

    func didPressReturn(for field: EditableField, in cell: EditableFieldCell) {
        didPressDone(self)
    }

    func didChangeField(_ field: EditableField, in cell: EditableFieldCell) {
        delegate?.didModifyContent(in: self)
        revalidate()
    }
    
    func didPressRandomize(field: EditableField, at popoverAnchor: PopoverAnchor) {
        delegate?.didPressPasswordGenerator(for: field, at: popoverAnchor, in: self)
    }
    
    func didPressChooseUserName(field: EditableField, at popoverAnchor: PopoverAnchor) {
        delegate?.didPressUserNameGenerator(for: field, at: popoverAnchor, in: self)
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
