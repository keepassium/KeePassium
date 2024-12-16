//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol GroupEditorTitleCellDelegate: AnyObject {
    func didPressReturn(in cell: GroupEditorTitleCell)
    func didPressChangeIcon(at popoverAnchor: PopoverAnchor, in cell: GroupEditorTitleCell)
    func didPressRandomizer(for textInput: TextInputView, in cell: GroupEditorTitleCell)
    func isValid(groupName: String, in cell: GroupEditorTitleCell) -> Bool
    func didChangeName(name: String, in cell: GroupEditorTitleCell)
    func didChangeValidity(isValid: Bool, in cell: GroupEditorTitleCell)
}

final class GroupEditorTitleCell: UITableViewCell {


    private lazy var iconButton: UIButton = {
        let buttonAction = UIAction(handler: { [weak self] _ in
            guard let self else { return }
            let popoverAnchor = PopoverAnchor(sourceView: iconButton, sourceRect: iconButton.bounds)
            self.delegate?.didPressChangeIcon(at: popoverAnchor, in: self)
        })
        let button = UIButton(configuration: .tinted(), primaryAction: buttonAction)
        button.configuration?.baseForegroundColor = .iconTint
        button.borderColor = .actionTint
        button.borderWidth = 1
        button.cornerRadius = 5
        button.accessibilityLabel = LString.fieldIcon
        button.accessibilityTraits.insert(.image)
        return button
    }()

    private lazy var nameTextField: ValidatingTextField = {
        let textField = ValidatingTextField(frame: .zero)
        textField.font = .preferredFont(forTextStyle: .body)
        textField.textColor = .primaryText
        textField.adjustsFontForContentSizeCategory = true
        textField.borderStyle = .roundedRect
        textField.placeholder = LString.titleGroupName
        textField.autocapitalizationType = .none

        textField.delegate = self
        textField.validityDelegate = self
        return textField
    }()


    weak var delegate: GroupEditorTitleCellDelegate? {
        didSet {
            delegate?.didChangeValidity(isValid: nameTextField.isValid, in: self)
        }
    }

    var group: Group? {
        didSet {
            nameTextField.text = group?.name
            let icon = (group != nil) ? UIImage.kpIcon(forGroup: group!) : nil
            iconButton.configuration?.image = icon?.downscalingToSquare(maxSidePoints: 30)
            delegate?.didChangeValidity(isValid: nameTextField.isValid, in: self)
        }
    }


    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    private func setupView() {
        selectionStyle = .none
        contentView.addSubview(iconButton)
        contentView.addSubview(nameTextField)
        iconButton.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconButton.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            iconButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconButton.widthAnchor.constraint(equalToConstant: 40),
            iconButton.heightAnchor.constraint(equalToConstant: 40),
            nameTextField.leadingAnchor.constraint(equalTo: iconButton.trailingAnchor, constant: 8),
            nameTextField.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            nameTextField.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            nameTextField.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
    }

    override func layoutSubviews() {
        separatorInset.left = bounds.width 
        super.layoutSubviews()
    }


    public func focus() {
        nameTextField.becomeFirstResponder()
        if [LString.defaultNewGroupName, LString.defaultNewSmartGroupName].contains(nameTextField.text) {
            nameTextField.selectAll(nil)
        }
    }
}

extension GroupEditorTitleCell: ValidatingTextFieldDelegate {
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return delegate?.isValid(groupName: sender.text ?? "", in: self) ?? true
    }

    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        delegate?.didChangeValidity(isValid: nameTextField.isValid, in: self)
    }

    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        delegate?.didChangeName(name: text, in: self)
    }
}

extension GroupEditorTitleCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard nameTextField.isValid else {
            nameTextField.becomeFirstResponder()
            nameTextField.shake()
            return true
        }
        delegate?.didPressReturn(in: self)
        nameTextField.resignFirstResponder()
        return true
    }

    func textField(
        _ textField: UITextField,
        editMenuForCharactersIn range: NSRange,
        suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        return textField.addRandomizerEditMenu(to: suggestedActions)
    }
}

extension GroupEditorTitleCell: TextInputEditMenuDelegate {
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        delegate?.didPressRandomizer(for: textInput, in: self)
    }
}
