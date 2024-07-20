//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol GroupViewerDelegate: AnyObject {
    func didPressLockDatabase(in viewController: GroupViewerVC)
    func didPressChangeMasterKey(in viewController: GroupViewerVC)
    func didPressPrintDatabase(in viewController: GroupViewerVC)
    func didPressReloadDatabase(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC)
    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC)
    func didPressPasswordAudit(in viewController: GroupViewerVC)
    func didPressFaviconsDownload(in viewController: GroupViewerVC)
    func didPressPasswordGenerator(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC)
    func didPressEncryptionSettings(in viewController: GroupViewerVC)

    func didSelectGroup(_ group: Group?, in viewController: GroupViewerVC) -> Bool

    func didSelectEntry(_ entry: Entry?, in viewController: GroupViewerVC) -> Bool

    func didPressCreateGroup(
        smart: Bool,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )
    func didPressCreateEntry(
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )

    func didPressEditGroup(
        _ group: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )
    func didPressEditEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )

    func didPressDeleteGroup(
        _ group: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )

    func didPressDeleteItems(
        _ items: [DatabaseItem],
        in viewController: GroupViewerVC
    )

    func didPressDeleteEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )

    func didPressRelocateItems(
        _ items: [DatabaseItem],
        mode: ItemRelocationMode,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )

    func didReorderItems(in group: Group, groups: [Group], entries: [Entry])

    func didPressEmptyRecycleBinGroup(
        _ recycleBinGroup: Group,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )

    func getActionPermissions(for group: Group) -> DatabaseItem.ActionPermissions
    func getActionPermissions(for entry: Entry) -> DatabaseItem.ActionPermissions
}

final class GroupViewerVC:
    TableViewControllerWithContextActions,
    Refreshable
{
    private enum CellID {
        static let announcement = "AnnouncementCell"
        static let emptyGroup = "EmptyGroupCell"
        static let group = "GroupCell"
        static let entry = "EntryCell"
        static let nothingFound = "NothingFoundCell"
    }

    enum Section: Int, CaseIterable {
        case announcements
        case groups
        case entries

        var title: String? {
            switch self {
            case .announcements:
                return nil
            case .groups:
                return "Groups"
            case .entries:
                return "Entries"
            }
        }
    }

    weak var delegate: GroupViewerDelegate?

    @IBOutlet private weak var sortOrderButton: UIBarButtonItem!
    @IBOutlet private weak var databaseMenuButton: UIBarButtonItem!
    @IBOutlet private weak var reloadDatabaseButton: UIBarButtonItem!
    @IBOutlet private weak var passwordGeneratorButton: UIBarButtonItem!

    weak var group: Group? {
        didSet {
            refresh()
        }
    }

    var isGroupEmpty: Bool {
        return groupsSorted.isEmpty && entriesSorted.isEmpty
    }
    var isSmartGroup: Bool {
        return group?.isSmartGroup ?? false
    }
    var supportsSmartGroups: Bool {
        return group is Group2
    }

    var canDownloadFavicons: Bool = true
    var canChangeEncryptionSettings: Bool = true

    private var titleView = DatabaseItemTitleView()

    private var groupsSorted = [Weak<Group>]()
    private var entriesSorted = [Weak<Entry>]()

    private var groupActionsButton: UIBarButtonItem!

    private lazy var doneSelectReorderButton = UIBarButtonItem(
        barButtonSystemItem: .done,
        target: self,
        action: #selector(didPressDoneSelectReorder)
    )

    private var actionPermissions = DatabaseItem.ActionPermissions()

    internal var announcements = [AnnouncementItem]() {
        didSet {
            guard isViewLoaded else { return }
            tableView.reloadSections([0], with: .automatic)
        }
    }

    private var isActivateSearch: Bool = false
    private var searchHelper = SearchHelper()
    private var searchResults = [GroupedItems]()
    private var searchController: UISearchController?
    var isSearchActive: Bool {
        if isSmartGroup {
            return true
        }
        guard let searchController = searchController else { return false }
        return searchController.isActive && (searchController.searchBar.text?.isNotEmpty ?? false)
    }

    override var canDismissFromKeyboard: Bool {
        return !(searchController?.isActive ?? false)
    }

    private var cellRefreshTimer: Timer?
    private var settingsNotifications: SettingsNotifications!

    private lazy var bulkDeleteButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            barButtonSystemItem: .trash,
            target: self,
            action: #selector(didPressBulkDelete))
        button.title = LString.actionDelete
        return button
    }()

    private lazy var bulkRelocateButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: .symbol(.folder),
            style: .plain,
            target: self,
            action: #selector(didPressBulkRelocate))
        button.title = LString.actionMove
        return button
    }()

    private var defaultToolbarItems: [UIBarButtonItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        tableView.register(AnnouncementCell.classForCoder(), forCellReuseIdentifier: CellID.announcement)
        tableView.selectionFollowsFocus = true

        groupActionsButton = UIBarButtonItem()
        navigationItem.rightBarButtonItem = groupActionsButton

        navigationItem.titleView = titleView
        reloadDatabaseButton.title = LString.actionReloadDatabase
        passwordGeneratorButton.title = LString.PasswordGenerator.titleRandomGenerator

        settingsNotifications = SettingsNotifications(observer: self)

        let isRootGroup = group?.isRoot ?? false
        isActivateSearch = Settings.current.isStartWithSearch && isRootGroup
        setupSearch()
        if isRootGroup {
            navigationItem.hidesSearchBarWhenScrolling = false
        }

        defaultToolbarItems = toolbarItems ?? []
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        cellRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshDynamicCells()
        }
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        settingsNotifications.startObserving()

        navigationItem.hidesSearchBarWhenScrolling = true
        if isActivateSearch {
            isActivateSearch = false 
            DispatchQueue.main.async { [weak searchController] in
                searchController?.searchBar.becomeFirstResponder()
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        settingsNotifications.stopObserving()
        cellRefreshTimer?.invalidate()
        cellRefreshTimer = nil
    }

    private func setupSearch() {
        if let group = group, group.isSmartGroup {
            updateSearchResults(searchText: group.smartGroupQuery)
            return
        }

        searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController

        searchController?.searchBar.searchBarStyle = .default
        searchController?.searchBar.returnKeyType = .search
        searchController?.searchBar.barStyle = .default
        searchController?.obscuresBackgroundDuringPresentation = false
        searchController?.hidesNavigationBarDuringPresentation = true
        searchController?.delegate = self

        definesPresentationContext = true
        searchController?.searchResultsUpdater = self
    }

    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(
                action: #selector(activateSearch),
                input: "f",
                modifierFlags: [.command],
                discoverabilityTitle: LString.titleSearch
            )
        ]
    }

    @objc func activateSearch() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.searchController?.isActive = true
            self.searchController?.searchBar.becomeFirstResponderWhenSafe()
        }
    }

    func refresh() {
        guard isViewLoaded, let group = group else { return }

        titleView.titleLabel.setText(group.name, strikethrough: group.isExpired)
        titleView.iconView.image = UIImage.kpIcon(forGroup: group)
        navigationItem.title = titleView.titleLabel.text

        if isSearchActive, let searchController = searchController {
            updateSearchResults(for: searchController)
        } else {
            sortGroupItems()
        }
        tableView.reloadData()

        actionPermissions = delegate?.getActionPermissions(for: group) ?? DatabaseItem.ActionPermissions()
        updateGroupActionsMenuButton()
        configureDatabaseMenuButton(databaseMenuButton)

        sortOrderButton.menu = makeListSettingsMenu()
        sortOrderButton.image = .symbol(.listBullet)
    }

    private func refreshDynamicCells() {
        tableView.visibleCells.forEach {
            if let entryCell = $0 as? GroupViewerEntryCell {
                entryCell.refresh()
            }
        }
    }

    private func sortGroupItems() {
        groupsSorted.removeAll()
        entriesSorted.removeAll()
        guard let group = self.group else { return }

        let groupSortOrder = Settings.current.groupSortOrder
        let weakGroupsSorted = group.groups
            .sorted { groupSortOrder.compare($0, $1) }
            .map { Weak($0) }
        let weakEntriesSorted = group.entries
            .sorted { groupSortOrder.compare($0, $1) }
            .map { Weak($0) }

        groupsSorted.append(contentsOf: weakGroupsSorted)
        entriesSorted.append(contentsOf: weakEntriesSorted)
    }

    private func configureDatabaseMenuButton(_ barButton: UIBarButtonItem) {
        barButton.title = LString.titleDatabaseOperations
        let lockDatabaseAction = UIAction(
            title: LString.actionLockDatabase,
            image: .symbol(.lock),
            attributes: [.destructive],
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressLockDatabase(in: self)
            }
        )
        let printDatabaseAction = UIAction(
            title: LString.actionPrint,
            image: .symbol(.printer),
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressPrintDatabase(in: self)
            }
        )
        let changeMasterKeyAction = UIAction(
            title: LString.actionChangeMasterKey,
            image: .symbol(.key),
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressChangeMasterKey(in: self)
            }
        )
        let passwordAuditAction = UIAction(
            title: LString.titlePasswordAudit,
            image: .symbol(.networkBadgeShield),
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressPasswordAudit(in: self)
            }
        )
        let faviconsDownloadAction = UIAction(
            title: LString.actionDownloadFavicons,
            image: .symbol(.wandAndStars),
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressFaviconsDownload(in: self)
            }
        )

        let encryptionSettingsAction = UIAction(
            title: LString.titleEncryptionSettings,
            image: .symbol(.lockShield),
            handler: { [weak self] _ in
                guard let self else { return }
                self.delegate?.didPressEncryptionSettings(in: self)
            }
        )

        if !actionPermissions.canEditDatabase {
            changeMasterKeyAction.attributes.insert(.disabled)
            faviconsDownloadAction.attributes.insert(.disabled)
            encryptionSettingsAction.attributes.insert(.disabled)
        }

        let frequentMenu = UIMenu(
            options: [.displayInline],
            children: [
                passwordAuditAction,
                canDownloadFavicons ? faviconsDownloadAction : nil,
                printDatabaseAction,
            ].compactMap { $0 }
        )
        let rareMenu = UIMenu(
            options: [.displayInline],
            children: [
                changeMasterKeyAction,
                canChangeEncryptionSettings ? encryptionSettingsAction : nil,
            ].compactMap { $0 }
        )
        let lockMenu = UIMenu(options: [.displayInline], children: [lockDatabaseAction])

        var menuElements = [frequentMenu, rareMenu, lockMenu]
        if #available(iOS 16, *) {
            barButton.preferredMenuElementOrder = .fixed
        } else {
            menuElements.reverse()
        }
        let menu = UIMenu(children: menuElements)
        barButton.menu = menu
    }


    override func numberOfSections(in tableView: UITableView) -> Int {
        if isSearchActive {
            return searchResults.isEmpty ? 1 : searchResults.count
        } else {
            return Section.allCases.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        if isSearchActive {
            return searchResults.isEmpty ? nil : searchResults[section].group.name
        } else if tableView.isEditing {
            return Section(rawValue: section)?.title
        } else {
            return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        if isSearchActive {
            if section < searchResults.count {
                return searchResults[section].scoredItems.count
            } else {
                return (section == 0 ? 1 : 0)
            }
        } else {
            switch Section(rawValue: section) {
            case .announcements:
                return announcements.count
            case .groups:
                return isGroupEmpty ? 1 : groupsSorted.count
            case .entries:
                return entriesSorted.count
            default:
                fatalError("Invalid section")
            }
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        if isSearchActive {
            return makeSearchResultCell(at: indexPath)
        } else {
            switch Section(rawValue: indexPath.section) {
            case .announcements:
                return makeAnnouncementCell(at: indexPath)
            case .groups where isGroupEmpty:
                return tableView.dequeueReusableCell(withIdentifier: CellID.emptyGroup, for: indexPath)
            case .groups:
                guard let group = groupsSorted[indexPath.row].value else {
                    fatalError()
                }
                return getGroupCell(for: group, at: indexPath)
            case .entries:
                guard let entry = entriesSorted[indexPath.row].value else {
                    fatalError()
                }
                return getEntryCell(for: entry, at: indexPath)
            default:
                fatalError("Invalid section")
            }
        }
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if isSearchActive {
            return true
        } else {
            switch Section(rawValue: indexPath.section) {
            case .announcements:
                return false
            default:
                return true
            }
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

    private func makeSearchResultCell(at indexPath: IndexPath) -> UITableViewCell {
        if isSearchActive && searchResults.isEmpty {
            return tableView.dequeueReusableCell(
                withIdentifier: CellID.nothingFound,
                for: indexPath)
        }

        let section = searchResults[indexPath.section]
        let foundItem = section.scoredItems[indexPath.row].item
        switch foundItem {
        case let entry as Entry:
            return getEntryCell(for: entry, at: indexPath)
        case let group as Group:
            return getGroupCell(for: group, at: indexPath)
        default:
            fatalError("Invalid usage")
        }
    }

    private func getGroupCell(for group: Group, at indexPath: IndexPath) -> GroupViewerGroupCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.group,
            for: indexPath)
            as! GroupViewerGroupCell

        cell.iconView?.image = UIImage.kpIcon(forGroup: group)
        cell.titleLabel.setText(group.name, strikethrough: group.isExpired)
        cell.isSmartGroup = group.isSmartGroup
        if group.isSmartGroup {
            cell.subtitleLabel.text = ""
            cell.accessibilityLabel = String.localizedStringWithFormat(
                LString.titleSmartGroupDescriptionTemplate,
                group.name)
        } else {
            let itemCount = group.groups.count + group.entries.count
            cell.subtitleLabel?.setText("\(itemCount)", strikethrough: group.isExpired)
            cell.accessibilityLabel = String.localizedStringWithFormat(
                LString.titleGroupDescriptionTemplate,
                group.name)
        }
        return cell
    }

    private func getEntryCell(for entry: Entry, at indexPath: IndexPath) -> GroupViewerEntryCell {
        let entryCell = tableView.dequeueReusableCell(
            withIdentifier: CellID.entry,
            for: indexPath)
            as! GroupViewerEntryCell

        setupEntryCell(entryCell, entry: entry)
        return entryCell
    }

    private func setupEntryCell(_ cell: GroupViewerEntryCell, entry: Entry) {
        cell.titleLabel.setText(entry.resolvedTitle, strikethrough: entry.isExpired)
        cell.subtitleLabel?.setText(getDetailInfo(for: entry), strikethrough: entry.isExpired)
        cell.iconView?.image = UIImage.kpIcon(forEntry: entry)

        cell.totpGenerator = TOTPGeneratorFactory.makeGenerator(for: entry)
        cell.otpCopiedHandler = { [weak self] in
            self?.showNotification(LString.otpCodeCopiedToClipboard)
        }

        cell.hasAttachments = entry.attachments.count > 0
        cell.accessibilityCustomActions = getAccessibilityActions(for: entry)
    }

    private func getDetailInfo(for entry: Entry) -> String? {
        switch Settings.current.entryListDetail {
        case .none:
            return nil
        case .userName:
            return entry.getField(EntryField.userName)?.premiumDecoratedValue
        case .password:
            return entry.getField(EntryField.password)?.premiumDecoratedValue
        case .url:
            return entry.getField(EntryField.url)?.premiumDecoratedValue
        case .notes:
            return entry.getField(EntryField.notes)?
                .premiumDecoratedValue
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
        case .lastModifiedDate:
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: entry.lastModificationTime)
        case .tags:
            guard let entry2 = entry as? Entry2 else {
                return nil
            }
            return entry2.resolvingTags().joined(separator: ", ")
        }
    }


    @available(iOS 13, *)
    private func getAccessibilityActions(for entry: Entry) -> [UIAccessibilityCustomAction] {
        var actions = [UIAccessibilityCustomAction]()

        let nonTitleFields = entry.fields.filter { $0.name != EntryField.title }
        nonTitleFields.reversed().forEach { field in
            let actionName = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                field.name)
            let action = UIAccessibilityCustomAction(name: actionName) { [weak field] _ -> Bool in
                if let fieldValue = field?.resolvedValue {
                    Clipboard.general.insert(fieldValue)
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: LString.titleCopiedToClipboard
                    )
                }
                return true
            }
            actions.append(action)
        }
        return actions
    }


    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateBulkSelectionActions()
            return
        }

        if isSearchActive {
            didSelectItem(at: indexPath)
        } else {
            if !isGroupEmpty {
                didSelectItem(at: indexPath)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateBulkSelectionActions()
        }
    }

    private func getIndexPath(for group: Group) -> IndexPath? {
        guard let groupIndex = groupsSorted.firstIndex(where: { $0.value === group }) else {
            return nil
        }
        let indexPath = IndexPath(row: groupIndex, section: Section.groups.rawValue)
        return indexPath
    }

    private func getIndexPath(for entry: Entry) -> IndexPath? {
        guard let entryIndex = entriesSorted.firstIndex(where: { $0.value === entry }) else {
            return nil
        }
        let indexPath = IndexPath(row: entryIndex, section: Section.entries.rawValue)
        return indexPath
    }

    func selectEntry(_ entry: Entry?, animated: Bool) {
        guard let entry = entry else {
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                tableView.deselectRow(at: selectedIndexPath, animated: animated)
            }
            return
        }
        guard let indexPath = getIndexPath(for: entry) else {
            return
        }
        tableView.selectRow(at: indexPath, animated: animated, scrollPosition: .none)
        tableView.scrollToRow(at: indexPath, at: .none, animated: animated)
    }

    func getGroup(at indexPath: IndexPath) -> Group? {
        guard !indexPath.isEmpty else { return nil }
        if isSearchActive {
            return getSearchResult(at: indexPath) as? Group
        } else {
            switch Section(rawValue: indexPath.section) {
            case .groups:
                if groupsSorted.indices.contains(indexPath.row) {
                    return groupsSorted[indexPath.row].value
                }
                return nil
            default:
                return nil
            }
        }
    }

    func getEntry(at indexPath: IndexPath) -> Entry? {
        guard !indexPath.isEmpty else { return nil }
        if isSearchActive {
            return getSearchResult(at: indexPath) as? Entry
        } else {
            switch Section(rawValue: indexPath.section) {
            case .entries:
                if entriesSorted.indices.contains(indexPath.row) {
                    return entriesSorted[indexPath.row].value
                }
                return nil
            default:
                return nil
            }
        }
    }

    private func getSearchResult(at indexPath: IndexPath) -> DatabaseItem? {
        guard indexPath.section < searchResults.count else { return nil }
        let searchResult = searchResults[indexPath.section]
        guard indexPath.row < searchResult.scoredItems.count else { return nil }
        return searchResult.scoredItems[indexPath.row].item
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

    func didSelectItem(at indexPath: IndexPath) {
        var shouldKeepSelection = true
        if let selectedGroup = getGroup(at: indexPath) {
            shouldKeepSelection = delegate?.didSelectGroup(selectedGroup, in: self) ?? true
        } else if let selectedEntry = getEntry(at: indexPath) {
            shouldKeepSelection = delegate?.didSelectEntry(selectedEntry, in: self) ?? true
        }

        if !shouldKeepSelection {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }


    private func makeListSettingsMenu() -> UIMenu {
        let currentDetail = Settings.current.entryListDetail
        let entrySubtitleActions = Settings.EntryListDetail.allCases.map { entryListDetail in
            UIAction(
                title: entryListDetail.longTitle,
                state: (currentDetail == entryListDetail) ? .on : .off,
                handler: { [weak self] _ in
                    Settings.current.entryListDetail = entryListDetail
                    self?.refresh()
                }
            )
        }
        let entrySubtitleMenu = UIMenu.make(
            title: LString.titleEntrySubtitle,
            reverse: true,
            options: [],
            children: entrySubtitleActions
        )

        let sortOrderMenuItems = UIMenu.makeDatabaseItemSortMenuItems(
            current: Settings.current.groupSortOrder,
            handler: { [weak self] newSortOrder in
                Settings.current.groupSortOrder = newSortOrder
                self?.refresh()
            }
        )
        let sortOrderMenu = UIMenu.make(
            title: LString.titleSortBy,
            reverse: true,
            options: [],
            macOptions: [],
            children: sortOrderMenuItems
        )
        return UIMenu.make(
            title: "",
            reverse: true,
            options: [],
            children: [sortOrderMenu, entrySubtitleMenu]
        )
    }

    override func getContextActionsForRow(
        at indexPath: IndexPath,
        forSwipe: Bool
    ) -> [ContextualAction] {
        var isNonEmptyRecycleBinGroup = false
        let permissions: DatabaseItem.ActionPermissions
        if let group = getGroup(at: indexPath) {
            permissions = delegate?.getActionPermissions(for: group) ?? DatabaseItem.ActionPermissions()
            let isRecycleBin = (group === group.database?.getBackupGroup(createIfMissing: false))
            isNonEmptyRecycleBinGroup = isRecycleBin && (!group.entries.isEmpty || !group.groups.isEmpty)
        } else if let entry = getEntry(at: indexPath) {
            permissions = delegate?.getActionPermissions(for: entry) ?? DatabaseItem.ActionPermissions()
        } else {
            return []
        }

        let editAction = ContextualAction(
            title: LString.actionEdit,
            imageName: .squareAndPencil,
            style: .default,
            color: UIColor.actionTint,
            handler: { [weak self, indexPath] in
                self?.didPressEditItem(at: indexPath)
            }
        )
        let deleteAction = ContextualAction(
            title: LString.actionDelete,
            imageName: .trash,
            style: .destructive,
            color: UIColor.destructiveTint,
            handler: { [weak self, indexPath] in
                self?.didPressDeleteItem(at: indexPath)
            }
        )
        let emptyRecycleBinAction = ContextualAction(
            title: LString.actionEmptyRecycleBinGroup,
            imageName: .trash,
            style: .destructive,
            color: UIColor.destructiveTint,
            handler: { [weak self, indexPath] in
                self?.didPressEmptyRecycleBinGroup(at: indexPath)
            }
        )

        var actions = [ContextualAction]()

        if forSwipe {
            if permissions.canDeleteItem {
                actions.append(deleteAction)
            }
            if permissions.canEditItem {
                actions.append(editAction)
            }
            return actions
        }

        if permissions.canEditItem {
            actions.append(editAction)
        }
        if permissions.canMoveItem {
            let moveAction = ContextualAction(
                title: LString.actionMove,
                imageName: .folder,
                style: .default,
                handler: { [weak self, indexPath] in
                    self?.didPressRelocateItem(at: indexPath, mode: .move)
                }
            )
            let copyAction = ContextualAction(
                title: LString.actionCopy,
                imageName: .docOnDoc,
                style: .default,
                handler: { [weak self, indexPath] in
                    self?.didPressRelocateItem(at: indexPath, mode: .copy)
                }
            )
            actions.append(moveAction)
            actions.append(copyAction)
        }
        if permissions.canDeleteItem {
            actions.append(deleteAction)
            if isNonEmptyRecycleBinGroup {
                actions.append(emptyRecycleBinAction)
            }
        }
        return actions
    }


    private func updateGroupActionsMenuButton() {
        let button = groupActionsButton!
        button.title = LString.titleGroupMenu
        button.image = .symbol(.ellipsisCircle)

        let popoverAnchor = PopoverAnchor(barButtonItem: button)
        let createGroupAction = UIAction(
            title: LString.actionCreateGroup,
            image: .symbol(.folderBadgePlus),
            attributes: actionPermissions.canCreateGroup ? [] : [.disabled],
            handler: { [weak self, popoverAnchor] _ in
                guard let self else { return }
                delegate?.didPressCreateGroup(smart: false, at: popoverAnchor, in: self)
            }
        )

        let createSmartGroupAction = UIAction(
            title: LString.actionCreateSmartGroup,
            image: .symbol(.folderGridBadgePlus),
            attributes: actionPermissions.canCreateGroup ? [] : [.disabled],
            handler: { [weak self, popoverAnchor] _ in
                guard let self = self else { return }
                delegate?.didPressCreateGroup(smart: true, at: popoverAnchor, in: self)
            }
        )

        let createEntryAction = UIAction(
            title: LString.actionCreateEntry,
            image: .symbol(.docBadgePlus),
            attributes: actionPermissions.canCreateEntry ? [] : [.disabled],
            handler: { [weak self, popoverAnchor] _ in
                guard let self else { return }
                delegate?.didPressCreateEntry(at: popoverAnchor, in: self)
            }
        )

        let editGroupAction = UIAction(
            title: LString.titleEditGroup,
            image: .symbol(.squareAndPencil),
            attributes: actionPermissions.canEditItem ? [] : [.disabled],
            handler: { [weak self, popoverAnchor] _ in
                guard let self,
                      let group = self.group
                else { return }
                delegate?.didPressEditGroup(group, at: popoverAnchor, in: self)
            }
        )

        let selectItemsAction = UIAction(
            title: LString.actionSelect,
            image: .symbol(.checkmarkCircle),
            handler: { [weak self] _ in
                self?.startSelectionMode(animated: true)
            }
        )
        let reorderItemsAction = UIAction(
            title: LString.actionReorderItems,
            image: .symbol(.arrowUpArrowDown),
            handler: { [weak self] _ in
                self?.startSelectionMode(animated: true)
            }
        )

        if isSmartGroup {
            createGroupAction.attributes.insert(.disabled)
            createSmartGroupAction.attributes.insert(.disabled)
            createEntryAction.attributes.insert(.disabled)
            selectItemsAction.attributes.insert(.disabled)
            reorderItemsAction.attributes.insert(.disabled)
        }
        if !actionPermissions.canEditDatabase || !actionPermissions.canEditItem || isGroupEmpty {
            reorderItemsAction.attributes.insert(.disabled)
            selectItemsAction.attributes.insert(.disabled)
        }
        if Settings.current.groupSortOrder != .noSorting {
            reorderItemsAction.attributes.insert(.disabled)
        }

        button.menu = UIMenu.make(
            title: "",
            reverse: false,
            options: [],
            children: [
                createEntryAction,
                createGroupAction,
                supportsSmartGroups ? createSmartGroupAction : nil,
                UIMenu(options: .displayInline, children: [selectItemsAction, reorderItemsAction]),
                UIMenu(options: .displayInline, children: [editGroupAction]),
            ].compactMap({ $0 })
        )
    }

    func didPressEditItem(at indexPath: IndexPath) {
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        if let targetGroup = getGroup(at: indexPath) {
            delegate?.didPressEditGroup(targetGroup, at: popoverAnchor, in: self)
        } else if let targetEntry = getEntry(at: indexPath) {
            delegate?.didPressEditEntry(targetEntry, at: popoverAnchor, in: self)
        } else {
            assertionFailure("Unknown database item type")
        }
    }

    func didPressDeleteItem(at indexPath: IndexPath) {
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)

        let confirmationAlert = UIAlertController(title: "", message: nil, preferredStyle: .alert)
        if let targetGroup = getGroup(at: indexPath) {
            confirmationAlert.title = targetGroup.name
            confirmationAlert.addAction(title: LString.actionDelete, style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didPressDeleteGroup(targetGroup, at: popoverAnchor, in: self)
            }
        } else if let targetEntry = getEntry(at: indexPath) {
            confirmationAlert.title = targetEntry.resolvedTitle
            confirmationAlert.addAction(title: LString.actionDelete, style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didPressDeleteEntry(targetEntry, at: popoverAnchor, in: self)
            }
        } else {
            assertionFailure("Unknown database item type")
        }

        confirmationAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        confirmationAlert.modalPresentationStyle = .popover
        popoverAnchor.apply(to: confirmationAlert.popoverPresentationController)
        present(confirmationAlert, animated: true, completion: nil)
    }

    private func didPressEmptyRecycleBinGroup(at indexPath: IndexPath) {
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        guard let targetGroup = getGroup(at: indexPath) else {
            assertionFailure("Cannot find a group at specified index path")
            return
        }
        let confirmationAlert = UIAlertController.make(
            title: LString.confirmEmptyRecycleBinGroup,
            message: nil,
            dismissButtonTitle: LString.actionCancel)
        confirmationAlert.addAction(title: LString.actionEmptyRecycleBinGroup, style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressEmptyRecycleBinGroup(targetGroup, at: popoverAnchor, in: self)
        }
        confirmationAlert.modalPresentationStyle = .popover
        popoverAnchor.apply(to: confirmationAlert.popoverPresentationController)
        present(confirmationAlert, animated: true, completion: nil)
    }

    func didPressRelocateItem(at indexPath: IndexPath, mode: ItemRelocationMode) {
        guard let selectedItem = getItem(at: indexPath) else {
            Diag.warning("No items selected for relocation")
            assertionFailure()
            return
        }

        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressRelocateItems([selectedItem], mode: mode, at: popoverAnchor, in: self)
    }

    @IBAction private func didPressReloadDatabase(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressReloadDatabase(at: popoverAnchor, in: self)
    }

    @IBAction private func didPressSettings(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressSettings(at: popoverAnchor, in: self)
    }

    @IBAction private func didPressPasswordGenerator(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressPasswordGenerator(at: popoverAnchor, in: self)
    }

    @objc
    private func didPressBulkDelete(_ sender: UIBarButtonItem) {
        let items = getSelectedItems()
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)

        let confirmationAlert = UIAlertController(
            title: String.localizedStringWithFormat(LString.itemsSelectedCountTemplate, items.count),
            message: nil,
            preferredStyle: .actionSheet
        )
        let actionTitle = items.count > 1 ? LString.actionDeleteAll : LString.actionDelete
        confirmationAlert.addAction(title: actionTitle, style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.stopSelectionMode(animated: false)
            self.delegate?.didPressDeleteItems(items, in: self)
        }
        confirmationAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        confirmationAlert.modalPresentationStyle = .popover
        popoverAnchor.apply(to: confirmationAlert.popoverPresentationController)
        present(confirmationAlert, animated: true, completion: nil)
    }

    @objc
    private func didPressBulkRelocate(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressRelocateItems(getSelectedItems(), mode: .move, at: popoverAnchor, in: self)
        stopSelectionMode(animated: false)
    }

    @objc
    private func didPressDoneSelectReorder(_ sender: UIBarButtonItem) {
        stopSelectionMode(animated: true)
    }
}

extension GroupViewerVC {
    private func stopSelectionMode(animated: Bool) {
        setEditingState(false, animated: animated)
        if isSearchActive {
            return
        }

        guard let group = group else {
            return
        }

        delegate?.didReorderItems(
            in: group,
            groups: groupsSorted.compactMap({ $0.value }),
            entries: entriesSorted.compactMap({ $0.value })
        )
    }

    private func startSelectionMode(animated: Bool) {
        setEditingState(true, animated: animated)
        updateBulkSelectionActions()
    }

    private func setEditingState(_ editing: Bool, animated: Bool) {
        tableView.setEditing(editing, animated: animated)
        tableView.allowsSelection = true
        navigationItem.setRightBarButton(
            tableView.isEditing ? doneSelectReorderButton : groupActionsButton,
            animated: animated
        )
        toolbarItems = tableView.isEditing ? [
            UIBarButtonItem.flexibleSpace(),
            bulkRelocateButton,
            UIBarButtonItem.flexibleSpace(),
            bulkDeleteButton,
        ] : defaultToolbarItems

        if animated {
            let sectionCount = numberOfSections(in: tableView)
            let sectionIndices = IndexSet(0..<sectionCount)
            tableView.reloadSections(sectionIndices, with: .automatic)
        } else {
            tableView.reloadData()
        }
    }

    private func getSelectedItems() -> [DatabaseItem] {
        guard let selection = tableView.indexPathsForSelectedRows,
              !selection.isEmpty
        else {
            return []
        }

        if isSearchActive {
            return selection.compactMap { getSearchResult(at: $0) }
        } else {
            return selection.compactMap { getItem(at: $0) }
        }
    }

    private func updateBulkSelectionActions() {
        let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
        let hasSelection = selectedCount > 0
        bulkDeleteButton.isEnabled = hasSelection
        bulkRelocateButton.isEnabled = hasSelection
    }
}

extension GroupViewerVC {
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard Settings.current.groupSortOrder == .noSorting else {
            return false
        }

        if isSearchActive {
            return false
        } else {
            switch Section(rawValue: indexPath.section) {
            case .announcements:
                return false
            case .groups,
                 .entries:
                return true
            default:
                fatalError("Unexpected section number")
            }
        }
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

    override func tableView(
       _ tableView: UITableView,
       moveRowAt sourceIndexPath: IndexPath,
       to destinationIndexPath: IndexPath
    ) {
        switch Section(rawValue: sourceIndexPath.section) {
        case .announcements:
            break
        case .groups:
            guard let group = getGroup(at: sourceIndexPath) else {
                return
            }
            groupsSorted.remove(at: sourceIndexPath.row)
            groupsSorted.insert(Weak(group), at: destinationIndexPath.row)
        case .entries:
            guard let entry = getEntry(at: sourceIndexPath) else {
                return
            }
            entriesSorted.remove(at: sourceIndexPath.row)
            entriesSorted.insert(Weak(entry), at: destinationIndexPath.row)
        default:
            fatalError("Unexpected section number")
        }
    }
}

#if targetEnvironment(macCatalyst)
extension GroupViewerVC {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let selectedRows = tableView.indexPathsForSelectedRows,
           selectedRows.contains(indexPath)
        {
            tableView.deselectRow(at: indexPath, animated: false)
            return nil
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
        if let selectedRows = tableView.indexPathsForSelectedRows,
           selectedRows.contains(indexPath)
        {
            return nil
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        tableView.indexPathsForSelectedRows?.forEach {
            tableView.cellForRow(at: $0)?.isHighlighted = true
        }
        return true
    }

    override func tableView(
        _ tableView: UITableView,
        selectionFollowsFocusForRowAt indexPath: IndexPath
    ) -> Bool {
        let isEntry = getEntry(at: indexPath) != nil
        return isEntry
    }
}
#endif

extension GroupViewerVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        switch key {
        case .appLockEnabled, .rememberDatabaseKey:
            refresh()
        case .groupSortOrder:
            updateGroupActionsMenuButton()
        default:
            break
        }
    }
}


extension GroupViewerVC: UISearchResultsUpdating {
    public func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text else { return }
        stopSelectionMode(animated: false)
        updateSearchResults(searchText: searchText)
    }

    private func updateSearchResults(searchText: String) {
        guard let group,
              let database = group.database
        else { return }

        searchResults = searchHelper.findEntriesAndGroups(
            database: database,
            searchText: searchText,
            excludeGroupUUID: group.isSmartGroup ? group.uuid : nil
        )
        searchResults.sort(order: Settings.current.groupSortOrder)
        tableView.reloadData()
    }
}

extension GroupViewerVC: UISearchControllerDelegate {
    public func didDismissSearchController(_ searchController: UISearchController) {
        refresh()
    }
}
