//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


import UIKit
import KeePassiumLib


class EditableFieldCellFactory {
    public static func dequeueAndConfigureCell(
        from tableView: UITableView,
        for indexPath: IndexPath,
        field: EditableField
        ) -> EditableFieldCell & UITableViewCell
    {
        
        let cellStoryboardID: String
        if field.isFixed {
            if field.isMultiline {
                cellStoryboardID = EditEntryMultiLineCell.storyboardID
            } else {
                if field.isProtected {
                    cellStoryboardID = EditEntrySingleLineProtectedCell.storyboardID
                } else {
                    cellStoryboardID = EditEntrySingleLineCell.storyboardID
                }
            }
        } else {
            cellStoryboardID = EditEntryCustomFieldCell.storyboardID
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: cellStoryboardID,
            for: indexPath)
            as! EditableFieldCell & UITableViewCell
        cell.field = field
        return cell
    }
}

internal protocol EditableFieldCellDelegate: class {
    func didPressChangeIcon(in cell: EditableFieldCell)
    func didChangeField(field: EditableField, in cell: EditableFieldCell)
    func didPressReturn(in cell: EditableFieldCell)
    func didPressRandomize(field: EditableField, in cell: EditableFieldCell)
}

internal protocol EditableFieldCell: class {
    var delegate: EditableFieldCellDelegate? { get set }
    var field: EditableField? { get set }
    func validate()
}


class EditEntryTitleCell:
    UITableViewCell,
    EditableFieldCell,
    UITextFieldDelegate,
    ValidatingTextFieldDelegate
{
    public static let storyboardID = "TitleCell"
    
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleTextField: ValidatingTextField!
    @IBOutlet weak var changeIconButton: UIButton!
    
    weak var field: EditableField? {
        didSet {
            titleTextField.text = field?.value
        }
    }
    var icon: UIImage? {
        get { return iconView.image }
        set { iconView.image = newValue }
    }
    weak var delegate: EditableFieldCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleTextField.validityDelegate = self
        titleTextField.delegate = self
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapIcon))
        iconView.addGestureRecognizer(tapRecognizer)
    }
    
    @objc func didTapIcon(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            didPressChangeIcon(gestureRecognizer)
        }
    }
    
    @IBAction func didPressChangeIcon(_ sender: Any) {
        delegate?.didPressChangeIcon(in: self)
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        titleTextField.becomeFirstResponder()
        if titleTextField.text == LString.defaultNewEntryName {
            titleTextField.selectAll(nil)
        }
        return result
    }
    
    func validate() {
        titleTextField.validate()
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field = field else { return }
        field.value = titleTextField.text ?? ""
        field.isValid = field.value?.isNotEmpty ?? false
        delegate?.didChangeField(field: field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.didPressReturn(in: self)
        return false
    }
}

class EditEntrySingleLineCell:
    UITableViewCell,
    EditableFieldCell,
    ValidatingTextFieldDelegate,
    UITextFieldDelegate
{
    public static let storyboardID = "SingleLineCell"
    @IBOutlet private weak var textField: ValidatingTextField!
    @IBOutlet private weak var titleLabel: UILabel!
    
    var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textField.text = field?.value
            textField.isSecureTextEntry = field?.isProtected ?? false
        }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        textField.validityDelegate = self
        textField.delegate = self
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    func validate() {
        textField.validate()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.didPressReturn(in: self)
        return false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field = field else { return }
        field.value = textField.text ?? ""
        delegate?.didChangeField(field: field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
}

class EditEntrySingleLineProtectedCell:
    UITableViewCell,
    EditableFieldCell,
    ValidatingTextFieldDelegate,
    UITextFieldDelegate
{
    public static let storyboardID = "SingleLineProtectedCell"
    @IBOutlet private weak var textField: ValidatingTextField!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet weak var randomizeButton: UIButton!
    
    var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textField.text = field?.value
            textField.isSecureTextEntry = field?.isProtected ?? false
            randomizeButton.isHidden = (field?.internalName != EntryField.password)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textField.validityDelegate = self
        textField.delegate = self
    }
    
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }
    
    func validate() {
        textField.validate()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        delegate?.didPressReturn(in: self)
        return false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field = field else { return }
        field.value = textField.text ?? ""
        delegate?.didChangeField(field: field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
    
    @IBAction func didPressRandomizeButton(_ sender: Any) {
        guard let field = field else { return }
        delegate?.didPressRandomize(field: field, in: self)
    }
}

class EditEntryMultiLineCell: UITableViewCell, EditableFieldCell, ValidatingTextViewDelegate {
    public static let storyboardID = "MultiLineCell"
    @IBOutlet private weak var textView: ValidatingTextView!
    @IBOutlet weak var titleLabel: UILabel!
    
    var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textView.text = field?.value
            textView.isSecureTextEntry = field?.isProtected ?? false
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        textView.validityDelegate = self
        DispatchQueue.main.async {
            self.textView.setupBorder()
        }
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textView.becomeFirstResponder()
    }

    func validate() {
        textView.validate()
    }

    func validatingTextView(_ sender: ValidatingTextView, textDidChange text: String) {
        guard let field = field else { return }
        field.value = textView.text ?? ""
        delegate?.didChangeField(field: field, in: self)
    }
    
    func validatingTextViewShouldValidate(_ sender: ValidatingTextView) -> Bool {
        return field?.isValid ?? false
    }
}

class EditEntryCustomFieldCell:
    UITableViewCell,
    EditableFieldCell,
    ValidatingTextFieldDelegate,
    ValidatingTextViewDelegate
{
    public static let storyboardID = "CustomFieldCell"
    @IBOutlet private weak var nameTextField: ValidatingTextField!
    @IBOutlet private weak var valueTextView: ValidatingTextView!
    @IBOutlet private weak var protectionSwitch: UISwitch!

    var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            nameTextField.text = field?.visibleName
            valueTextView.text = field?.value
            protectionSwitch.isOn = field?.isProtected ?? false
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        protectionSwitch.addTarget(self, action: #selector(protectionDidChange), for: .valueChanged)
        nameTextField.validityDelegate = self
        valueTextView.validityDelegate = self
        DispatchQueue.main.async {
            self.valueTextView.setupBorder()
        }
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return nameTextField.becomeFirstResponder()
    }

    func selectNameText() {
        nameTextField.selectAll(nil)
    }
    func validate() {
        nameTextField.validate()
        valueTextView.validate()
    }

    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard sender == nameTextField else { assertionFailure(); return }
        guard let field = field else { return }
        field.internalName = text
        field.isValid = nameTextField.isValid
        delegate?.didChangeField(field: field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        guard sender == nameTextField else { assertionFailure(); return false }
        return field?.isValid ?? false
    }
    
    func validatingTextView(_ sender: ValidatingTextView, textDidChange text: String) {
        guard sender == valueTextView else { assertionFailure(); return }
        guard let field = field else { return }
        field.value = valueTextView.text ?? ""
        delegate?.didChangeField(field: field, in: self)
    }
    
    func validatingTextViewShouldValidate(_ sender: ValidatingTextView) -> Bool {
        guard sender == valueTextView else { assertionFailure(); return false }
        return true 
    }

    @objc func protectionDidChange() {
        guard let field = field else { return }
        field.isProtected = protectionSwitch.isOn
        delegate?.didChangeField(field: field, in: self)
    }
}

