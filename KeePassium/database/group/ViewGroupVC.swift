//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class GroupViewListCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}

open class ViewGroupVC: UITableViewController, Refreshable {
    
    private enum CellID {
        static let emptyGroup = "EmptyGroupCell"
        static let group = "GroupCell"
        static let entry = "EntryCell"
        static let nothingFound = "NothingFoundCell"
    }
    
    @IBOutlet fileprivate weak var groupIconView: UIImageView!
    @IBOutlet fileprivate weak var groupTitleLabel: UILabel!
    
    weak var group: Group? {
        didSet {
            if let group = group {
                groupTitleLabel.setText(group.name, strikethrough: group.isExpired)
                groupIconView.image = UIImage.kpIcon(forGroup: group)
            } else {
                groupTitleLabel.text = nil
                groupIconView.image = nil
            }
            sortGroupItems()
        }
    }

    var isGroupEmpty: Bool {
        return groupsSorted.isEmpty && entriesSorted.isEmpty
    }
    
    private var groupsSorted = Array<Weak<Group>>()
    private var entriesSorted = Array<Weak<Entry>>()
    private weak var shownEntry: Entry?

    private var isActivateSearch: Bool = false
    private var searchHelper = SearchHelper()
    private var searchResults = [GroupedEntries]()
    private var searchController: UISearchController!
    var isSearchActive: Bool {
        guard let searchController = searchController else { return false }
        return searchController.isActive && (searchController.searchBar.text?.isNotEmpty ?? false)
    }
    
    private var loadingWarnings: DatabaseLoadingWarnings?
    
    private var groupChangeNotifications: GroupChangeNotifications!
    private var entryChangeNotifications: EntryChangeNotifications!
    private var settingsNotifications: SettingsNotifications!

    static func make(group: Group?, loadingWarnings: DatabaseLoadingWarnings?=nil) -> ViewGroupVC {
        let viewGroupVC = ViewGroupVC.instantiateFromStoryboard()
        viewGroupVC.group = group
        viewGroupVC.loadingWarnings = loadingWarnings
        group?.touch(.accessed)
        return viewGroupVC
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        
        tableView.delegate = self
        tableView.dataSource = self
        if !(splitViewController?.isCollapsed ?? true) {
            handleItemSelection(indexPath: nil)
        }

        navigationItem.setRightBarButton(UIBarButtonItem(
            image: UIImage(asset: .createItemToolbar),
            style: .plain, target: self,
            action: #selector(onCreateNewItemAction)), animated: false)
        
        isActivateSearch = Settings.current.isStartWithSearch && (group?.isRoot ?? false)
        
        groupChangeNotifications = GroupChangeNotifications(observer: self)
        entryChangeNotifications = EntryChangeNotifications(observer: self)
        settingsNotifications = SettingsNotifications(observer: self)
        
        let longPressGestureRecognizer = UILongPressGestureRecognizer(
            target: self,
            action: #selector(didLongPressTableView))
        tableView.addGestureRecognizer(longPressGestureRecognizer)
        
        searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        entryChangeNotifications.startObserving()
        groupChangeNotifications.startObserving()
        settingsNotifications.startObserving()
        refresh()
        
        DispatchQueue.main.async { [weak self] in
            self?.setupSearch()
        }
        
        if let warnings = loadingWarnings, !warnings.isEmpty {
            showLoadingWarnings(warnings)
            loadingWarnings = nil 
        }
    }
    
    open override func didMove(toParent parent: UIViewController?) {
        guard let group = group else { return }
        
        if DatabaseManager.shared.isDatabaseOpen {
            if parent == nil && group.isRoot {
                DatabaseManager.shared.closeDatabase(clearStoredKey: false, ignoreErrors: false) {
                    [weak self] (errorMessage) in
                    if let errorMessage = errorMessage {
                        let errorAlert = UIAlertController.make(
                            title: LString.titleError,
                            message: errorMessage,
                            cancelButtonTitle: LString.actionDismiss)
                        self?.navigationController?
                            .present(errorAlert, animated: true, completion: nil)
                    } else {
                        Diag.debug("Database locked on leaving the root group")
                    }
                }
            }
        }
        super.didMove(toParent: parent)
    }

    override open func viewDidDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        groupChangeNotifications.stopObserving()
        entryChangeNotifications.stopObserving()
        
        super.viewDidDisappear(animated)
    }
    
    private func showLoadingWarnings(_ warnings: DatabaseLoadingWarnings) {
        guard !warnings.isEmpty else { return }
        
        let lastUsedAppName = warnings.databaseGenerator ?? ""
        let footerLine = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database/Opened/Warning/lastEdited] Database was last edited by: %@",
                    value: "Database was last edited by: %@",
                    comment: "Status message: name of the app that was last to write/create the database file. [lastUsedAppName: String]"),
                lastUsedAppName)
        let message = warnings.messages.joined(separator: "\n\n") + "\n\n" + footerLine
        
        let alert = UIAlertController(
            title: NSLocalizedString(
                "[Database/Opened/Warning/title] Your database is ready, but there was an issue.",
                value: "Your database is ready, but there was an issue.",
                comment: "Title of a warning message, shown after opening a problematic database"),
            message: message,
            preferredStyle: .alert)
        let continueAction = UIAlertAction(
            title: NSLocalizedString(
                "[Database/Opened/Warning/action] Ignore and Continue",
                value: "Ignore and Continue",
                comment: "Action: ignore warnings and proceed to work with the database"),
            style: .default,
            handler: nil)
        let contactUsAction = UIAlertAction(
            title: LString.actionContactUs,
            style: .default,
            handler: { (action) in
                SupportEmailComposer.show(
                    subject: .problem,
                    completion: { (isSent) in
                        alert.dismiss(animated: false, completion: nil)
                    }
                )
            }
        )
        let lockDatabaseAction = UIAlertAction(
            title: NSLocalizedString(
                "[Database/Opened/Warning/action] Close Database",
                value: "Close Database",
                comment: "Action: lock database"),
            style: .cancel,
            handler: { (action) in
                DatabaseManager.shared.closeDatabase(clearStoredKey: true, ignoreErrors: false) {
                    [weak self] (errorMessage) in
                    if let errorMessage = errorMessage {
                        let errorAlert = UIAlertController.make(
                            title: LString.titleError,
                            message: errorMessage,
                            cancelButtonTitle: LString.actionDismiss)
                        self?.present(errorAlert, animated: true, completion: nil)
                    } else {
                        Diag.debug("Database locked from a loading warning")
                    }
                }
            }
        )
        alert.addAction(continueAction)
        alert.addAction(lockDatabaseAction)
        alert.addAction(contactUsAction)
        present(alert, animated: true, completion: nil)
    }
        
    
    private func setupSearch() {
        guard navigationItem.searchController != nil else {
            assertionFailure()
            return
        }

        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.barStyle = .default
        searchController.dimsBackgroundDuringPresentation = false
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.delegate = self

        definesPresentationContext = true
        searchController.searchResultsUpdater = self

        if isActivateSearch {
            isActivateSearch = false 
            searchController.searchBar.becomeFirstResponder()
        }
    }

    
    func refresh() {
        if isSearchActive {
            updateSearchResults(for: searchController)
        } else {
            sortGroupItems()
        }
        tableView.reloadData()
    }

    private func sortGroupItems() {
        groupsSorted.removeAll()
        entriesSorted.removeAll()
        guard let group = self.group else { return }
        
        let groupSortOrder = Settings.current.groupSortOrder
        let _groupsSorted = group.groups.sorted { return groupSortOrder.compare($0, $1) }
        let _entriesSorted = group.entries.sorted { return groupSortOrder.compare($0, $1) }
        
        for subgroup in _groupsSorted {
            groupsSorted.append(Weak(subgroup))
        }
        for entry in _entriesSorted {
            entriesSorted.append(Weak(entry))
        }
    }
    

    override open func numberOfSections(in tableView: UITableView) -> Int {
        if isSearchActive {
            return searchResults.isEmpty ? 1 : searchResults.count
        } else {
            return 1
        }
    }

    override open func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int) -> String?
    {
        if isSearchActive {
            return searchResults.isEmpty ? nil : searchResults[section].group.name
        } else {
            return nil
        }
    }
    
    override open func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int) -> Int
    {
        if isSearchActive {
            if section < searchResults.count {
                return searchResults[section].entries.count
            } else {
                return (section == 0 ? 1 : 0)
            }
        } else {
            if isGroupEmpty {
                return 1 // for "Nothing here" cell
            } else {
                return groupsSorted.count + entriesSorted.count
            }
        }
    }

    override open func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if isSearchActive {
            return getSearchResultCell(at: indexPath)
        } else {
            return getGroupItemCell(at: indexPath)
        }
    }
    
    private func getSearchResultCell(at indexPath: IndexPath) -> UITableViewCell {
        if isSearchActive && searchResults.isEmpty {
            return tableView.dequeueReusableCell(
                withIdentifier: CellID.nothingFound,
                for: indexPath)
        }

        let entry = searchResults[indexPath.section].entries[indexPath.row].entry
        let entryCell = tableView.dequeueReusableCell(
            withIdentifier: CellID.entry,
            for: indexPath)
            as! GroupViewListCell
        setupCell(
            entryCell,
            title: entry.title,
            subtitle: getDetailInfo(forEntry: entry),
            image: UIImage.kpIcon(forEntry: entry),
            isExpired: entry.isExpired)
        return entryCell
    }
    
    private func getGroupItemCell(at indexPath: IndexPath) -> UITableViewCell {
        if isGroupEmpty {
            return tableView.dequeueReusableCell(withIdentifier: CellID.emptyGroup, for: indexPath)
        }
        
        if indexPath.row < groupsSorted.count {
            guard let group = groupsSorted[indexPath.row].value else {
                assertionFailure()
                return tableView.dequeueReusableCell(withIdentifier: CellID.group, for: indexPath)
            }
            let groupCell = tableView.dequeueReusableCell(
                withIdentifier: CellID.group,
                for: indexPath)
                as! GroupViewListCell
            setupCell(
                groupCell,
                title: group.name,
                subtitle: "\(group.groups.count + group.entries.count)",
                image: UIImage.kpIcon(forGroup: group),
                isExpired: group.isExpired)
            return groupCell
        } else {
            let entryIndex = indexPath.row - groupsSorted.count
            guard let entry = entriesSorted[entryIndex].value else {
                assertionFailure()
                return tableView.dequeueReusableCell(withIdentifier: CellID.entry, for: indexPath)
            }
            
            let entryCell = tableView.dequeueReusableCell(
                withIdentifier: CellID.entry,
                for: indexPath)
                as! GroupViewListCell
            setupCell(
                entryCell,
                title: entry.title,
                subtitle: getDetailInfo(forEntry: entry),
                image: UIImage.kpIcon(forEntry: entry),
                isExpired: entry.isExpired)
            return entryCell
        }
    }
    
    private func setupCell(
        _ cell: GroupViewListCell,
        title: String,
        subtitle: String?,
        image: UIImage?,
        isExpired: Bool)
    {
        cell.titleLabel.setText(title, strikethrough: isExpired)
        cell.subtitleLabel?.setText(subtitle, strikethrough: isExpired)
        cell.iconView?.image = image
    }

    func getDetailInfo(forEntry entry: Entry) -> String? {
        switch Settings.current.entryListDetail {
        case .none:
            return nil
        case .userName:
            return entry.userName
        case .password:
            return entry.password
        case .url:
            return entry.url
        case .notes:
            return entry.notes
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
        case .lastModifiedDate:
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: entry.lastModificationTime)
        }
    }
    
    override open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSearchActive {
            handleItemSelection(indexPath: indexPath)
        } else {
            if !isGroupEmpty {
                handleItemSelection(indexPath: indexPath)
            }
        }
    }
    
    func getGroup(at indexPath: IndexPath) -> Group? {
        if isSearchActive {
            return nil
        } else {
            guard indexPath.row < groupsSorted.count else { return nil }
            return groupsSorted[indexPath.row].value
        }
    }
    
    func getEntry(at indexPath: IndexPath) -> Entry? {
        if isSearchActive {
            guard indexPath.section < searchResults.count else { return  nil }
            let searchResult = searchResults[indexPath.section]
            guard indexPath.row < searchResult.entries.count else { return nil }
            return searchResult.entries[indexPath.row].entry
        } else {
            let entryIndex = indexPath.row - groupsSorted.count
            guard entryIndex >= 0 && entryIndex < entriesSorted.count else { return nil }
            return entriesSorted[entryIndex].value
        }
    }

    func getItem(at indexPath: IndexPath) -> DatabaseItem? {
        if let entry = getEntry(at: indexPath) {
            return entry
        }
        if let group = getGroup(at: indexPath) {
            return group
        }
        return nil
    }
    
    func handleItemSelection(indexPath: IndexPath?) {
        guard let indexPath = indexPath else {
            shownEntry = nil
            let placeholderVC = PlaceholderVC.make()
            showDetailViewController(placeholderVC, sender: self)
            return
        }
        
        if let selectedGroup = getGroup(at: indexPath) {
            
            tableView.deselectRow(at: indexPath, animated: false)
            
            let viewGroupVC = ViewGroupVC.make(group: selectedGroup)
            guard let leftNavController = splitViewController?.viewControllers.first
                as? UINavigationController else
            {
                assertionFailure()
                return
            }
            leftNavController.show(viewGroupVC, sender: self)
        } else if let selectedEntry = getEntry(at: indexPath) {
            if splitViewController?.isCollapsed ?? false {
                tableView.deselectRow(at: indexPath, animated: false)
            }
            shownEntry = selectedEntry
            let viewEntryVC = ViewEntryVC.make(with: selectedEntry)
            showDetailViewController(viewEntryVC, sender: self)
        }
    }
    
    override open func tableView(
        _ tableView: UITableView,
        canEditRowAt indexPath: IndexPath) -> Bool
    {
        return getEntry(at: indexPath) != nil || getGroup(at: indexPath) != nil
    }

    override open func tableView(
        _ tableView: UITableView,
        editActionsForRowAt indexPath: IndexPath
        ) -> [UITableViewRowAction]?
    {
        let editAction = UITableViewRowAction(style: .default, title: LString.actionEdit)
        {
            [unowned self] (_,_) in
            self.setEditing(false, animated: true)
            self.onEditItemAction(at: indexPath)
        }
        editAction.backgroundColor = UIColor.actionTint
        
        let deleteAction = UITableViewRowAction(style: .destructive, title: LString.actionDelete)
        {
            [unowned self] (_,_) in
            self.setEditing(false, animated: true)
            self.onDeleteItemAction(at: indexPath)
        }
        deleteAction.backgroundColor = UIColor.destructiveTint
     
        let menuAction = UITableViewRowAction(style: .default, title: "...")
        {
            [unowned self] (_,_) in
            self.setEditing(false, animated: true)
            self.showActionsForItem(at: indexPath)
        }
        menuAction.backgroundColor = UIColor.lightGray
        
        var allowedActions = [deleteAction]
        if let entry = getEntry(at: indexPath) {
            if !entry.isDeleted { allowedActions.append(editAction) }
        } else if let group = getGroup(at: indexPath) {
            if !group.isDeleted { allowedActions.append(editAction) }
        }
        allowedActions.append(menuAction)
        return allowedActions
    }
    
    
    private func canCreateGroupHere() -> Bool {
        guard let group = group else { return false }
        
        return !group.isDeleted
    }
    
    private func canCreateEntryHere() -> Bool {
        guard let group = group else { return false }
        guard !group.isDeleted else { return false }
        
        if let group1 = group as? Group1 {
            return !group1.isRoot
        }
        return true
    }
    
    private func canMove(_ group: Group) -> Bool {
        guard !group.isRoot else { return false }
        
        if let group1 = group as? Group1,
            let database1 = group1.database as? Database1,
            group1 === database1.getBackupGroup(createIfMissing: false)
        {
            return false
        }
        return true
    }
    
    private func canMove(_ entry: Entry) -> Bool {
        return true
    }


    func showActionsForItem(at indexPath: IndexPath) {
        let actions = getActionsForItem(at: indexPath)
        guard !actions.isEmpty else { return }
        
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actions.forEach {
            menu.addAction($0)
        }
        let pa = PopoverAnchor(tableView: tableView, at: indexPath)
        if let popover = menu.popoverPresentationController {
            pa.apply(to: popover)
        }
        present(menu, animated: true)
    }
    
    func getActionsForItem(at indexPath: IndexPath) -> [UIAlertAction] {
        let editAction = UIAlertAction(
            title: LString.actionEdit,
            style: .default,
            handler: { [weak self] alertAction in
                self?.onEditItemAction(at: indexPath)
            }
        )
        let deleteAction = UIAlertAction(
            title: LString.actionDelete,
            style: .destructive,
            handler: { [weak self] alertAction in
                self?.onDeleteItemAction(at: indexPath)
            }
        )
        let moveAction = UIAlertAction(
            title: LString.actionMove,
            style: .default,
            handler: { [weak self] alertAction in
                self?.onRelocateItemAction(at: indexPath, mode: .move)
            }
        )
        let copyAction = UIAlertAction(
            title: LString.actionCopy,
            style: .default,
            handler: { [weak self] alertAction in
                self?.onRelocateItemAction(at: indexPath, mode: .copy)
            }
        )
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        
        var actions = [UIAlertAction]()
        if let entry = getEntry(at: indexPath) {
            if !entry.isDeleted {
                actions.append(editAction)
            }
            if canMove(entry) {
                actions.append(moveAction)
                actions.append(copyAction)
            }
            actions.append(deleteAction)
            actions.append(cancelAction)
        }
        if let group = getGroup(at: indexPath) {
            if !group.isDeleted {
                actions.append(editAction)
            }
            if canMove(group) {
                actions.append(moveAction)
                actions.append(copyAction)
            }
            actions.append(deleteAction)
            actions.append(cancelAction)
        }
        return actions
    }
    
    @objc func onCreateNewItemAction(sender: UIBarButtonItem) {
        let addItemSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let createGroupAction = UIAlertAction(title: LString.actionCreateGroup, style: .default)
        {
            [weak self] _ in
            self?.onCreateGroupAction()
        }
        createGroupAction.isEnabled = canCreateGroupHere()
        
        let createEntryAction = UIAlertAction(title: LString.actionCreateEntry, style: .default)
        {
            [weak self] _ in
            self?.onCreateEntryAction()
        }
        createEntryAction.isEnabled = canCreateEntryHere()
        
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        
        addItemSheet.addAction(createGroupAction)
        addItemSheet.addAction(createEntryAction)
        addItemSheet.addAction(cancelAction)

        addItemSheet.modalPresentationStyle = .popover
        if let popover = addItemSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
        present(addItemSheet, animated: true, completion: nil)
    }

    func onCreateGroupAction() {
        Diag.info("Will create group")
        guard let parentGroup = self.group else { return }
        let editGroupVC = EditGroupVC.make(
            mode: .create,
            group: parentGroup,
            popoverSource: nil,
            delegate: nil)
        present(editGroupVC, animated: true, completion: nil)
    }

    func onCreateEntryAction() {
        Diag.info("Will create entry")
        guard let group = group else { return }
        let editEntryVC = EditEntryVC.make(
            createInGroup: group,
            popoverSource: nil,
            delegate: self)
        present(editEntryVC, animated: true, completion: nil)
    }
    
    func onEditItemAction(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        
        if let selectedGroup = getGroup(at: indexPath) {
            let editGroupVC = EditGroupVC.make(
                mode: .edit,
                group: selectedGroup,
                popoverSource: cell,
                delegate: nil)
            present(editGroupVC, animated: true, completion: nil)
            return
        }
        
        if let selectedEntry = getEntry(at: indexPath) {
            let editEntryVC = EditEntryVC.make(
                entry: selectedEntry,
                popoverSource: cell,
                delegate: nil)
            present(editEntryVC, animated: true, completion: nil)
            return
        }
    }
    
    func onDeleteItemAction(at indexPath: IndexPath) {
        let confirmationAlert = UIAlertController(title: "", message: nil, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        confirmationAlert.addAction(cancelAction)

        if let targetGroup = getGroup(at: indexPath) {
            confirmationAlert.title = targetGroup.name
            let deleteAction = UIAlertAction(title: LString.actionDelete, style: .destructive)
            {
                [weak self] _ in
                guard let database = targetGroup.database else { return }
                database.delete(group: targetGroup)
                targetGroup.touch(.accessed)
                self?.saveDatabase()
            }
            confirmationAlert.addAction(deleteAction)
            present(confirmationAlert, animated: true, completion: nil)
            return
        }
        
        if let targetEntry = getEntry(at: indexPath) {
            let isDeletingShownEntry = (targetEntry === shownEntry)
            confirmationAlert.title = targetEntry.title
            let deleteAction = UIAlertAction(title: LString.actionDelete, style: .destructive)
            {
                [weak self] _ in
                guard let database = targetEntry.database else { return }
                database.delete(entry: targetEntry)
                targetEntry.touch(.accessed)
                if isDeletingShownEntry && !(self?.splitViewController?.isCollapsed ?? true) {
                    self?.handleItemSelection(indexPath: nil) 
                }
                self?.saveDatabase()
            }
            confirmationAlert.addAction(deleteAction)
            present(confirmationAlert, animated: true, completion: nil)
            return
        }
    }
    

    var itemRelocationCoordinator: ItemRelocationCoordinator?
    
    func onRelocateItemAction(at indexPath: IndexPath, mode: ItemRelocationMode) {
        guard let database = group?.database else { return }
        
        assert(itemRelocationCoordinator == nil)
        itemRelocationCoordinator = ItemRelocationCoordinator(
            database: database,
            mode: mode,
            parentViewController: self)
        itemRelocationCoordinator?.delegate = self
        
        if let selectedItem = getItem(at: indexPath) {
            itemRelocationCoordinator?.itemsToRelocate = [Weak(selectedItem)]
        } else {
            assertionFailure()
        }
        itemRelocationCoordinator?.start()
    }

    @IBAction func didPressItemListSettings(_ sender: Any) {
        let itemListSettingsVC = SettingsItemListVC.make(
            barPopoverSource: sender as? UIBarButtonItem)
        present(itemListSettingsVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressSettings(_ sender: Any) {
        let settingsVC = SettingsVC.make(popoverFromBar: sender as? UIBarButtonItem)
        present(settingsVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressLockDatabase(_ sender: UIBarButtonItem) {
        let confirmationAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let lockDatabaseAction = UIAlertAction(title: LString.actionLockDatabase, style: .destructive) {
            (action) in
            DatabaseManager.shared.closeDatabase(clearStoredKey: true, ignoreErrors: false) {
                [weak self] (errorMessage) in
                if let errorMessage = errorMessage {
                    let errorAlert = UIAlertController.make(
                        title: LString.titleError,
                        message: errorMessage,
                        cancelButtonTitle: LString.actionDismiss)
                    self?.present(errorAlert, animated: true, completion: nil)
                } else {
                    Diag.debug("Database locked on user request")
                }
            }
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
    
    @IBAction func didPressChangeDatabaseSettings(_ sender: Any) {
        guard let dbRef = DatabaseManager.shared.databaseRef else {
            assertionFailure("databaseRef should not be nil here")
            return
        }
        let vc = ChangeMasterKeyVC.make(dbRef: dbRef)
        present(vc, animated: true, completion: nil)
    }
    
    @objc func didLongPressTableView(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point = gestureRecognizer.location(in: tableView)
        guard gestureRecognizer.state == .began,
            let indexPath = tableView.indexPathForRow(at: point),
            tableView(tableView, canEditRowAt: indexPath),
            let _ = tableView.cellForRow(at: indexPath) else { return }
        showActionsForItem(at: indexPath)
    }
    
    
    func saveDatabase() {
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
    
    private var savingOverlay: ProgressOverlay?
    
    private func showSavingOverlay() {
        guard let splitVC = splitViewController else { fatalError() }
        savingOverlay = ProgressOverlay.addTo(
            splitVC.view,
            title: LString.databaseStatusSaving,
            animated: true)
        savingOverlay?.isCancellable = false
    }
    
    private func hideSavingOverlay() {
        savingOverlay?.dismiss(animated: true) {
            [weak self] finished in
            guard let _self = self else { return }
            _self.savingOverlay?.removeFromSuperview()
            _self.savingOverlay = nil
        }
    }
}

extension ViewGroupVC: DatabaseManagerObserver {
    
    public func databaseManager(willSaveDatabase urlRef: URLReference) {
        showSavingOverlay()
    }
    
    public func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideSavingOverlay()
    }
    
    public func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideSavingOverlay()
    }

    public func databaseManager(progressDidChange progress: ProgressEx) {
        savingOverlay?.update(with: progress)
    }

    public func databaseManager(
        database urlRef: URLReference,
        savingError message: String,
        reason: String?)
    {
        DatabaseManager.shared.removeObserver(self)
        refresh()
        hideSavingOverlay()

        let errorAlert = UIAlertController(title: message, message: reason, preferredStyle: .alert)
        let showDetailsAction = UIAlertAction(title: LString.actionShowDetails, style: .default)
        {
            [weak self] _ in
            self?.present(ViewDiagnosticsVC.make(), animated: true, completion: nil)
        }
        let dismissAction = UIAlertAction(title: LString.actionDismiss, style: .cancel)
        {
            [weak self] _ in
            self?.refresh()
        }
        errorAlert.addAction(showDetailsAction)
        errorAlert.addAction(dismissAction)
        present(errorAlert, animated: true, completion: nil)
    }
}

extension ViewGroupVC: SettingsObserver {
    public func settingsDidChange(key: Settings.Keys) {
        if key == .entryListDetail || key == .groupSortOrder {
            refresh()
        }
    }
}

extension ViewGroupVC: EditEntryFieldsDelegate {
    func entryEditor(entryDidChange entry: Entry) {
        refresh()
        
        guard let splitVC = splitViewController else { fatalError() }
        
        if !splitVC.isCollapsed,
            let entryIndex = entriesSorted.index(where: { $0.value === entry })
        {
            let indexPath = IndexPath(row: groupsSorted.count + entryIndex, section: 0)
            handleItemSelection(indexPath: indexPath)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none) 
        }
    }
}

extension ViewGroupVC: EntryChangeObserver {
    func entryDidChange(entry: Entry) {
        refresh()
    }
}

extension ViewGroupVC: GroupChangeObserver {
    func groupDidChange(group: Group) {
        refresh()
    }
}


extension ViewGroupVC: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        guard let database = group?.database else { return }
        searchResults = searchHelper.find(database: database, searchText: searchText)
        sortSearchResults()
        tableView.reloadData()
    }
    
    private func sortSearchResults() {
        let groupSortOrder = Settings.current.groupSortOrder
        searchResults.sort { return groupSortOrder.compare($0.group, $1.group) }
    }
}

extension ViewGroupVC: UISearchControllerDelegate {
    public func didDismissSearchController(_ searchController: UISearchController) {
        refresh()
    }
}

extension ViewGroupVC: ItemRelocationCoordinatorDelegate {
    func didFinish(_ coordinator: ItemRelocationCoordinator) {
        assert(itemRelocationCoordinator != nil)
        itemRelocationCoordinator = nil
    }
}
