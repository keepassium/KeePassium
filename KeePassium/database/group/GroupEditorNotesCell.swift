//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

protocol GroupEditorNotesCellDelegate: AnyObject {
    func didChangeNotes(notes: String, in cell: GroupEditorNotesCell)
    func didPressAboutSmartGroups(in cell: GroupEditorNotesCell)
}

final class GroupEditorNotesCell: UITableViewCell {

    private lazy var textView = {
        let textView = ValidatingTextView(frame: .zero, textContainer: nil)
        textView.font = UIFont.entryTextFont()
        textView.adjustsFontForContentSizeCategory = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.textColor = .primaryText
        textView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        textView.validityDelegate = self
        return textView
    }()

    private lazy var titleLabel = {
        let titleLabel = UILabel()
        titleLabel.text = LString.titleGroupNotes
        titleLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        titleLabel.textColor = .auxiliaryText
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        return titleLabel
    }()

    private lazy var presetsButton = {
        var config = UIButton.Configuration.plain()
        config.title = LString.titlePresets
        config.contentInsets.trailing = 0
        config.buttonSize = .medium
        let button = UIButton(configuration: config)
        button.menu = makePresetsMenu()
        button.showsMenuAsPrimaryAction = true
        button.contentHorizontalAlignment = .trailing
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var infoButton = {
        var config = UIButton.Configuration.plain()
        config.title = LString.titleAboutSmartGroups
        config.contentInsets.leading = 0
        config.buttonSize = .small
        let buttonAction = UIAction { [weak self] _ in
            guard let self else { return }
            delegate?.didPressAboutSmartGroups(in: self)
        }
        let button = UIButton(configuration: config, primaryAction: buttonAction)
        button.contentHorizontalAlignment = .leading
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    weak var delegate: GroupEditorNotesCellDelegate?

    var notes: String? {
        didSet { refresh() }
    }
    var isSmartGroup: Bool = false {
        didSet { refresh() }
    }

    private var presetsCollapsingConstraint: NSLayoutConstraint?
    private var textBottomConstraint: NSLayoutConstraint?

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    override func prepareForReuse() {
        notes = nil
        isSmartGroup = false
        super.prepareForReuse()
    }

    private func setupView() {
        selectionStyle = .none

        contentView.addSubview(titleLabel)
        contentView.addSubview(presetsButton)
        contentView.addSubview(textView)
        contentView.addSubview(infoButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: presetsButton.leadingAnchor),
            presetsButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            presetsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            textView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            infoButton.layoutMarginsGuide.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
            infoButton.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            infoButton.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            infoButton.layoutMarginsGuide.bottomAnchor
                .constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])
        presetsCollapsingConstraint = presetsButton.widthAnchor.constraint(equalToConstant: 0)
        textBottomConstraint = textView.bottomAnchor
            .constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
    }

    private func makePresetsMenu() -> UIMenu {
        let menu = UIMenu.make(reverse: false, children: [
            makePresetMenuAction(LString.titleSmartGroupAllEntries, query: "is:entry"),
            makePresetMenuAction(LString.titleSmartGroupExpiredEntries, query: "is:entry is:expired"),
            makePresetMenuAction(LString.titleSmartGroupOTPEntries, query: "otp:*"),
            makePresetMenuAction(LString.titleSmartGroupPasskeyEntries, query: "is:passkey"),
        ])
        return menu
    }
    private func makePresetMenuAction(_ title: String, query: String) -> UIAction {
        return UIAction(title: title) { [weak self] _ in
            guard let self else { return }
            textView.text = query
            textView.onTextChanged()
        }
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textView.becomeFirstResponder()
    }

    private func refresh() {
        textView.text = notes
        textView.smartQuotesType = isSmartGroup ? .no : .default

        let isPlainGroup = !isSmartGroup
        titleLabel.text = isPlainGroup ? LString.titleGroupNotes : LString.titleSmartGroupQuery
        infoButton.isHidden = isPlainGroup
        presetsButton.isHidden = isPlainGroup
        presetsCollapsingConstraint?.isActive = presetsButton.isHidden
        textBottomConstraint?.isActive = isPlainGroup
    }
}

extension GroupEditorNotesCell: ValidatingTextViewDelegate {
    func validatingTextView(_ sender: ValidatingTextView, textDidChange text: String) {
        delegate?.didChangeNotes(notes: textView.text ?? "", in: self)
    }
}
