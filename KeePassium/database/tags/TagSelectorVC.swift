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

protocol TagSelectorVCDelegate: AnyObject {
    func didPressDismiss(in viewController: TagSelectorVC)
    func didToggleTag(_ tag: Tag, in viewController: TagSelectorVC)
    func didMoveTag(_ tag: Tag, to row: Int, in viewController: TagSelectorVC)
    func didPressDeleteTag(_ tag: Tag, in viewController: TagSelectorVC)
    func didPressRenameTag(_ tag: Tag, newTitle: String, in viewController: TagSelectorVC)

    func didPressAddTag(tagText: String?, in viewController: TagSelectorVC)
    func isTagTextValid(_ tagText: String?, in viewController: TagSelectorVC) -> Bool

    func getSections(for viewController: TagSelectorVC) -> [TagSelectorVC.Section]
}

final class TagSelectorVC: TableViewControllerWithContextActions {

    enum Section {
        case selected([Tag])
        case inherited([Tag])
        case all([Tag])

        var tags: [Tag] {
            switch self {
            case .selected(let tags), .inherited(let tags), .all(let tags):
                return tags
            }
        }

        var title: String {
            switch self {
            case .selected:
                return LString.selectedTags
            case .inherited:
                return LString.inheritedTags
            case .all:
                return LString.allTags
            }
        }

        var subtitle: String? {
            switch self {
            case .selected, .inherited:
                return nil
            case .all:
                return LString.tagUsageCount
            }
        }
    }

    private enum CellID {
        static let tagCell = "TagCell"
    }

    private let noDataLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .center
        return label
    }()

    private var filteredData: [Section] = [] {
        didSet {
            noDataLabel.isHidden = !filteredData.isEmpty
            if let text = searchController.searchBar.text, !text.isEmpty {
                noDataLabel.text = LString.statusNoTagsFound
            } else {
                noDataLabel.text = LString.statusNoTagsInDatabase
            }
        }
    }

    private var searchController: UISearchController!

    weak var delegate: TagSelectorVCDelegate?

    private lazy var tagCellConfiguration: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.valueCell()
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        configuration.textProperties.color = .primaryText
        configuration.imageToTextPadding = 8
        configuration.imageProperties.tintColor = .actionTint
        configuration.imageProperties.preferredSymbolConfiguration = .init(textStyle: .body)
        configuration.imageProperties.reservedLayoutSize = CGSize(width: 32, height: 0)
        configuration.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .callout)
        configuration.secondaryTextProperties.color = .auxiliaryText
        configuration.secondaryTextProperties.adjustsFontForContentSizeCategory = true
        return configuration
    }()

    public static func create() -> TagSelectorVC {
        return Self()
    }

    init() {
        super.init(style: .plain)

        registerCellClasses(tableView)
        tableView.backgroundView = noDataLabel
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellID.tagCell)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.fieldTags
        let createTagButton = UIBarButtonItem(
            image: .symbol(.plus),
            style: .plain,
            target: self,
            action: #selector(didPressAdd))
        createTagButton.accessibilityLabel = LString.actionCreateTag
        navigationItem.rightBarButtonItem = createTagButton

        setupSearch()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh(animated: false)
    }

    private func setupSearch() {
        searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false

        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.barStyle = .default
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false

        definesPresentationContext = true
        searchController.searchResultsUpdater = self
    }

    @objc private func didPressAdd(_ sender: UIBarButtonItem) {
        showTagEditor(title: LString.titleNewTag, actionTitle: LString.actionCreateTag) { [weak self] text in
            guard let self else { return }
            self.delegate?.didPressAddTag(tagText: text, in: self)
        }
    }

    private func showTagEditor(
        title: String,
        actionTitle: String,
        value: String? = nil,
        doneHandler: @escaping (String) -> Void
    ) {
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        let doneAction = UIAlertAction(title: actionTitle, style: .default) {
            [weak self, weak alert] _ in
            guard let self, let alert else { return }
            let textField = alert.textFields?.first
            doneHandler(textField?.text ?? "")
            self.refresh(animated: true)
        }
        doneAction.isEnabled = delegate?.isTagTextValid(value, in: self) ?? false
        alert.addAction(doneAction)

        alert.addTextField { [weak self] textField in
            textField.text = value
            textField.placeholder = LString.sampleTagsPlaceholder
            NotificationCenter.default.addObserver(
                forName: UITextField.textDidChangeNotification,
                object: textField,
                queue: OperationQueue.main
            ) { [weak self] _ in
                guard let self else { return }
                doneAction.isEnabled = self.delegate?.isTagTextValid(textField.text, in: self) ?? false
            }
        }
        alert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)

        alert.preferredAction = doneAction
        present(alert, animated: true)
    }

    func refresh(animated: Bool = false) {
        let oldData = filteredData
        filter()

        guard animated else {
            tableView.reloadData()
            restoreRowSelection()
            return
        }

        guard oldData.count != filteredData.count else {
            tableView.reloadSections([0, filteredData.count - 1], with: .automatic)
            restoreRowSelection()
            return
        }

        tableView.beginUpdates()
        tableView.insertSections([0], with: .automatic)
        tableView.endUpdates()
        restoreRowSelection()
    }

    func restoreRowSelection() {
        for (iSection, section) in filteredData.enumerated() {
            for (iRow, tag) in section.tags.enumerated() {
                if tag.selected {
                    tableView.selectRow(
                        at: IndexPath(row: iRow, section: iSection),
                        animated: false,
                        scrollPosition: .none
                    )
                }
            }
        }
    }

    override func getContextActionsForRow(at indexPath: IndexPath, forSwipe: Bool) -> [ContextualAction] {
        switch filteredData[indexPath.section] {
        case .selected, .inherited:
            return []
        case .all:
            let tag = filteredData[indexPath.section].tags[indexPath.row]
            let deleteAction = ContextualAction(
                title: LString.actionDelete,
                imageName: .trash,
                style: .destructive,
                color: .destructiveTint
            ) { [weak self] in
                let sheet = UIAlertController(
                    title: tag.title,
                    message: LString.confirmDeleteTag,
                    preferredStyle: .alert
                )
                sheet.addAction(title: LString.actionDelete, style: .destructive) { [weak self] _ in
                    guard let self else { return }
                    self.delegate?.didPressDeleteTag(tag, in: self)
                }
                sheet.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
                self?.present(sheet, animated: true)
            }
            let editAction = ContextualAction(
                title: LString.actionEdit,
                imageName: .squareAndPencil,
                style: .default,
                color: .actionTint
            ) { [weak self] in
                self?.showTagEditor(
                    title: LString.titleEditTag,
                    actionTitle: LString.actionRename,
                    value: tag.title
                ) {  [weak self] title in
                    guard let self = self else { return }
                    self.delegate?.didPressRenameTag(tag, newTitle: title, in: self)
                }
            }
            return [editAction, deleteAction]
        }
    }
}

extension TagSelectorVC {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch filteredData[indexPath.section] {
        case .inherited:
            break
        case .all:
            delegate?.didToggleTag(filteredData[indexPath.section].tags[indexPath.row], in: self)
            refresh(animated: true)
        case .selected:
            delegate?.didToggleTag(filteredData[indexPath.section].tags[indexPath.row], in: self)
            refresh(animated: false)
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        delegate?.didToggleTag(filteredData[indexPath.section].tags[indexPath.row], in: self)
        refresh(animated: false)
    }
}

extension TagSelectorVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return filteredData.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredData[section].tags.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CellID.tagCell, for: indexPath)
        configure(cell: cell, tag: filteredData[indexPath.section].tags[indexPath.row])
        switch filteredData[indexPath.section] {
        case .inherited:
            cell.selectionStyle = .none
        default:
            cell.selectionStyle = .default
        }
        return cell
    }

    private func configure(cell: UITableViewCell, tag: Tag) {
        var content = tagCellConfiguration
        content.imageProperties.tintColor = tag.tintColor
        content.text = tag.title
        if let tagCount = tag.count {
            content.secondaryText = String(tagCount)
        } else {
            content.secondaryText = nil
        }
        cell.contentConfiguration = content

        cell.configurationUpdateHandler = { cell, state in
            var updatedContent = content.updated(for: state)
            if state.isSelected || state.isHighlighted {
                updatedContent.image = .symbol(.checkmark)
            } else {
                updatedContent.image = UIImage()
            }
            cell.contentConfiguration = updatedContent

            var backgroundContent = cell.backgroundConfiguration?.updated(for: state)
            backgroundContent?.backgroundColor = .clear
            cell.backgroundConfiguration = backgroundContent
        }
    }

    override func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        cell.showsReorderControl = self.tableView(tableView, canMoveRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionInfo = filteredData[section]
        var config = UIListContentConfiguration.plainHeader()
        config.text = sectionInfo.title
        config.secondaryText = sectionInfo.subtitle
        config.textToSecondaryTextHorizontalPadding = 16
        config.prefersSideBySideTextAndSecondaryText = true

        let headerView = UITableViewHeaderFooterView()
        headerView.contentConfiguration = config
        return headerView
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if let text = searchController.searchBar.text, !text.isEmpty {
            return false
        }

        switch filteredData[indexPath.section] {
        case .selected:
            return true
        case .inherited, .all:
            return false
        }
    }

    override func tableView(
        _ tableView: UITableView,
        moveRowAt sourceIndexPath: IndexPath,
        to destinationIndexPath: IndexPath
    ) {
        delegate?.didMoveTag(
            filteredData[sourceIndexPath.section].tags[sourceIndexPath.row],
            to: destinationIndexPath.row,
            in: self
        )
        filter()
    }

    override func tableView(
        _ tableView: UITableView,
        targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
        toProposedIndexPath proposedDestinationIndexPath: IndexPath
    ) -> IndexPath {
        guard sourceIndexPath.section != proposedDestinationIndexPath.section else {
            return proposedDestinationIndexPath
        }

        if sourceIndexPath.section < proposedDestinationIndexPath.section {
            return IndexPath(
                row: tableView.numberOfRows(inSection: sourceIndexPath.section) - 1,
                section: sourceIndexPath.section
            )
        }

        return IndexPath(row: 0, section: sourceIndexPath.section)
    }

    override func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        restoreRowSelection()
    }
}

#if targetEnvironment(macCatalyst)
extension TagSelectorVC {
    override func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        return nil
    }
}
#endif

extension TagSelectorVC: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        refresh()
    }

    private func filter() {
        guard let data = delegate?.getSections(for: self) else {
            return
        }

        let searchText = searchController.searchBar.searchTextField.text
        let filter = { (tag: Tag) -> Bool in
            guard let searchText, !searchText.isEmpty else {
                return true
            }
            return tag.contains(text: searchText)
        }

        filteredData = data.compactMap {
            let tags = $0.tags.filter(filter)
            if tags.isEmpty {
                return nil
            }
            switch $0 {
            case .selected:
                return .selected(tags)
            case .inherited:
                return .inherited(tags)
            case .all:
                return .all(tags)
            }
        }
    }
}
