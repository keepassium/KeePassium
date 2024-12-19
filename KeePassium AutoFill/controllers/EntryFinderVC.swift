//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol EntryFinderDelegate: AnyObject {
    func didLoadViewController(_ viewController: EntryFinderVC)
    func didChangeSearchQuery(_ searchText: String, in viewController: EntryFinderVC)
    func didSelectEntry(_ entry: Entry, in viewController: EntryFinderVC)
    func didPressLockDatabase(in viewController: EntryFinderVC)

    func getAnnouncements(for viewController: EntryFinderVC) -> [AnnouncementItem]

    @available(iOS 18.0, *)
    func getSelectableFields(for entry: Entry) -> [EntryField]?

    @available(iOS 18.0, *)
    func didSelectField(_ field: EntryField, from entry: Entry, in viewController: EntryFinderVC)
}

final class EntryFinderCell: UITableViewCell {
    fileprivate static let storyboardID = "EntryFinderCell"

    var menu: UIMenu? {
        didSet {
            theButton?.menu = menu
            theButton.isEnabled = menu != nil
        }
    }

    private var theButton: UIButton!

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var passkeyIndicator: UIImageView!

    fileprivate var entry: Entry? {
        didSet {
            guard let entry = entry else {
                titleLabel?.text = ""
                subtitleLabel?.text = ""
                iconView?.image = nil
                passkeyIndicator.setVisible(false)
                return
            }
            titleLabel?.text = entry.getField(EntryField.title)?.decoratedResolvedValue
            subtitleLabel?.text = entry.getField(EntryField.userName)?.decoratedResolvedValue
            iconView?.image = UIImage.kpIcon(forEntry: entry)
            passkeyIndicator.setVisible(Passkey.probablyPresent(in: entry))
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        theButton = UIButton(frame: self.bounds)
        contentView.addSubview(theButton)
        theButton.isAccessibilityElement = false
        theButton.backgroundColor = .clear
        theButton.showsMenuAsPrimaryAction = true
        theButton.menu = menu
    }
}

final class CallerIDView: UIView {
    @IBOutlet weak var textLabel: UILabel!
    @IBOutlet weak var copyButton: UIButton!

    typealias CopyHandler = (CallerIDView) -> Void
    var copyHandler: CopyHandler?

    @IBAction private func didPressCopyButton(_ sender: Any) {
        copyHandler?(self)
    }

    func blink() {
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: .curveEaseOut,
            animations: {
                self.textLabel.alpha = 0.3
            },
            completion: { _ in
                self.textLabel.alpha = 1.0
            }
        )
    }
}

final class EntryFinderVC: UITableViewController {
    private enum CellID {
        static let announcement = "AnnouncementCell"
        static let entry = EntryFinderCell.storyboardID
        static let nothingFound = "NothingFoundCell"
    }
    @IBOutlet var separatorView: UIView!
    @IBOutlet var callerIDView: CallerIDView!

    weak var delegate: EntryFinderDelegate?

    var autoFillMode: AutoFillMode?

    var callerID: String? {
        didSet { refreshCallerID() }
    }

    private var announcements = [AnnouncementItem]()

    private var searchController: UISearchController! 
    private var manualSearchButton: UIBarButtonItem! 
    private var searchResults = FuzzySearchResults(exactMatch: [], partialMatch: [])

    override var canDismissFromKeyboard: Bool {
        return !(searchController?.isActive ?? false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSearch()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        tableView.register(AnnouncementCell.classForCoder(), forCellReuseIdentifier: CellID.announcement)
        tableView.selectionFollowsFocus = true
        tableView.sectionHeaderTopPadding = 1 

        manualSearchButton = UIBarButtonItem(
            barButtonSystemItem: .search,
            target: self,
            action: #selector(didPressManualSearch))
        navigationItem.rightBarButtonItem = manualSearchButton
        delegate?.didLoadViewController(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: false)
        refreshCallerID()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.navigationBar.isUserInteractionEnabled = true
    }


    private func setupSearch() {
        searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.barStyle = .default
        searchController.searchBar.delegate = self

        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        definesPresentationContext = true
    }

    private func refreshCallerID() {
        guard isViewLoaded else {
            return
        }

        let hasCallerID = callerID?.isNotEmpty ?? false
        callerIDView.copyButton.isHidden = !hasCallerID
        let callerIDText = self.callerID ?? "?"
        callerIDView.textLabel.text = String.localizedStringWithFormat(
            LString.autoFillContextTemplate,
            callerIDText
        )
        callerIDView.copyHandler = { (view: CallerIDView) in
            Clipboard.general.copyWithTimeout(callerIDText)
            HapticFeedback.play(.copiedToClipboard)
            view.blink()
        }
        tableView.tableFooterView = callerIDView
    }

    public func setSearchResults(_ newResults: FuzzySearchResults) {
        searchResults = newResults

        let groupSortOrder = Settings.current.groupSortOrder
        searchResults.exactMatch.sort(order: groupSortOrder)
        searchResults.partialMatch.sort(order: groupSortOrder)

        refresh()
    }

    public func activateManualSearch(query: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.searchController.isActive = true
            self.searchController.searchBar.text = query
            self.searchController.searchBar.becomeFirstResponderWhenSafe()

            let searchText = self.searchController.searchBar.text ?? ""
            self.delegate?.didChangeSearchQuery(searchText, in: self)
        }
    }

    func refresh() {
        guard isViewLoaded else {
            return
        }
        announcements = delegate?.getAnnouncements(for: self) ?? []
        tableView.reloadData()
    }

    func refreshAnnouncements() {
        guard isViewLoaded else { return }
        let wasEmpty = announcements.isEmpty
        announcements = delegate?.getAnnouncements(for: self) ?? []
        let isEmpty = announcements.isEmpty

        if wasEmpty != isEmpty {
            tableView.reloadData()
        } else {
            tableView.reloadSections([0], with: .automatic)
        }
    }

    func setPasskeyTargetSelectionMode() {
        title = LString.actionAddPasskeyToExistingEntry
    }

    private enum SectionType {
        case announcement
        case nothingFound
        case exactMatch
        case matchSeparator
        case partialMatch
    }

    private func getSectionTypeAndIndex(_ section: Int) -> (SectionType, Int) {
        let precedingSections = announcements.isEmpty ? 0 : 1
        let resultSection = section - precedingSections
        if resultSection < 0 {
            return (.announcement, section)
        }
        if searchResults.isEmpty {
            return (.nothingFound, 0)
        }

        let nExactResults = searchResults.exactMatch.count
        if resultSection < nExactResults {
            return (.exactMatch, resultSection)
        } else if resultSection == nExactResults {
            return (.matchSeparator, 0)
        } else {
            return (.partialMatch, resultSection - nExactResults - 1)
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        let nAnnouncementSections = announcements.isEmpty ? 0 : 1
        if searchResults.isEmpty {
            return nAnnouncementSections + 1 // for "Nothing found" cell
        }

        var nSearchResultSections = searchResults.exactMatch.count
        let hasPartialResults = !searchResults.partialMatch.isEmpty
        if hasPartialResults {
            nSearchResultSections += searchResults.partialMatch.count + 1 
        }
        return nAnnouncementSections + nSearchResultSections
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let (sectionType, sectionIndex) = getSectionTypeAndIndex(section)
        switch sectionType {
        case .announcement:
            return announcements.count
        case .nothingFound:
            return 1 // "Nothing found" cell
        case .exactMatch:
            return searchResults.exactMatch[sectionIndex].scoredItems.count
        case .matchSeparator:
            return 0
        case .partialMatch:
            return searchResults.partialMatch[sectionIndex].scoredItems.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        let (sectionType, sectionIndex) = getSectionTypeAndIndex(section)
        switch sectionType {
        case .announcement, .nothingFound, .matchSeparator:
            return nil
        case .exactMatch:
            return searchResults.exactMatch[sectionIndex].group.name
        case .partialMatch:
            return searchResults.partialMatch[sectionIndex].group.name
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let (sectionType, _) = getSectionTypeAndIndex(section)
        switch sectionType {
        case .nothingFound:
            return 1 
        case .matchSeparator:
            return 20
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let (sectionType, _) = getSectionTypeAndIndex(section)
        switch sectionType {
        case .announcement, .exactMatch, .partialMatch, .nothingFound:
            return 8 
        default:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let (sectionType, _) = getSectionTypeAndIndex(section)
        switch sectionType {
        case .matchSeparator:
            return separatorView
        default:
            return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let (sectionType, sectionIndex) = getSectionTypeAndIndex(indexPath.section)
        switch sectionType {
        case .announcement:
            return makeAnnouncementCell(at: indexPath)
        case .nothingFound:
            return makeNothingFoundCell(at: indexPath)
        case .exactMatch:
            let exactMatchSection = searchResults.exactMatch[sectionIndex]
            let entry = exactMatchSection.scoredItems[indexPath.row].item as? Entry
            return makeResultCell(at: indexPath, entry: entry)
        case .matchSeparator:
            assertionFailure("Result separator is not supposed to contain cells")
            return makeNothingFoundCell(at: indexPath)
        case .partialMatch:
            let partialMatchSection = searchResults.partialMatch[sectionIndex]
            let entry = partialMatchSection.scoredItems[indexPath.row].item as? Entry
            return makeResultCell(at: indexPath, entry: entry)
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

    private func makeNothingFoundCell(at indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(
            withIdentifier: CellID.nothingFound,
            for: indexPath
        )
    }

    private func makeResultCell(at indexPath: IndexPath, entry: Entry?) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.entry,
            for: indexPath)
            as! EntryFinderCell
        cell.entry = entry
        cell.menu = createMenu(for: entry)
        let hasMenu = cell.menu != nil
        cell.accessoryType = hasMenu ? .disclosureIndicator : .none
        return cell
    }


    override func tableView(
        _ tableView: UITableView,
        willSelectRowAt indexPath: IndexPath
    ) -> IndexPath? {
        let (sectionType, _) = getSectionTypeAndIndex(indexPath.section)
        switch sectionType {
        case .announcement, .matchSeparator, .nothingFound: 
            return nil
        default:
            return indexPath
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Watchdog.shared.restart()

        let (sectionType, sectionIndex) = getSectionTypeAndIndex(indexPath.section)
        switch sectionType {
        case .announcement, .matchSeparator, .nothingFound:
            return
        case .exactMatch:
            let exactMatchSection = searchResults.exactMatch[sectionIndex]
            guard let entry = exactMatchSection.scoredItems[indexPath.row].item as? Entry else {
                return
            }
            delegate?.didSelectEntry(entry, in: self)
        case .partialMatch:
            let partialMatchSection = searchResults.partialMatch[sectionIndex]
            guard let entry = partialMatchSection.scoredItems[indexPath.row].item as? Entry else {
                return
            }
            delegate?.didSelectEntry(entry, in: self)
        }
    }

    private func createMenu(for entry: Entry?) -> UIMenu? {
        guard let entry,
              #available(iOS 18, *),
              let selectableFields = delegate?.getSelectableFields(for: entry),
              selectableFields.count > 0
        else { return nil }

        let actions = selectableFields.map { field in
            UIAction(title: field.visibleName) { [weak self] _ in
                guard let self else { return }
                delegate?.didSelectField(field, from: entry, in: self)
            }
        }
        return UIMenu(title: LString.callToActionSelectField, children: actions)
    }

    @IBAction private func didPressManualSearch(_ sender: Any) {
        activateManualSearch()
    }

    @IBAction private func didPressLockDatabase(_ sender: UIBarButtonItem) {
        Watchdog.shared.restart()
        let confirmationAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let lockDatabaseAction = UIAlertAction(title: LString.actionLockDatabase, style: .destructive) {
            [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressLockDatabase(in: self)
        }
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        confirmationAlert.addAction(lockDatabaseAction)
        confirmationAlert.addAction(cancelAction)
        confirmationAlert.modalPresentationStyle = .popover
        if let popover = confirmationAlert.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(confirmationAlert, animated: true, completion: nil)
    }
}

extension EntryFinderVC: UISearchControllerDelegate {
    func didPresentSearchController(_ searchController: UISearchController) {
        DispatchQueue.main.async {
            searchController.searchBar.becomeFirstResponderWhenSafe()
        }
    }
}

extension EntryFinderVC: UISearchBarDelegate {
    private func acceptFirstEntry(from searchResults: SearchResults) {
        assert(!searchResults.isEmpty)
        guard let firstGroup = searchResults.first,
              let firstEntry = firstGroup.scoredItems.first?.item as? Entry
        else {
            assertionFailure()
            return
        }
        delegate?.didSelectEntry(firstEntry, in: self)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchResults.exactMatch.count > 0 {
            acceptFirstEntry(from: searchResults.exactMatch)
        } else if searchResults.partialMatch.count > 0 {
            acceptFirstEntry(from: searchResults.partialMatch)
        } else {
            HapticFeedback.play(.error)
        }
    }
}

extension EntryFinderVC: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        Watchdog.shared.restart()
        guard let searchText = searchController.searchBar.text else {
            return
        }
        delegate?.didChangeSearchQuery(searchText, in: self)
    }
}


extension LString {
    // swiftlint:disable line_length

    public static let autoFillCallerIDTemplate = NSLocalizedString(
        "[AutoFill/Search/callerID]",
        value: "Caller ID: %@",
        comment: "An identifier of the app that called AutoFill. The term is intentionally similar to https://ru.wikipedia.org/wiki/Caller_ID. [callerID: String]")
    public static let autoFillContextTemplate = NSLocalizedString(
        "[AutoFill/Search/context]",
        value: "Context: %@",
        comment: "Status message, shows which app or webpage launched AutoFill. For example: `Context: google.com`")

    public static let callToActionSelectField = NSLocalizedString(
        "[AutoFill/InsertText/select]",
        value: "Select Field",
        comment: "Call for action to select an entry field for filling out."
    )
    // swiftlint:enable line_length

}
