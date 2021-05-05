//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryHistoryViewerDelegate: AnyObject {
    func didSelectHistoryEntry(_ entry: Entry, in viewController: EntryHistoryViewerVC)
}

final class EntryHistoryViewerVC: UITableViewController, Refreshable {

    private let numberOfFixedTimestamps = 4 
    private enum Section: Int { 
        case expiryTime = 0
        case creationTime = 1
        case lastModificationTime = 2
        case lastAccessTime = 3
        case previousVersions = 4
    }
    private enum CellID { 
        static let fixedTimestamp = "FixedTimestampCell"
        static let emptyHistory = "EmptyHistoryCell"
        static let historyItem = "HistoryItemCell"
    }

    weak var delegate: EntryHistoryViewerDelegate?
    
    private var canExpire = false
    private var expiryTime = Date.distantPast
    private var creationTime = Date.distantPast
    private var lastModificationTime = Date.distantPast
    private var lastAccessTime = Date.distantPast
    
    private var historyEntries: [Entry]?
    private let dateFormatter = DateFormatter()
    
    public func setContents(from entry: Entry, isHistoryEntry: Bool) {
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
        refresh()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.rightBarButtonItem = nil
        refresh()
    }
    
    func refresh() {
        if traitCollection.horizontalSizeClass == .compact {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
        } else {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .long
        }
        tableView.reloadData()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refresh()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        if historyEntries != nil {
            return numberOfFixedTimestamps + 1
        } else {
            return numberOfFixedTimestamps
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section < numberOfFixedTimestamps {
            return 1
        } else {
            return max(1, historyEntries?.count ?? 0) // need at least one to show "there's no history"
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch Section(rawValue: section)! {
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
        case .previousVersions:
            return NSLocalizedString(
                "[Entry/History] Previous Versions",
                value: "Previous Versions",
                comment: "Title of a list with previous versions/revisions of an entry.")
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .expiryTime:
            return setupTimestampCell(indexPath: indexPath, timestamp: canExpire ? expiryTime : nil)
        case .creationTime:
            return setupTimestampCell(indexPath: indexPath, timestamp: creationTime)
        case .lastModificationTime:
            return setupTimestampCell(indexPath: indexPath, timestamp: lastModificationTime)
        case .lastAccessTime:
            return setupTimestampCell(indexPath: indexPath, timestamp: lastAccessTime)
        case .previousVersions:
            return setupHistoryEntryCell(indexPath: indexPath)
        }
    }

    private func setupTimestampCell(indexPath: IndexPath, timestamp: Date?) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.fixedTimestamp,
            for: indexPath
        )
        if let timestamp = timestamp {
            cell.textLabel?.text = dateFormatter.string(from: timestamp)
        } else {
            cell.textLabel?.text = NSLocalizedString(
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
        let cell = tableView.dequeueReusableCell(withIdentifier: CellID.historyItem, for: indexPath)
        cell.textLabel?.setText(historyEntry.resolvedTitle, strikethrough: historyEntry.isExpired)
        cell.detailTextLabel?.text = dateFormatter.string(from: historyEntry.lastModificationTime)
        return cell
    }

    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section),
              section == .previousVersions,
              let historyEntries = historyEntries,
              indexPath.row < historyEntries.count
        else {
            return
        }
        
        let selectedHistoryEntry = historyEntries[indexPath.row]
        delegate?.didSelectHistoryEntry(selectedHistoryEntry, in: self)
    }
}
