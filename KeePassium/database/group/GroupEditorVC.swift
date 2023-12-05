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
}

final class GroupEditorVC: UITableViewController {
    private enum Section: Int, CaseIterable {
        case titleAndIcon
        case properties
    }

    private enum CellID {
        static let parameterValueCell = "ParameterValueCell"
        static let titleAndIconCell = "TitleAndIconCell"
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

    weak var delegate: GroupEditorDelegate?

    private let group: Group
    private var isFirstFocus = true
    private var properties: [Property]

    init(group: Group, properties: [Property]) {
        self.group = group
        self.properties = properties
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = closeButton
        navigationItem.rightBarButtonItem = doneButton
        tableView.allowsSelection = false
        tableView.alwaysBounceVertical = false

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
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if properties.isEmpty {
            return 1 
        }
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .titleAndIcon:
            return 1 
        case .properties:
            return properties.count
        case .none:
            fatalError("Invalid section")
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .titleAndIcon:
            return CGFloat.leastNonzeroMagnitude 
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .titleAndIcon:
            return nil
        case .properties:
            return LString.titleItemProperties
        default:
            return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .titleAndIcon:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.titleAndIconCell,
                for: indexPath)
                as! GroupEditorTitleCell
            configure(cell: cell)
            return cell
        case .properties:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.parameterValueCell,
                for: indexPath)
                as! ParameterValueCell
            let model = properties[indexPath.row]
            configure(cell: cell, with: model)
            return cell
        case .none:
            fatalError("Invalid section")
        }
    }

    private func configure(cell: GroupEditorTitleCell) {
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
