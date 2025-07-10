//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

final class EntryFieldEditorSingleLineCell: UITableViewCell, EditableFieldCell {
    static let reuseIdentifier = "EntryFieldEditorSingleLineCell"

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .auxiliaryText
        return label
    }()

    private lazy var titleRow: UIView = {
        let titleRow = UIView()

        titleRow.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleRow.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleRow.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: titleRow.bottomAnchor)
        ])

        titleRow.addSubview(actionButton)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionButton.trailingAnchor.constraint(equalTo: titleRow.trailingAnchor),
            actionButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            actionButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])

        return titleRow
    }()

    lazy var textField: ValidatingTextField = {
        let textField = ValidatingTextField()
        textField.font = UIFont.entryTextFont()
        textField.adjustsFontForContentSizeCategory = true
        textField.backgroundColor = .secondarySystemGroupedBackground
        textField.borderStyle = .roundedRect
        textField.autocorrectionType = .no
        textField.returnKeyType = .done
        textField.validityDelegate = self
        textField.delegate = self
        return textField
    }()

    lazy var actionButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        configuration.buttonSize = .medium

        let button = UIButton(configuration: configuration)
        button.isHidden = true
        button.tintColor = .actionTint
        button.addTarget(self, action: #selector(didPressActionButton), for: .touchUpInside)
        return button
    }()

    lazy var deleteButton: UIButton = {
        let button = UIButton(type: .system)

        var configuration = UIButton.Configuration.plain()
        configuration.image = .symbol(.trash)
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        button.configuration = configuration
        button.tintColor = .destructiveTint
        button.accessibilityLabel = LString.actionDelete
        button.isHidden = true
        button.addTarget(self, action: #selector(didPressDelete), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var textFieldTrailingConstraint: NSLayoutConstraint?

    var isTitleHidden: Bool = false {
        didSet {
            refreshLayout()
        }
    }

    weak var delegate: EditableFieldCellDelegate?
    weak var field: EditableField? {
        didSet {
            refreshContent()
            refreshLayout()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCell() {
        selectionStyle = .none

        contentView.addSubview(stackView)
        contentView.addSubview(deleteButton)

        stackView.addArrangedSubview(titleRow)
        stackView.addArrangedSubview(textField)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),

            deleteButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])

        textFieldTrailingConstraint = stackView.trailingAnchor.constraint(
            equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        textFieldTrailingConstraint?.isActive = true
    }

    private func refreshContent() {
        guard let field else { return }

        titleLabel.text = field.visibleName
        textField.text = field.value
        textField.isSecureTextEntry = field.isProtected && Settings.current.isHideProtectedFields
        textField.accessibilityLabel = field.visibleName
        textField.textContentType = field.textContentType
    }

    private func refreshLayout() {
        guard let field else { return }

        let actionConfig = delegate?.getActionConfiguration(for: field) ?? .hidden
        actionConfig.apply(to: actionButton)

        titleRow.isHidden = isTitleHidden

        let isDeleteButtonVisible = !(field.field?.isStandardField == true)
        deleteButton.isHidden = !isDeleteButtonVisible

        textFieldTrailingConstraint?.isActive = false

        if isDeleteButtonVisible {
            textFieldTrailingConstraint = stackView.trailingAnchor.constraint(
                equalTo: deleteButton.leadingAnchor,
                constant: -8)
        } else {
            textFieldTrailingConstraint = stackView.trailingAnchor.constraint(
                equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        }

        textFieldTrailingConstraint?.isActive = true
        setNeedsLayout()
    }

    func validate() {
        textField.validate()
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    @objc private func didPressActionButton() {
        guard let field else { return }
        delegate?.didPressButton(for: field, at: actionButton.asPopoverAnchor, in: self)
    }

    @objc private func didPressDelete() {
        guard let field else { return }
        delegate?.didPressDelete(field, in: self)
    }
}

extension EntryFieldEditorSingleLineCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let field else { return false }
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
}

extension EntryFieldEditorSingleLineCell: ValidatingTextFieldDelegate {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard let field else { return }
        field.value = textField.text ?? ""
        delegate?.didChangeField(field, in: self)
        refreshLayout()
    }

    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return field?.isValid ?? false
    }
}

extension EntryFieldEditorSingleLineCell: TextInputEditMenuDelegate {
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard textInput === textField else { return }
        delegate?.didPressRandomize(for: textInput, viaMenu: true, in: self)
    }
}
