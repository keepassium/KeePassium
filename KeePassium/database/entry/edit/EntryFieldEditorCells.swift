//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
    ) -> EditableFieldCell & UITableViewCell {
        let cellStoryboardID: String
        if field.isFixed {
            if field.isMultiline {
                cellStoryboardID = EntryFieldEditorMultiLineCell.storyboardID
            } else {
                if field.isProtected || (field.internalName == EntryField.password) {
                    cellStoryboardID = PasswordEntryFieldCell.storyboardID
                } else {
                    cellStoryboardID = EntryFieldEditorSingleLineCell.storyboardID
                }
            }
        } else {
            cellStoryboardID = EntryFieldEditorCustomFieldCell.storyboardID
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: cellStoryboardID,
            for: indexPath)
            as! EditableFieldCell & UITableViewCell
        cell.field = field
        
        if let singleLineCell = cell as? EntryFieldEditorSingleLineCell {
            decorate(singleLineCell, field: field)
        }
        return cell
    }
    
    private static func decorate(_ cell: EntryFieldEditorSingleLineCell, field: EditableField) {
        cell.textField.keyboardType = .default
        cell.actionButton.isHidden = true
        
        switch field.internalName {
        case EntryField.userName:
            cell.actionButton.setTitle(LString.actionChooseUserName, for: .normal)
            cell.actionButton.isHidden = false
            cell.textField.keyboardType = .emailAddress
        case EntryField.url:
            cell.textField.keyboardType = .URL
        default:
            break
        }
    }
}

internal protocol EditableFieldCellDelegate: AnyObject {
    func didChangeField(_ field: EditableField, in cell: EditableFieldCell)
    func didPressDelete(_ field: EditableField, in cell: EditableFieldCell)
    func didPressReturn(for field: EditableField, in cell: EditableFieldCell)
    func didPressRandomize(for textInput: TextInputView, viaMenu: Bool, in cell: EditableFieldCell)
    func didPressButton(
        for field: EditableField,
        at popoverAnchor: PopoverAnchor,
        in cell: EditableFieldCell)
    
    @available(iOS 14, *)
    func getButtonMenu(for field: EditableField, in cell: EditableFieldCell) -> UIMenu?
}

internal protocol EditableFieldCell: AnyObject {
    var delegate: EditableFieldCellDelegate? { get set }
    var field: EditableField? { get set }
    func validate()
}

class EntryFieldEditorTitleCell:
    UITableViewCell,
    EditableFieldCell,
    UITextFieldDelegate,
    ValidatingTextFieldDelegate,
    TextInputEditMenuDelegate
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
        titleTextField.addRandomizerEditMenu()
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapIcon))
        iconView.addGestureRecognizer(tapRecognizer)
    }
    
    @objc func didTapIcon(_ gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            didPressChangeIcon(gestureRecognizer)
        }
    }
    
    @IBAction func didPressChangeIcon(_ sender: Any) {
        guard let field = field else { return }
        let popoverAnchor = PopoverAnchor(
            sourceView: changeIconButton,
            sourceRect: changeIconButton.bounds
        )
        delegate?.didPressButton(for: field, at: popoverAnchor, in: self)
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
        delegate?.didChangeField(field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let field = field else { return false }
        delegate?.didPressReturn(for: field, in: self)
        return false
    }
    
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard textInput === titleTextField else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }
}

class EntryFieldEditorSingleLineCell:
    UITableViewCell,
    EditableFieldCell,
    ValidatingTextFieldDelegate,
    TextInputEditMenuDelegate,
    UITextFieldDelegate
{
    public static let storyboardID = "SingleLineCell"
    @IBOutlet weak var textField: ValidatingTextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var actionButton: UIButton!
    
    weak var delegate: EditableFieldCellDelegate? {
        didSet { refreshMenu() }
    }
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textField.text = field?.value
            textField.isSecureTextEntry =
                (field?.isProtected ?? false) && Settings.current.isHideProtectedFields
            textField.accessibilityLabel = field?.visibleName
            textField.textContentType = field?.textContentType
            refreshMenu()
        }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.monospaceFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        
        textField.validityDelegate = self
        textField.delegate = self
        textField.addRandomizerEditMenu()
    }

    private func refreshMenu() {
        guard #available(iOS 14, *) else { return }
        
        if let field = field,
           let buttonMenu = delegate?.getButtonMenu(for: field, in: self)
        {
            actionButton.menu = buttonMenu
            actionButton.showsMenuAsPrimaryAction = true
        } else {
            actionButton.showsMenuAsPrimaryAction = false
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    func validate() {
        textField.validate()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let field = field else { return false }
        delegate?.didPressReturn(for: field, in: self)
        return false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field = field else { return }
        field.value = textField.text ?? ""
        delegate?.didChangeField(field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
    
    @IBAction func didPressActionButton(_ sender: Any) {
        guard let field = field else { return }
        let popoverAnchor = PopoverAnchor(sourceView: actionButton, sourceRect: actionButton.bounds)
        delegate?.didPressButton(for: field, at: popoverAnchor, in: self)
    }
    
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard textInput === textField else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }
}

final class PasswordEntryFieldCell:
    UITableViewCell,
    EditableFieldCell,
    ValidatingTextFieldDelegate,
    TextInputEditMenuDelegate,
    UITextFieldDelegate
{
    public static let storyboardID = "PasswordEntryFieldCell"
    @IBOutlet private weak var textField: ValidatingTextField!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet weak var randomizeButton: UIButton!
    
    weak var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textField.text = field?.value
            textField.isSecureTextEntry =
                (field?.isProtected ?? false) && Settings.current.isHideProtectedFields
            textField.accessibilityLabel = field?.visibleName
            randomizeButton.accessibilityLabel = LString.PasswordGenerator.titleRandomGenerator
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.monospaceFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        
        textField.validityDelegate = self
        textField.delegate = self
        textField.addRandomizerEditMenu()
    }
    
    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }
    
    func validate() {
        textField.validate()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let field = field else { return false }
        delegate?.didPressReturn(for: field, in: self)
        return false
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field = field else { return }
        field.value = textField.text ?? ""
        delegate?.didChangeField(field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
    
    @IBAction func didPressRandomizeButton(_ sender: Any) {
        textField.selectAll(self) 
        delegate?.didPressRandomize(for: textField, viaMenu: false, in: self)
    }
    
    func shouldShowRandomizerMenu(in textInput: TextInputView) -> Bool {
        return textInput === textField
    }
    
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard textInput === textField else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }
}

class EntryFieldEditorMultiLineCell:
    UITableViewCell,
    EditableFieldCell,
    UITextViewDelegate,
    ValidatingTextViewDelegate,
    TextInputEditMenuDelegate
{
    public static let storyboardID = "MultiLineCell"
    @IBOutlet private weak var textView: ValidatingTextView!
    @IBOutlet weak var titleLabel: UILabel!
    
    weak var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textView.text = field?.value
            textView.isSecureTextEntry =
                (field?.isProtected ?? false) && Settings.current.isHideProtectedFields
            textView.accessibilityLabel = field?.visibleName
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        textView.font = UIFont.monospaceFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        
        textView.validityDelegate = self
        textView.delegate = self
        textView.addRandomizerEditMenu()
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
        delegate?.didChangeField(field, in: self)
    }
    
    func validatingTextViewShouldValidate(_ sender: ValidatingTextView) -> Bool {
        return field?.isValid ?? false
    }
    
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard textInput === textView else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }
}

class EntryFieldEditorCustomFieldCell:
    UITableViewCell,
    EditableFieldCell,
    UITextFieldDelegate,
    UITextViewDelegate,
    ValidatingTextFieldDelegate,
    ValidatingTextViewDelegate,
    TextInputEditMenuDelegate
{
    public static let storyboardID = "CustomFieldCell"
    @IBOutlet private weak var nameTextField: ValidatingTextField!
    @IBOutlet private weak var valueTextView: ValidatingTextView!
    @IBOutlet private weak var protectionSwitch: UISwitch!
    @IBOutlet private weak var deleteButton: UIButton!
    
    weak var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            nameTextField.text = field?.visibleName
            valueTextView.text = field?.value
            protectionSwitch.isOn = field?.isProtected ?? false
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        nameTextField.font = UIFont.preferredFont(forTextStyle: .subheadline)
        nameTextField.adjustsFontForContentSizeCategory = true
        valueTextView.font = UIFont.monospaceFont(forTextStyle: .body)
        valueTextView.adjustsFontForContentSizeCategory = true
        
        protectionSwitch.addTarget(self, action: #selector(protectionDidChange), for: .valueChanged)
        deleteButton.accessibilityLabel = LString.actionDelete
        deleteButton.addTarget(self, action: #selector(didPressDelete), for: .touchUpInside)

        nameTextField.validityDelegate = self
        nameTextField.delegate = self
        nameTextField.addRandomizerEditMenu()

        valueTextView.validityDelegate = self
        valueTextView.delegate = self
        valueTextView.addRandomizerEditMenu()

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
        delegate?.didChangeField(field, in: self)
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        guard sender == nameTextField else { assertionFailure(); return false }
        return field?.isValid ?? false
    }
    
    func validatingTextView(_ sender: ValidatingTextView, textDidChange text: String) {
        guard sender == valueTextView else { assertionFailure(); return }
        guard let field = field else { return }
        field.value = valueTextView.text ?? ""
        delegate?.didChangeField(field, in: self)
    }
    
    func validatingTextViewShouldValidate(_ sender: ValidatingTextView) -> Bool {
        guard sender == valueTextView else { assertionFailure(); return false }
        return true 
    }
    
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard (textInput === nameTextField) || (textInput === valueTextView) else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }
    
    @objc
    private func protectionDidChange() {
        guard let field = field else { return }
        field.isProtected = protectionSwitch.isOn
        delegate?.didChangeField(field, in: self)
    }
    
    @objc
    private func didPressDelete() {
        guard let field = field else { return }
        delegate?.didPressDelete(field, in: self)
    }
}
