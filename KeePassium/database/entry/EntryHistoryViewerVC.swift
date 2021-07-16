//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryHistoryViewerDelegate: AnyObject {
    func didSelectHistoryEntry(
        _ entry: Entry2,
        in viewController: EntryHistoryViewerVC
    )
    func didPressRestore(
        historyEntry entryToRestore: Entry2,
        in viewController: EntryHistoryViewerVC
    )
    func didPressDelete(
        historyEntries historyEntriesToDelete: [Entry2],
        in viewController: EntryHistoryViewerVC
    )
}

final class EntryHistoryTimestampCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
}

final class EntryHistoryItemCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    var restoreButton: UIButton! 
    
    var buttonHandler: (()->Void)?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        restoreButton = UIButton()
        restoreButton.setImage(UIImage.get(.clockArrowCirclepath), for: .normal)
        restoreButton.accessibilityLabel = LString.actionRestore
        restoreButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        restoreButton.addTarget(self, action: #selector(didTapButton(_:)), for: .touchUpInside)
        editingAccessoryView = restoreButton
    }
    
    @objc private func didTapButton(_ sender: AnyObject) {
        buttonHandler?()
    }
}

final class EntryHistoryViewerVC: TableViewControllerWithContextActions, Refreshable {
    private enum Section: Int { 
        case timestamps = 0
        case historyEntries = 1
    }
    
    private enum CellID { 
        static let fixedTimestamp = "TimestampCell"
        static let emptyHistory = "EmptyHistoryCell"
        static let historyItem = "HistoryItemCell"
    }
    
    private enum TimestampType: Int {
        static let all = [expiryTime, creationTime, lastModificationTime, lastAccessTime]
        case expiryTime = 0
        case creationTime = 1
        case lastModificationTime = 2
        case lastAccessTime = 3
        
        var title: String {
            switch self {
            case .expiryTime:
                return NSLocalizedString(
                    "[Entry/History] Expiry Date",
                    value: "Expiry Date",
                    comment: "Title of a field with date and time when the entry will no longer be valid. 'Never' is also a possible value")
            case .creationTime:
                return NSLocalizedString(
                    "[Entry/History] Creation Date",
                    value: "Creation Date",
                    comment: "Title of a field with entry creation date and time")
            case .lastModificationTime:
                return NSLocalizedString(
                    "[Entry/History] Last Modification Date",
                    value: "Last Modification Date",
                    comment: "Title of a field with entry's last modification date and time")
            case .lastAccessTime:
                return NSLocalizedString(
                    "[Entry/History] Last Access Date",
                    value: "Last Access Date",
                    comment: "Title of a field with date and time when the entry was last accessed/viewed")
            }
        }
    }
    
    weak var delegate: EntryHistoryViewerDelegate?
    private var canEditEntry = false
    
    private var canExpire = false
    private var expiryTime = Date.distantPast
    private var creationTime = Date.distantPast
    private var lastModificationTime = Date.distantPast
    private var lastAccessTime = Date.distantPast
    
    private var historyEntries: [Entry2]?
    private let dateFormatter = DateFormatter()
    
    private var deleteBarButton: UIBarButtonItem! 
    
    public func setContents(
        from entry: Entry,
        isHistoryEntry: Bool,
        canEditEntry: Bool,
        animated: Bool
    ) {
        self.canEditEntry = canEditEntry
        
        canExpire = entry.canExpire
        expiryTime = entry.expiryTime
        creationTime = entry.creationTime
        lastModificationTime = entry.lastModificationTime
        lastAccessTime = entry.lastAccessTime

        if let entry2 = entry as? Entry2 {
            historyEntries = isHistoryEntry ? nil : entry2.history
        } else {
            historyEntries = nil
        }
        refresh(animated: animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = editButtonItem
        tableView.allowsMultipleSelectionDuringEditing = true
        
        deleteBarButton = UIBarButtonItem(
            title: "", 
            style: .plain,
            target: self,
            action: #selector(confirmDeleteSelection(_:))
        )
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteBarButton
        ]
        updateToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        setEditing(false, animated: false)
    }
    
    func refresh() {
        refresh(animated: false)
    }
    
    func refresh(animated: Bool) {
        if traitCollection.horizontalSizeClass == .compact {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
        } else {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .long
        }
        
        editButtonItem.isEnabled = canEditEntry
        if animated {
            let visibleSections = IndexSet(0..<numberOfSections(in: tableView))
            tableView.reloadSections(visibleSections, with: .automatic)
        } else {
            tableView.reloadData()
        }
        updateToolbar()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        if historyEntries != nil {
            return 2
        } else {
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .timestamps:
            return TimestampType.all.count
        case .historyEntries:
            return max(1, historyEntries?.count ?? 0) // need at least one to show "there's no history"
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch Section(rawValue: section)! {
        case .timestamps:
            return nil
        case .historyEntries:
            return NSLocalizedString(
                "[Entry/History] Previous Versions",
                value: "Previous Versions",
                comment: "Title of a list with previous versions/revisions of an entry.")
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        willSelectRowAt indexPath: IndexPath
    ) -> IndexPath? {
        switch Section(rawValue: indexPath.section)! {
        case .timestamps:
            return nil
        case .historyEntries:
            return indexPath
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .timestamps:
            return setupTimestampCell(indexPath: indexPath)
        case .historyEntries:
            return setupHistoryEntryCell(indexPath: indexPath)
        }
    }
    
    private func setupTimestampCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.fixedTimestamp,
            for: indexPath)
            as! EntryHistoryTimestampCell

        let timestampType = TimestampType(rawValue: indexPath.row)! 
        cell.titleLabel.text = timestampType.title
        
        let timestamp: Date?
        switch timestampType {
        case .expiryTime:
            timestamp = canExpire ? expiryTime : nil
        case .creationTime:
            timestamp = creationTime
        case .lastModificationTime:
            timestamp = lastModificationTime
        case .lastAccessTime:
            timestamp = lastAccessTime
        }
        
        if let timestamp = timestamp {
            cell.valueLabel?.text = dateFormatter.string(from: timestamp)
        } else {
            cell.valueLabel?.text = NSLocalizedString(
                "[Entry/History/ExpiryDate] Never",
                value: "Never",
                comment: "Expiry Date of an entry which does not expire.")
        }
        return cell
    }
    
    private func setupHistoryEntryCell(indexPath: IndexPath) -> UITableViewCell {
        guard let historyEntries = historyEntries,
              historyEntries.count > 0
        else {
            return tableView.dequeueReusableCell(withIdentifier: CellID.emptyHistory, for: indexPath)
        }
        let historyEntry = historyEntries[indexPath.row]
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.historyItem,
            for: indexPath)
            as! EntryHistoryItemCell
        cell.titleLabel?.setText(historyEntry.resolvedTitle, strikethrough: historyEntry.isExpired)
        cell.subtitleLabel?.text = dateFormatter.string(from: historyEntry.lastModificationTime)
        cell.restoreButton.isHidden = !canEditEntry
        cell.buttonHandler = { [weak self, indexPath] in
            guard let self = self else { return }
            self.tableView(self.tableView, accessoryButtonTappedForRowWith: indexPath)
        }
        return cell
    }

    override func tableView(
        _ tableView: UITableView,
        commit editingStyle: UITableViewCell.EditingStyle,
        forRowAt indexPath: IndexPath
    ) {
        switch Section(rawValue: indexPath.section)! {
        case .timestamps:
            assertionFailure("Tried to modify non-editable cell")
        case .historyEntries:
            didPressDeleteHistoryEntry(index: indexPath.row)
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard canEditEntry else {
            return false
        }
        switch Section(rawValue: indexPath.section)! {
        case .timestamps:
            return false
        case .historyEntries:
            return (historyEntries?.count ?? 0) > 0
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        editingStyleForRowAt indexPath: IndexPath
    ) -> UITableViewCell.EditingStyle {
        assert(canEditEntry)
        switch Section(rawValue: indexPath.section)! {
        case .timestamps:
            return .none
        case .historyEntries:
            return .delete
        }
    }
    
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        assert(canEditEntry || !editing)
        super.setEditing(editing, animated: animated)
        updateToolbar()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section),
              section == .historyEntries,
              let historyEntries = historyEntries
        else {
            assertionFailure()
            return
        }
        if historyEntries.isEmpty {
            return
        }
        assert(indexPath.row < historyEntries.count)

        if tableView.isEditing {
            updateToolbar()
        } else {
            let selectedHistoryEntry = historyEntries[indexPath.row]
            delegate?.didSelectHistoryEntry(selectedHistoryEntry, in: self)
        }
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section),
              section == .historyEntries,
              let historyEntries = historyEntries
        else {
            assertionFailure()
            return
        }
        if historyEntries.isEmpty {
            return
        }
        assert(indexPath.row < historyEntries.count)
        
        if tableView.isEditing {
            updateToolbar()
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath
    ) {
        guard let section = Section(rawValue: indexPath.section),
              section == .historyEntries,
              let historyEntries = historyEntries
        else {
            assertionFailure()
            return
        }
        if historyEntries.isEmpty {
            return
        }
        assert(indexPath.row < historyEntries.count)
        
        if isEditing {
            didPressRestoreHistoryEntry(index: indexPath.row)
        }
    }
    
    
    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        guard let section = Section(rawValue: indexPath.section),
              section == .historyEntries,
              let historyEntries = historyEntries,  
              indexPath.row < historyEntries.count, 
              canEditEntry
        else {
            return []
        }
        
        let deleteAction = ContextualAction(
            title: LString.actionDelete,
            imageName: .trash,
            style: .destructive,
            color: .destructiveTint,
            handler: { [weak self] in
                self?.didPressDeleteHistoryEntry(index: indexPath.row)
            }
        )
        if forSwipe {
            return [deleteAction]
        }

        let restoreAction = ContextualAction(
            title: LString.actionRestore,
            imageName: .clockArrowCirclepath,
            style: .default,
            color: .actionTint,
            handler: { [weak self] in
                self?.didPressRestoreHistoryEntry(index: indexPath.row)
            }
        )
        return [restoreAction, deleteAction]
    }
    
    private func didPressRestoreHistoryEntry(index: Int) {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry")
            assertionFailure()
            return
        }
        guard let historyEntries = historyEntries else {
            assertionFailure("There are no history entries")
            return
        }
        let entry = historyEntries[index]
        delegate?.didPressRestore(historyEntry: entry, in: self)
    }
    
    private func didPressDeleteHistoryEntry(index: Int) {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry")
            assertionFailure()
            return
        }
        guard let historyEntries = historyEntries else {
            assertionFailure("There are no history entries")
            return
        }
        let entryToDelete = historyEntries[index]
        delegate?.didPressDelete(historyEntries: [entryToDelete], in: self)
    }
    
    @objc private func confirmDeleteSelection(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .actionSheet)
        alert.addAction(title: sender.title, style: .destructive) { [weak self] _ in
            self?.didPressDeleteSelection()
        }
        alert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        popoverAnchor.apply(to: alert.popoverPresentationController)
        present(alert, animated: true, completion: nil)
    }
    
    private func didPressDeleteSelection() {
        guard canEditEntry else {
            Diag.warning("Tried to modify non-editable entry")
            assertionFailure()
            return
        }
        guard let historyEntries = historyEntries else {
            assertionFailure("There are no history entries")
            return
        }
        
        let entriesToDelete: [Entry2]
        if let selectedIndexPaths = tableView.indexPathsForSelectedRows {
            Diag.debug("Deleting selected history entries")
            entriesToDelete = selectedIndexPaths.map {
                historyEntries[$0.row]
            }
        } else {
            Diag.debug("Deleting all history entries")
            entriesToDelete = historyEntries
        }
        delegate?.didPressDelete(historyEntries: entriesToDelete, in: self)
    }
    
    private func updateToolbar() {
        let hasHistoryEntries = (historyEntries?.count ?? 0) > 0
        deleteBarButton.isEnabled = canEditEntry && isEditing && hasHistoryEntries
        if tableView.indexPathsForSelectedRows != nil {
            deleteBarButton.title = LString.actionDelete
        } else {
            deleteBarButton.title = LString.actionDeleteAll
        }
    }
    
}
