//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.


import KeePassiumLib
import UIKit

struct EntryFieldActionConfiguration {
    static let hidden = Self(state: [.hidden], menu: nil)

    enum State {
        case enabled
        case hidden
        case busy
    }
    var state: Set<State>
    var menu: UIMenu?

    public func apply(to button: UIButton) {
        button.menu = menu
        button.showsMenuAsPrimaryAction = menu != nil

        button.isHidden = state.contains(.hidden)
        button.isEnabled = state.contains(.enabled)
        button.configuration?.showsActivityIndicator = state.contains(.busy)
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

    func getActionConfiguration(for field: EditableField) -> EntryFieldActionConfiguration
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

    @IBOutlet weak var titleTextField: ValidatingTextField!
    @IBOutlet weak var iconButton: UIButton!

    weak var field: EditableField? {
        didSet { refresh() }
    }
    var icon: UIImage? {
        didSet { refresh() }
    }
    weak var delegate: EditableFieldCellDelegate?

    override func awakeFromNib() {
        super.awakeFromNib()

        titleTextField.font = UIFont.entryTextFont()
        titleTextField.validityDelegate = self
        titleTextField.delegate = self

        iconButton.configuration = .tinted()
        iconButton.borderColor = .actionTint
        iconButton.borderWidth = 1
        iconButton.cornerRadius = 5
        iconButton.configuration?.baseForegroundColor = .iconTint
        iconButton.accessibilityLabel = LString.fieldIcon
    }

    private func refresh() {
        guard let field else { return }
        let buttonConfig = delegate?.getActionConfiguration(for: field)
        buttonConfig?.apply(to: iconButton)
        iconButton.configuration?.image = icon?.downscalingToSquare(maxSidePoints: 30)

        titleTextField.text = field.value
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        titleTextField.becomeFirstResponder()
        if titleTextField.text == LString.defaultNewEntryName {
            titleTextField.selectAll(nil)
        }
        return result
    }

    func pulsateIcon() {
        let scalingAnimation = CABasicAnimation(keyPath: "transform.scale")
        scalingAnimation.toValue = 1.25
        scalingAnimation.duration = 0.2
        scalingAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        scalingAnimation.autoreverses = true
        scalingAnimation.repeatCount = 1
        iconButton.layer.add(scalingAnimation, forKey: nil)
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

    func textField(
        _ textField: UITextField,
        editMenuForCharactersIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textField.addRandomizerEditMenu(to: suggestedActions)
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
        didSet {
            refreshActionButton()
        }
    }
    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            textField.text = field?.value
            textField.isSecureTextEntry =
                (field?.isProtected ?? false) && Settings.current.isHideProtectedFields
            textField.accessibilityLabel = field?.visibleName
            textField.textContentType = field?.textContentType
            refreshActionButton()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.entryTextFont()
        textField.adjustsFontForContentSizeCategory = true

        textField.validityDelegate = self
        textField.delegate = self

    }

    private func refreshActionButton() {
        guard let field = field else {
            return
        }
        let actionConfig = delegate?.getActionConfiguration(for: field) ?? .hidden
        actionConfig.apply(to: actionButton)
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    func validate() {
        textField.validate()
        refreshActionButton()
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
        refreshActionButton()
    }

    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }

    @IBAction private func didPressActionButton(_ sender: Any) {
        guard let field = field else { return }
        let popoverAnchor = PopoverAnchor(sourceView: actionButton, sourceRect: actionButton.bounds)
        delegate?.didPressButton(for: field, at: popoverAnchor, in: self)
    }

    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard textInput === textField else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }

    func textField(
        _ textField: UITextField,
        editMenuForCharactersIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textField.addRandomizerEditMenu(to: suggestedActions)
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
    @IBOutlet private weak var passwordQualityIndicatorView: PasswordQualityIndicatorView!
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
            passwordQualityIndicatorView.quality = .init(password: field?.value)
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        titleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        titleLabel.adjustsFontForContentSizeCategory = true
        textField.font = UIFont.entryTextFont()
        textField.adjustsFontForContentSizeCategory = true

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
        guard let field = field else { return false }
        delegate?.didPressReturn(for: field, in: self)
        return false
    }

    func textField(
        _ textField: UITextField,
        editMenuForCharactersIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textField.addRandomizerEditMenu(to: suggestedActions)
    }

    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field = field else { return }
        field.value = textField.text ?? ""
        passwordQualityIndicatorView.quality = .init(password: textField.text)
        delegate?.didChangeField(field, in: self)
    }

    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }

    @IBAction private func didPressRandomizeButton(_ sender: Any) {
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

final class TagsFieldEditorCell: UITableViewCell, EditableFieldCell, UITextFieldDelegate {
    static let storyboardID = "TagsFieldEditorCell"

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var valueTextField: UITextField!

    var delegate: EditableFieldCellDelegate?

    weak var field: EditableField? {
        didSet {
            titleLabel.text = field?.visibleName
            let attributedText = TagFormatter.format(field?.value)
            valueTextField.attributedText = attributedText
            valueTextField.isHidden = attributedText == nil

            valueTextField.accessibilityLabel = field?.visibleName
            valueTextField.accessibilityValue = field?.value
        }
    }

    func validate() { }

    override func awakeFromNib() {
        super.awakeFromNib()

        accessoryType = .disclosureIndicator
        valueTextField.delegate = self
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return false
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
        textView.font = UIFont.entryTextFont()
        textView.adjustsFontForContentSizeCategory = true

        textView.validityDelegate = self
        textView.delegate = self
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

    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textView.addRandomizerEditMenu(to: suggestedActions)
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
    @IBOutlet private weak var protectionSwitchLabel: UILabel!
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

        nameTextField.font = UIFont.entryTextFont()
        nameTextField.adjustsFontForContentSizeCategory = true

        valueTextView.font = UIFont.entryTextFont()
        valueTextView.adjustsFontForContentSizeCategory = true

        protectionSwitchLabel.text = LString.titleProtectedField
        protectionSwitchLabel.isAccessibilityElement = false
        protectionSwitch.accessibilityLabel = LString.titleProtectedField
        protectionSwitch.addTarget(self, action: #selector(protectionDidChange), for: .valueChanged)

        deleteButton.accessibilityLabel = LString.actionDelete
        deleteButton.addTarget(self, action: #selector(didPressDelete), for: .touchUpInside)

        nameTextField.validityDelegate = self
        nameTextField.delegate = self

        valueTextView.validityDelegate = self
        valueTextView.delegate = self
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

    func textField(
        _ textField: UITextField,
        editMenuForCharactersIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textField.addRandomizerEditMenu(to: suggestedActions)
    }

    func textView(
        _ textView: UITextView,
        editMenuForTextIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textView.addRandomizerEditMenu(to: suggestedActions)
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
