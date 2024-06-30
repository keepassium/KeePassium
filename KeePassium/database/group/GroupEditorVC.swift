//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol GroupEditorDelegate: AnyObject {
    func didPressCancel(in groupEditor: GroupEditorVC)
    func didPressDone(in groupEditor: GroupEditorVC)
    func didPressChangeIcon(at popoverAnchor: PopoverAnchor, in groupEditor: GroupEditorVC)
    func didPressRandomizer(for textInput: TextInputView, in groupEditor: GroupEditorVC)
    func didPressTags(in groupEditor: GroupEditorVC)
}

final class GroupEditorVC: UITableViewController {
    enum ExtraField {
        case tags
        case notes
    }
    private enum Section: Int, CaseIterable {
        case general
        case properties

        static func count(hasProperties: Bool) -> Int {
            return hasProperties ? allCases.count : allCases.count - 1
        }
        static func generalCount(with extraFields: Set<ExtraField>) -> Int {
            return 1 + extraFields.count
        }
    }

    private enum Row {
        case title
        case tags
        case notes
        case properties(index: Int)

        static func at(_ indexPath: IndexPath, with extraFields: Set<ExtraField>) -> Self? {
            let hasTags = extraFields.contains(.tags)
            let hasNotes = extraFields.contains(.notes)
            switch (indexPath.section, indexPath.row) {
            case (Section.general.rawValue, 0):
                return .title
            case (Section.general.rawValue, 1):
                if hasTags {
                    return .tags
                } else if  hasNotes {
                    return .notes
                } else {
                    return nil
                }
            case (Section.general.rawValue, 2):
                if hasTags && hasNotes {
                    return .notes
                } else {
                    return nil
                }
            case (Section.properties.rawValue, _):
                return .properties(index: indexPath.row)
            default:
                return nil
            }
        }
    }

    private enum CellID {
        static let parameterValueCell = "ParameterValueCell"
        static let titleAndIconCell = "TitleAndIconCell"
        static let tagsCell = "TagsCell"
        static let notesCell = "NotesCell"
    }

    private lazy var closeButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(didPressCancel))

    private lazy var doneButton = UIBarButtonItem(
        systemItem: .done,
        primaryAction: UIAction { [weak self] _ in
            self?.didPressDone()
        },
        menu: nil)

    private lazy var tagsCellConfiguration: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .callout)
        configuration.textProperties.color = .auxiliaryText
        configuration.textToSecondaryTextVerticalPadding = 8
        configuration.directionalLayoutMargins = .init(top: 8, leading: 0, bottom: 10, trailing: 0)
        return configuration
    }()

    weak var delegate: GroupEditorDelegate?

    private let group: Group
    private let parentGroup: Group?
    private let extraFields: Set<ExtraField>
    private var isFirstFocus = true
    private var properties: [Property]
    private let isSmartGroup: Bool

    init(
        group: Group,
        parent: Group?,
        extraFields: any Collection<ExtraField>,
        properties: [Property],
        isSmartGroup: Bool
    ) {
        self.group = group
        self.parentGroup = parent
        self.extraFields = Set(extraFields)
        self.properties = properties
        self.isSmartGroup = isSmartGroup
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = doneButton
        tableView.alwaysBounceVertical = false
        tableView.separatorStyle = .none

        registerCellClasses(tableView)
    }

    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(
            UINib(nibName: ParameterValueCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: CellID.parameterValueCell)
        tableView.register(
            GroupEditorTitleCell.classForCoder(),
            forCellReuseIdentifier: CellID.titleAndIconCell
        )
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: CellID.tagsCell
        )
        tableView.register(
            GroupEditorNotesCell.self,
            forCellReuseIdentifier: CellID.notesCell
        )
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.count(hasProperties: !properties.isEmpty)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .general:
            return Section.generalCount(with: extraFields)
        case .properties:
            return properties.count
        case .none:
            fatalError("Invalid section")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .general:
            return CGFloat.leastNonzeroMagnitude
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Row.at(indexPath, with: extraFields) {
        case .tags:
            delegate?.didPressTags(in: self)
        default:
            break
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Row.at(indexPath, with: extraFields) {
        case .title:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.titleAndIconCell,
                for: indexPath)
                as! GroupEditorTitleCell
            configure(cell: cell)
            return cell
        case .tags:
            assert(extraFields.contains(.tags), "Tried to show Tags row when tags must be hidden")
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.tagsCell,
                for: indexPath)
            configure(cell: cell)
            return cell
        case .notes:
            assert(extraFields.contains(.notes), "Tried to show Notes row when tags must be hidden")
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.notesCell,
                for: indexPath)
                as! GroupEditorNotesCell
            configure(cell: cell)
            return cell
        case .properties(let index):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.parameterValueCell,
                for: indexPath)
                as! ParameterValueCell
            let model = properties[index]
            configure(cell: cell, with: model)
            return cell
        case .none:
            fatalError("Unexpected index path")
        }
    }

    private func configure(cell: GroupEditorTitleCell) {
        cell.selectionStyle = .none
        cell.delegate = self
        cell.group = group

        guard isFirstFocus else {
            return
        }

        isFirstFocus = false
        DispatchQueue.main.async {
            cell.focus()
        }
    }

    private func configure(cell: GroupEditorNotesCell) {
        cell.selectionStyle = .none
        cell.isSmartGroup = isSmartGroup
        cell.notes = group.notes
        cell.delegate = self
    }

    private func configure(cell: UITableViewCell) {
        var configuration = tagsCellConfiguration
        configuration.text = LString.fieldTags

        configuration.secondaryAttributedText = TagFormatter.format(tags: group.tags)
        cell.contentConfiguration = configuration
        cell.accessoryType = .disclosureIndicator
    }

    private func configure(cell: ParameterValueCell, with model: Property) {
        let menuActions = Property.possibleValues.map { altValue in
            UIAction(
                title: model.description(for: altValue, inheritedValue: model.inheritedValue),
                state: model.value == altValue ? .on : .off,
                handler: { [weak self] _ in
                    self?.update(property: model, newValue: altValue)
                }
            )
        }

        cell.selectionStyle = .none
        cell.textLabel?.text = model.title
        cell.detailTextLabel?.text = model.description
        cell.menu = UIMenu(
            title: model.title,
            options: .displayInline,
            children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    self?.view.endEditing(true)
                    completion(menuActions)
                }
            ]
        )
    }

    private func update(property: Property, newValue: Bool?) {
        guard let index = properties.firstIndex(where: { $0.kind == property.kind }) else {
            assertionFailure("Tried to modify a non-existent property")
            return
        }
        properties[index].value = newValue
        properties[index].apply(to: group)
        refresh()
    }

    @objc
    private func didPressCancel(_ sender: UIBarButtonItem) {
        delegate?.didPressCancel(in: self)
    }

    private func didPressDone() {
        delegate?.didPressDone(in: self)
    }
}

extension GroupEditorVC: Refreshable {
    func refresh() {
        tableView.reloadData()
    }
}

extension GroupEditorVC: GroupEditorTitleCellDelegate {
    func didPressReturn(in cell: GroupEditorTitleCell) {
        delegate?.didPressDone(in: self)
    }

    func didPressChangeIcon(at popoverAnchor: PopoverAnchor, in cell: GroupEditorTitleCell) {
        delegate?.didPressChangeIcon(at: popoverAnchor, in: self)
    }

    func didPressRandomizer(for textInput: TextInputView, in cell: GroupEditorTitleCell) {
        delegate?.didPressRandomizer(for: textInput, in: self)
    }

    func isValid(groupName: String, in cell: GroupEditorTitleCell) -> Bool {
        let isReserved = group.isNameReserved(name: groupName)
        let isValid = groupName.isNotEmpty && !isReserved
        return isValid
    }

    func didChangeName(name: String, in cell: GroupEditorTitleCell) {
        group.name = name
    }

    func didChangeValidity(isValid: Bool, in cell: GroupEditorTitleCell) {
        navigationItem.rightBarButtonItem?.isEnabled = isValid
    }
}

extension GroupEditorVC: GroupEditorNotesCellDelegate {
    func didChangeNotes(notes: String, in cell: GroupEditorNotesCell) {
        group.notes = notes
    }

    func didPressAboutSmartGroups(in cell: GroupEditorNotesCell) {
        URLOpener(self).open(url: URL.AppHelp.smartGroups)
    }
}
