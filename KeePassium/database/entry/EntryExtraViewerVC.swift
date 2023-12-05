//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

protocol EntryExtraViewerVCDelegate: AnyObject {
    func didPressCopyField(
        text: String,
        in viewController: EntryExtraViewerVC)
    func didPressExportField(
        text: String,
        at popoverAnchor: PopoverAnchor,
        in viewController: EntryExtraViewerVC)
    func didUpdateProperties(
        properties: [EntryExtraViewerVC.Property],
        in viewController: EntryExtraViewerVC
    )
}

final class EntryExtraViewerVC: UITableViewController, Refreshable {
    private enum Section: Int, CaseIterable {
        case properties
        case info

        var title: String? {
            switch self {
            case .info:
                return LString.titleItemAdvancedProperties
            case .properties:
                return nil
            }
        }
    }

    private enum CellID {
        static let parameterValueCell = "ParameterValueCell"
        static let uuidCell = "UUIDCell"
    }

    enum Property: Equatable {
        case audit(Bool)
        case autoFill(Bool)
        case autoFillThirdParty(Bool)

        var title: String {
            switch self {
            case .audit:
                return LString.titleItemPropertyPasswordAudit
            case .autoFill:
                return LString.titleItemPropertyAutoFill
            case .autoFillThirdParty:
                return LString.titleItemPropertyAutoFillKeePassXC
            }
        }

        var symbol: SymbolName {
            switch self {
            case .audit:
                return .passwordAudit
            case .autoFill,
                 .autoFillThirdParty:
                return .autoFill
            }
        }

        var value: Bool {
            switch self {
            case .audit(let value), .autoFill(let value), .autoFillThirdParty(let value):
                return value
            }
        }

        var valueDescription: String { description(for: value) }

        func description(for value: Bool) -> String {
            switch self {
            case .audit:
                return value ? LString.itemPasswordAuditAllowed : LString.itemPasswordAuditDisabled
            case .autoFill,
                 .autoFillThirdParty:
                return value ? LString.itemAutoFillAllowed : LString.itemAutoFillDisabled
            }
        }

        func updated(value: Bool) -> Self {
            switch self {
            case .audit:
                return .audit(value)
            case .autoFill:
                return .autoFill(value)
            case .autoFillThirdParty:
                return .autoFillThirdParty(value)
            }
        }
    }

    private lazy var uuidCellConfiguarion: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.text = LString.fieldUUID
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .subheadline)
        configuration.textProperties.adjustsFontForContentSizeCategory = true
        configuration.textProperties.color = .auxiliaryText
        configuration.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .body)
        configuration.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        configuration.secondaryTextProperties.color = .primaryText
        configuration.textToSecondaryTextVerticalPadding = 4
        configuration.directionalLayoutMargins = .init(top: 12, leading: 0, bottom: 10, trailing: 0)
        return configuration
    }()

    private lazy var copiedCellView: FieldCopiedView = {
        let view = FieldCopiedView(frame: .zero)
        return view
    }()

    private var properties: [Property] = []
    private var entry: Entry?
    private var canEditEntry = false

    weak var delegate: EntryExtraViewerVCDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = .systemBackground
        tableView.allowsSelection = true
        copiedCellView.delegate = self
        registerCellClasses(tableView)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func setContents(
       for entry: Entry,
       property: [Property],
       canEditEntry: Bool,
       animated: Bool
    ) {
        self.entry = entry
        self.canEditEntry = canEditEntry
        self.properties = property
    }

    func refresh() {
        refresh(animated: false)
    }

    func refresh(animated: Bool) {
        if animated {
            let visibleSections = IndexSet(0..<numberOfSections(in: tableView))
            tableView.reloadSections(visibleSections, with: .automatic)
        } else {
            tableView.reloadData()
        }
    }

    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(
            UINib(nibName: ParameterValueCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: CellID.parameterValueCell)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellID.uuidCell)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        guard entry != nil else {
            return 0
        }

        if properties.isEmpty {
            return 1 
        }
        return Section.allCases.count
    }

    private func getSection(rawIndex: Int) -> Section {
        let adjustedIndex = properties.isEmpty ? rawIndex + 1 : rawIndex
        guard let result = Section(rawValue: adjustedIndex) else {
            fatalError("Invalid section")
        }
        return result
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch getSection(rawIndex: section) {
        case .info:
            return 1 
        case .properties:
            return properties.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch getSection(rawIndex: indexPath.section) {
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.uuidCell, for: indexPath)
            var configuration = uuidCellConfiguarion
            configuration.secondaryText = entry?.uuid.uuidString
            cell.contentConfiguration = configuration
            return cell
        case .properties:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.parameterValueCell,
                for: indexPath)
            as! ParameterValueCell
            let model = properties[indexPath.row]
            configure(cell: cell, with: model)
            return cell
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        return getSection(rawIndex: section).title
    }

    private func configure(cell: ParameterValueCell, with model: Property) {
        cell.textLabel?.text = model.title
        cell.detailTextLabel?.text = model.valueDescription
        cell.imageView?.image = .symbol(model.symbol)
        cell.selectionStyle = .none
        cell.accessoryType = .none

        guard canEditEntry else {
            cell.accessoryView = nil
            cell.menu = nil
            return
        }

        let options = [true, false].map { value in
            let action = UIAction(title: model.description(for: value)) { [weak self] _ in
                self?.update(property: model, to: value)
            }
            action.state = model.value == value ? .on : .off
            return action
        }

        cell.menu = UIMenu(
            title: model.title,
            options: .displayInline,
            children: options
        )
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let section = getSection(rawIndex: indexPath.section)
        guard section == .info,
              indexPath.row == 0,
              let entry = entry
        else {
            return
        }
        delegate?.didPressCopyField(text: entry.uuid.uuidString, in: self)
        animateCopyingToClipboard(at: indexPath)
    }

    private func update(property: Property, to value: Bool) {
        guard let index = properties.firstIndex(where: { $0 == property }) else {
            return
        }
        properties[index] = properties[index].updated(value: value)
        delegate?.didUpdateProperties(properties: properties, in: self)
    }

    private func animateCopyingToClipboard(at indexPath: IndexPath) {
        HapticFeedback.play(.copiedToClipboard)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.copiedCellView.show(
                in: self.tableView,
                at: indexPath,
                canReference: false
            )
        }
    }
}

extension EntryExtraViewerVC: FieldCopiedViewDelegate {
    func didPressExport(for indexPath: IndexPath, from view: FieldCopiedView) {
        guard let entry = entry else {
            return
        }
        view.hide(animated: true)

        HapticFeedback.play(.contextMenuOpened)
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressExportField(text: entry.uuid.uuidString, at: popoverAnchor, in: self)
    }

    func didPressCopyFieldReference(for indexPath: IndexPath, from view: FieldCopiedView) { }
}
