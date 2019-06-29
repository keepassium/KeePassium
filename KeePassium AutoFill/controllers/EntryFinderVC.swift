//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import AuthenticationServices

protocol EntryFinderDelegate: class {
    func entryFinder(_ sender: EntryFinderVC, didSelectEntry entry: Entry)
    func entryFinderShouldLockDatabase(_ sender: EntryFinderVC)
}

class EntryFinderCell: UITableViewCell {
    fileprivate static let storyboardID = "EntryFinderCell"
    fileprivate var entry: Entry? {
        didSet {
            guard let entry = entry else {
                textLabel?.text = ""
                detailTextLabel?.text = ""
                imageView?.image = nil
                return
            }
            textLabel?.text = entry.title
            detailTextLabel?.text = entry.userName
            imageView?.image = UIImage.kpIcon(forEntry: entry)
        }
    }
}

class EntryFinderVC: UITableViewController {
    private enum CellID {
        static let entry = EntryFinderCell.storyboardID
        static let nothingFound = "NothingFoundCell"
    }
    @IBOutlet var separatorView: UIView!
    
    weak var database: Database?
    weak var delegate: EntryFinderDelegate?
    var databaseName: String? {
        didSet{ refreshDatabaseName() }
    }
    var serviceIdentifiers = [ASCredentialServiceIdentifier]() {
        didSet{ updateSearchCriteria() }
    }
    
    private var searchHelper = SearchHelper()
    private var searchResults = SearchResults(exactMatch: [], partialMatch: [])
    private var searchController: UISearchController! 
    private var manualSearchButton: UIBarButtonItem! 

    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false
        setupSearch()

        manualSearchButton = UIBarButtonItem(
            barButtonSystemItem: .search,
            target: self,
            action: #selector(didPressManualSearch))
        navigationItem.rightBarButtonItem = manualSearchButton

        refreshDatabaseName()
        updateSearchCriteria()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: true)
    }
    
    private func setupSearch() {
        searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.barStyle = .default
        
        searchController.dimsBackgroundDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        definesPresentationContext = true
    }
    
    private func updateSearchCriteria() {
        guard isViewLoaded, let database = database else { return }
        
        let automaticResults = searchHelper.find(
            database: database,
            serviceIdentifiers: serviceIdentifiers
        )
        if !automaticResults.isEmpty {
            searchResults = automaticResults
            tableView.reloadData()
            return
        }
    
        updateSearchResults(for: searchController)
        DispatchQueue.main.async {
            self.searchController.isActive = true
            self.searchController.searchBar.becomeFirstResponder()
        }
        
    }
    
    func refreshDatabaseName() {
        guard isViewLoaded else { return }
        navigationItem.title = databaseName
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        if searchResults.isEmpty {
            return 1 // for "Nothing found" cell
        }
        
        var nSections = searchResults.exactMatch.count
        let hasPartialResults = !searchResults.partialMatch.isEmpty
        if hasPartialResults {
            nSections += searchResults.partialMatch.count + 1 
        }
        return nSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if searchResults.isEmpty {
            return (section == 0) ? 1 : 0 // "Nothing found" cell
        }
        let nExactResults = searchResults.exactMatch.count
        if section < nExactResults {
            let iExactResult = section
            return searchResults.exactMatch[iExactResult].entries.count
        } else if section == nExactResults {
            return 0
        } else {
            let iPartialResult = section - nExactResults - 1
            return searchResults.partialMatch[iPartialResult].entries.count
        }
    }
    
    override open func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
        ) -> String?
    {
        guard !searchResults.isEmpty else { return nil }

        let nExactResults = searchResults.exactMatch.count
        if section < nExactResults {
            let iExactResult = section
            return searchResults.exactMatch[iExactResult].group.name
        } else if section == nExactResults {
            return nil
        } else {
            let iPartialResult = section - nExactResults - 1
            return searchResults.partialMatch[iPartialResult].group.name
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let hasPartialResults = searchResults.partialMatch.count > 0
        let nExactResults = searchResults.exactMatch.count
        if hasPartialResults && section == nExactResults {
            return separatorView
        }
        return nil
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        if searchResults.isEmpty {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: CellID.nothingFound,
                for: indexPath)
            return cell
        }

        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.entry,
            for: indexPath)
            as! EntryFinderCell

        let section = indexPath.section
        let nExactResults = searchResults.exactMatch.count
        if section < nExactResults {
            let iExactResult = section
            cell.entry = searchResults.exactMatch[iExactResult].entries[indexPath.row].entry
        } else if section == nExactResults {
            assertionFailure("Should not be here")
        } else {
            let iPartialResult = section - nExactResults - 1
            cell.entry = searchResults.partialMatch[iPartialResult].entries[indexPath.row].entry
        }
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Watchdog.shared.restart()
        let section = indexPath.section
        let nExactResults = searchResults.exactMatch.count
        if section < nExactResults {
            let iExactResult = section
            let selectedEntry = searchResults.exactMatch[iExactResult].entries[indexPath.row].entry
            delegate?.entryFinder(self, didSelectEntry: selectedEntry)
        } else if section == nExactResults {
            assertionFailure("Should not be here")
        } else {
            let iPartialResult = section - nExactResults - 1
            let selectedEntry = searchResults.partialMatch[iPartialResult].entries[indexPath.row].entry
            delegate?.entryFinder(self, didSelectEntry: selectedEntry)
        }
    }
    
    @objc func didPressManualSearch(_ sender: Any) {
        serviceIdentifiers.removeAll()
        updateSearchCriteria()
        searchController.searchBar.becomeFirstResponder()
    }
    
    @IBAction func didPressLockDatabase(_ sender: Any) {
        Watchdog.shared.restart()
        delegate?.entryFinderShouldLockDatabase(self)
    }
}

extension EntryFinderVC: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        Watchdog.shared.restart()
        guard let searchText = searchController.searchBar.text,
            let database = database else { return }
        searchResults = searchHelper.find(database: database, searchText: searchText)
        sortSearchResults()
        tableView.reloadData()
    }

    private func sortSearchResults() {
        let groupSortOrder = Settings.current.groupSortOrder
        searchResults.exactMatch.sort { return groupSortOrder.compare($0.group, $1.group) }
        searchResults.partialMatch.sort { return groupSortOrder.compare($0.group, $1.group) }
    }
}
