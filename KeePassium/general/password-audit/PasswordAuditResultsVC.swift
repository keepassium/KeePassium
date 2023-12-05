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

protocol PasswordAuditResultsVCDelegate: AnyObject {
    func didPressDismiss(in viewController: PasswordAuditResultsVC)
    func didPressDeleteEntries(entries: [Entry], in viewController: PasswordAuditResultsVC)
    func didPressExcludeEntries(entries: [Entry], in viewController: PasswordAuditResultsVC)
    func didPressEditEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: PasswordAuditResultsVC,
        onDismiss: @escaping () -> Void)
    func requestFormatUpgradeIfNecessary(
        in viewController: PasswordAuditResultsVC,
        didApprove: @escaping () -> Void)
}

final class PasswordAuditResultsVC: UIViewController {
    enum AllowedAction {
        case edit
        case delete
        case exclude
    }

    private enum CellID {
        static let result = "PasswordAuditResultCell"
        static let announcement = "AnnouncementCell"
    }


    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var toolBar: UIToolbar!


    private lazy var closeButton = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(didPressDismiss))

    private lazy var selectButton = UIBarButtonItem(
        title: LString.actionSelect,
        style: .plain,
        target: self,
        action: #selector(didPressSelect))

    private lazy var cancelButton = UIBarButtonItem(
        barButtonSystemItem: .cancel,
        target: self,
        action: #selector(didPressCancel))

    private lazy var deleteButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(didPressDelete))
        button.title = LString.actionDelete
        return button
    }()

    private lazy var moreButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage.symbol(.ellipsisCircle),
            style: .plain,
            target: self,
            action: nil)
        button.title = LString.titleMoreActions
        let excludeItemAction = UIAction(
            title: LString.actionExcludeFromAudit,
            image: UIImage.symbol(.bellSlash),
            handler: didPressExcludeEntries
        )
        button.menu = UIMenu(title: "", children: [excludeItemAction])
        return button
    }()

    private lazy var selectedCountLabel: UILabel = {
        let label = UILabel()
        label.textColor = .primaryText
        label.font = .preferredFont(forTextStyle: .callout)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()

    private lazy var noResultsView: UIView = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = LString.titleAllPasswordsAreSecure

        let wrapper = UIView()
        wrapper.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -16),
        ])
        return wrapper
    }()


    private let passwordAuditFinishTime = Date.now

    private var selectedEntries: [Entry] {
        guard let selection = tableView.indexPathsForSelectedRows,
              !selection.isEmpty
        else {
            return []
        }

        let selectedEntries = selection.map {
            let itemIndex = $0.row - announcements.count
            return items[itemIndex].entry
        }
        return selectedEntries
    }

    var items: [PasswordAuditService.PasswordAudit] = []
    var allowedActions: [AllowedAction] = []
    private var announcements: [AnnouncementItem] = []

    weak var delegate: PasswordAuditResultsVCDelegate?


    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.titleCompromisedPasswords
        navigationItem.rightBarButtonItem = closeButton

        tableView.register(
            AnnouncementCell.classForCoder(),
            forCellReuseIdentifier: CellID.announcement)

        announcements.append(AnnouncementItem(
            title: nil,
            body: LString.exposureCountDescription,
            actionTitle: nil,
            image: .symbol(.infoCircle)
        ))

        updateState(animated: false)
        tableView.backgroundView = noResultsView
        tableView.dataSource = self
        tableView.delegate = self
    }


    @objc
    private func didPressDismiss(_ sender: UIBarButtonItem) {
        delegate?.didPressDismiss(in: self)
    }

    @objc
    private func didPressSelect(_ sender: UIBarButtonItem) {
        tableView.setEditing(true, animated: true)
        updateState(animated: true)
    }

    @objc
    private func didPressCancel(_ sender: UIBarButtonItem) {
        tableView.setEditing(false, animated: true)
        updateState(animated: true)
    }

    @objc
    private func didPressDelete(_ sender: UIBarButtonItem) {
        delete(entries: selectedEntries)
    }

    private func didPressExcludeEntries(_ action: UIAction) {
        exclude(entries: selectedEntries)
    }


    private func exclude(entries: [Entry]) {
        let title = (entries.count == 1)
            ? entries[0].resolvedTitle
            : LString.confirmExcludeSelectionFromAudit
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(title: LString.actionExcludeFromAudit, style: .default) { [weak self] _ in
            guard let self else { return }
            self.delegate?.requestFormatUpgradeIfNecessary(in: self) { [weak self] in
                guard let self else { return }
                self.delegate?.didPressExcludeEntries(entries: entries, in: self)
                self.reload(removing: entries)
            }
        }
        sheet.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        present(sheet, animated: true)
    }

    private func delete(entries: [Entry]) {
        let title = entries.count == 1 ? entries[0].resolvedTitle : LString.confirmDeleteSelection
        let sheet = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(title: LString.actionDelete, style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.delegate?.didPressDeleteEntries(entries: entries, in: self)
            self.reload(removing: entries)
        }
        sheet.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        present(sheet, animated: true)
    }


    private func updateState(animated: Bool) {
        noResultsView.isHidden = !items.isEmpty
        tableView.allowsSelection = allowedActions.contains(.edit)

        guard allowedActions.contains(.delete) || allowedActions.contains(.exclude),
              !items.isEmpty
        else {
            toolBar.setItems([], animated: animated)
            toolBar.isHidden = true
            return
        }

        guard tableView.isEditing else {
            toolBar.setItems([selectButton], animated: animated)
            return
        }

        toolBar.setItems(getToolbarItems(), animated: animated)
        updateButtons()
    }

    private func getToolbarItems() -> [UIBarButtonItem] {
        var result = [
            cancelButton,
            UIBarButtonItem.flexibleSpace(),
            UIBarButtonItem(customView: selectedCountLabel),
            UIBarButtonItem.flexibleSpace(),
        ]
        if allowedActions.contains(.delete) {
            result.append(deleteButton)
        }
        if allowedActions.contains(.exclude) {
            result.append(UIBarButtonItem.fixedSpace(8))
            result.append(moreButton)
        }
        return result
    }

    private func updateButtons() {
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        deleteButton.isEnabled = selectedCount > 0
        moreButton.isEnabled = selectedCount > 0
        selectedCountLabel.isHidden = (selectedCount == 0)
        selectedCountLabel.text = EntriesSelectedCountFormatter.string(fromEntriesCount: selectedCount)
        selectedCountLabel.sizeToFit()
    }

    private func reload(removing entries: [Entry]) {
        items = items.filter { item in
            let shouldRemove = entries.contains { $0 === item.entry }
            return !shouldRemove
        }
        tableView.isEditing = false
        tableView.reloadData()
        updateState(animated: false)
    }
}


extension PasswordAuditResultsVC: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if items.isEmpty {
            return 0
        } else {
            return items.count + announcements.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < announcements.count {
            return makeAnnouncementCell(at: indexPath)
        } else {
            return makeResultCell(index: indexPath.row - announcements.count, at: indexPath)
        }
    }

    private func makeAnnouncementCell(at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: CellID.announcement, for: indexPath)
            as! AnnouncementCell
        let announcement = announcements[indexPath.row]
        cell.announcementView.apply(announcement)
        return cell
    }

    private func makeResultCell(index itemIndex: Int, at indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.result,
            for: indexPath)
            as! PasswordAuditResultCell

        let model = items[itemIndex]
        cell.model = model
        cell.isEdited = model.entry.lastModificationTime > passwordAuditFinishTime
        return cell
    }
}


extension PasswordAuditResultsVC: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if indexPath.row < announcements.count {
            return nil
        } else {
            return indexPath
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row >= announcements.count else {
            return
        }
        if allowedActions.isEmpty {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        if tableView.isEditing {
            updateButtons()
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
        let itemIndex = indexPath.row - announcements.count
        let selectedEntry = items[itemIndex].entry
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressEditEntry(selectedEntry, at: popoverAnchor, in: self) {
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard tableView.isEditing else {
            return
        }

        updateButtons()
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard indexPath.row >= announcements.count else {
            return false
        }
        return allowedActions.contains(.delete) || allowedActions.contains(.exclude)
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let itemIndex = indexPath.row - announcements.count
        guard itemIndex >= 0 else {
            return nil
        }

        let entry = items[itemIndex].entry
        var contextActions = [UIContextualAction]()
        if allowedActions.contains(.delete) {
            let deleteAction = UIContextualAction(style: .destructive, title: LString.actionDelete) {
                [weak self] _, _, completion in
                self?.delete(entries: [entry])
                completion(true)
            }
            deleteAction.image = .symbol(.trash)
            deleteAction.backgroundColor = .destructiveTint
            contextActions.append(deleteAction)
        }

        if allowedActions.contains(.exclude) {
            let excludeAction = UIContextualAction(style: .normal, title: LString.actionExcludeFromAudit) {
                [weak self] _, _, completion in
                self?.exclude(entries: [entry])
                completion(true)
            }
            excludeAction.image = .symbol(.bellSlash)
            excludeAction.backgroundColor = .actionTint
            contextActions.append(excludeAction)
        }

        return UISwipeActionsConfiguration(actions: contextActions)
    }
}
