//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

struct DatabaseItemActionPermissions {
    static let everythingForbidden = DatabaseItemActionPermissions(
        canEditDatabase: false,
        canCreateGroup: false,
        canCreateEntry: false,
        canEditItem: false,
        canDeleteItem: false,
        canMoveItem: false
    )
    var canEditDatabase = false
    var canCreateGroup = false
    var canCreateEntry = false
    var canEditItem = false
    var canDeleteItem = false
    var canMoveItem = false
}

protocol GroupViewerDelegate: AnyObject {
    func didPressLockDatabase(in viewController: GroupViewerVC)
    func didPressChangeMasterKey(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC)
    func didPressSettings(at popoverAnchor: PopoverAnchor, in viewController: GroupViewerVC)

    func didSelectGroup(_ group: Group?, in viewController: GroupViewerVC) -> Bool
    
    func didSelectEntry(_ entry: Entry?, in viewController: GroupViewerVC) -> Bool
    
    func didPressCreateGroup(
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
    
    func didPressDeleteEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )
    
    func didPressRelocateItem(
        _ item: DatabaseItem,
        mode: ItemRelocationMode,
        at popoverAnchor: PopoverAnchor,
        in viewController: GroupViewerVC
    )
    
    func getActionPermissions(for group: Group) -> DatabaseItemActionPermissions
    func getActionPermissions(for entry: Entry) -> DatabaseItemActionPermissions
    
    func getAnnouncements(for group: Group, in viewController: GroupViewerVC) -> [AnnouncementItem]
}


final class GroupViewerGroupCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}

final class GroupViewerEntryCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    @IBOutlet private weak var hStack: UIStackView!
    @IBOutlet private weak var showOTPButton: UIButton!
    @IBOutlet private weak var otpView: OTPView!
    @IBOutlet private weak var attachmentIndicator: UIImageView!
    
    var hasAttachments: Bool = false {
        didSet {
            setVisible(attachmentIndicator, hasAttachments)
        }
    }
    
    var totpGenerator: TOTPGenerator? {
        didSet {
            refresh()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        attachmentIndicator.isHidden = true
        showOTPButton.isHidden = true
        otpView.isHidden = true
        showOTPButton.setTitle("", for: .normal)
        showOTPButton.accessibilityLabel = "OTP"
        showOTPButton.setImage(UIImage.get(.clock), for: .normal)
        otpView.tapHandler = { [weak self] in
            self?.animateOTPValue(visible: false)
        }
    }
    
    private func setVisible(_ view: UIView, _ visible: Bool) {
        let isViewAlreadyVisible = !view.isHidden
        guard visible != isViewAlreadyVisible else {
            return
        }
        view.isHidden = !visible
    }
    
    public func refresh() {
        guard let totpGenerator = totpGenerator else {
            setVisible(showOTPButton, false)
            setVisible(otpView, false)
            return
        }
        if otpView.isHidden {
            setVisible(showOTPButton, true)
            return
        }

        otpView.value = totpGenerator.generate()
        otpView.remainingTime = totpGenerator.remainingTime
        otpView.refresh()
        
        let justSwitched = !showOTPButton.isHidden
        if justSwitched {
            animateOTPValue(visible: true)
        }
    }
    
    private func animateOTPValue(visible: Bool) {
        let animateValue = (otpView.isHidden != !visible)
        let animateButton = (showOTPButton.isHidden != visible)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .beginFromCurrentState,
            animations: { [weak self] in
                guard let self = self else { return }
                if animateValue {
                    self.otpView.isHidden = !visible
                }
                if animateButton {
                    self.showOTPButton.isHidden = visible
                }
                self.hStack.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    @IBAction private func didPressShowOTP(_ sender: UIButton) {
        setVisible(otpView, true)
        refresh()
    }
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
    
    weak var delegate: GroupViewerDelegate?
    
    @IBOutlet private weak var sortOrderButton: UIBarButtonItem!
    @IBOutlet weak var changeMasterKeyButton: UIBarButtonItem!
    
    weak var group: Group? {
        didSet {
            refresh()
        }
    }

    var isGroupEmpty: Bool {
        return groupsSorted.isEmpty && entriesSorted.isEmpty
    }
    
    private var titleView = DatabaseItemTitleView()
    
    private var groupsSorted = Array<Weak<Group>>()
    private var entriesSorted = Array<Weak<Entry>>()

    private var createItemButton: UIBarButtonItem!
    
    private var actionPermissions = DatabaseItemActionPermissions()
    
    private var announcements = [AnnouncementItem]()
    
    private var isActivateSearch: Bool = false
    private var searchHelper = SearchHelper()
    private var searchResults = [GroupedEntries]()
    private var searchController: UISearchController!
    var isSearchActive: Bool {
        guard let searchController = searchController else { return false }
        return searchController.isActive && (searchController.searchBar.text?.isNotEmpty ?? false)
    }
    
    override var canDismissFromKeyboard: Bool {
        return !(searchController?.isActive ?? false)
    }
    
    private var cellRefreshTimer: Timer?
    private var settingsNotifications: SettingsNotifications!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        tableView.register(AnnouncementCell.classForCoder(), forCellReuseIdentifier: CellID.announcement)
        
        createItemButton = UIBarButtonItem(
            title: LString.actionCreate,
            image: UIImage(asset: .createItemToolbar),
            primaryAction: nil,
            menu: nil)
        navigationItem.setRightBarButton(createItemButton, animated: false)
        
        navigationItem.titleView = titleView
        
        settingsNotifications = SettingsNotifications(observer: self)
        
        let isRootGroup = group?.isRoot ?? false
        isActivateSearch = Settings.current.isStartWithSearch && isRootGroup
        setupSearch()
        if isRootGroup {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        cellRefreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
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
        searchController = UISearchController(searchResultsController: nil)
        navigationItem.searchController = searchController

        searchController.searchBar.searchBarStyle = .default
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.barStyle = .default
        if #available(iOS 12, *) {
        } else {
            searchController.dimsBackgroundDuringPresentation = false
        }
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.delegate = self

        definesPresentationContext = true
        searchController.searchResultsUpdater = self
    }
    
    override var keyCommands: [UIKeyCommand]? {
        var commands = [UIKeyCommand]()
        if #available(iOS 13, *) {
            commands.append(
                UIKeyCommand(
                    action: #selector(activateSearch),
                    input: "f",
                    modifierFlags: [.command],
                    discoverabilityTitle: LString.titleSearch
                )
            )
        } else {
            commands.append(
                UIKeyCommand(
                    input: "f",
                    modifierFlags: [.command],
                    action: #selector(activateSearch),
                    discoverabilityTitle: LString.titleSearch
                )
            )
        }
        return commands
    }
    
    @objc func activateSearch() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.searchController.isActive = true
            self.searchController.searchBar.becomeFirstResponderWhenSafe()
        }
    }
    
    func refresh() {
        guard isViewLoaded, let group = group else { return }
        
        titleView.titleLabel.setText(group.name, strikethrough: group.isExpired)
        titleView.iconView.image = UIImage.kpIcon(forGroup: group)
        navigationItem.title = titleView.titleLabel.text

        announcements = delegate?.getAnnouncements(for: group, in: self) ?? []

        actionPermissions =
            delegate?.getActionPermissions(for: group) ??
            DatabaseItemActionPermissions()
        createItemButton.isEnabled =
            actionPermissions.canCreateGroup ||
            actionPermissions.canCreateEntry
        changeMasterKeyButton.isEnabled = actionPermissions.canEditDatabase
        
        createItemButton.menu = makeCreateItemMenu(for: createItemButton)
        
        if isSearchActive {
            updateSearchResults(for: searchController)
        } else {
            sortGroupItems()
        }
        tableView.reloadData()
        
        sortOrderButton.menu = makeListSettingsMenu()
        sortOrderButton.image = Settings.current.groupSortOrder.toolbarIcon
    }
    
    func refreshAnnouncements() {
        guard isViewLoaded, let group = group else { return }
        announcements = delegate?.getAnnouncements(for: group, in: self) ?? []
        tableView.reloadSections([0], with: .automatic)
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
    
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        if isSearchActive {
            return searchResults.isEmpty ? 1 : searchResults.count
        } else {
            return 1
        }
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int) -> String?
    {
        if isSearchActive {
            return searchResults.isEmpty ? nil : searchResults[section].group.name
        } else {
            return nil
        }
    }
    
    override func tableView(
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
                return announcements.count + 1 // for "Nothing here" cell
            } else {
                return announcements.count + groupsSorted.count + entriesSorted.count
            }
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if isSearchActive {
            return makeSearchResultCell(at: indexPath)
        } else {
            if announcements.indices.contains(indexPath.row) {
                return makeAnnouncementCell(at: indexPath)
            } else {
                return makeDatabaseItemCell(at: indexPath)
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

        let entry = searchResults[indexPath.section].entries[indexPath.row].entry
        let entryCell = tableView.dequeueReusableCell(
            withIdentifier: CellID.entry,
            for: indexPath)
            as! GroupViewerEntryCell
        setupEntryCell(entryCell, entry: entry)
        return entryCell
    }
    
    private func makeDatabaseItemCell(at indexPath: IndexPath) -> UITableViewCell {
        if isGroupEmpty {
            return tableView.dequeueReusableCell(withIdentifier: CellID.emptyGroup, for: indexPath)
        }
        
        if let group = getGroup(at: indexPath) {
            return getGroupCell(for: group, at: indexPath)
        } else if let entry = getEntry(at: indexPath) {
            return getEntryCell(for: entry, at: indexPath)
        } else {
            assertionFailure()
            return tableView.dequeueReusableCell(withIdentifier: CellID.group, for: indexPath)
        }
    }
    
    private func getGroupCell(for group: Group, at indexPath: IndexPath) -> GroupViewerGroupCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: CellID.group,
            for: indexPath)
            as! GroupViewerGroupCell
        
        let itemCount = group.groups.count + group.entries.count
        cell.titleLabel.setText(group.name, strikethrough: group.isExpired)
        cell.subtitleLabel?.setText("\(itemCount)", strikethrough: group.isExpired)
        cell.iconView?.image = UIImage.kpIcon(forGroup: group)
        cell.accessibilityLabel = String.localizedStringWithFormat(
            LString.titleGroupDescriptionTemplate,
            group.name)
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
        
        cell.hasAttachments = entry.attachments.count > 0
        if #available(iOS 13, *) {
            cell.accessibilityCustomActions = getAccessibilityActions(for: entry)
        }
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
        }
    }
    
    
    @available(iOS 13, *)
    private func getAccessibilityActions(for entry: Entry) -> [UIAccessibilityCustomAction] {
        var actions = [UIAccessibilityCustomAction]()
        
        let nonTitleFields = entry.fields.filter { $0.name != EntryField.title }
        nonTitleFields.reversed().forEach { (field) in
            let actionName = String.localizedStringWithFormat(
                LString.actionCopyToClipboardTemplate,
                field.name)
            let action = UIAccessibilityCustomAction(name: actionName) {
                [weak field] _ -> Bool in
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
        if isSearchActive {
            didSelectItem(at: indexPath)
        } else {
            if !isGroupEmpty {
                didSelectItem(at: indexPath)
            }
        }
    }

    
    private func getIndexPath(for group: Group) -> IndexPath? {
        guard let groupIndex = groupsSorted.firstIndex(where: { $0.value === group }) else {
            return nil
        }
        let indexPath = IndexPath(row: groupIndex, section: 0)
        return indexPath
    }

    private func getIndexPath(for entry: Entry) -> IndexPath? {
        guard let entryIndex = entriesSorted.firstIndex(where: { $0.value === entry }) else {
            return nil
        }
        let indexPath = IndexPath(row: groupsSorted.count + entryIndex, section: 0)
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
        if isSearchActive {
            return nil
        } else {
            let groupIndex = indexPath.row - announcements.count
            guard groupsSorted.indices.contains(groupIndex) else { return nil }
            return groupsSorted[groupIndex].value
        }
    }
    
    func getEntry(at indexPath: IndexPath) -> Entry? {
        if isSearchActive {
            guard indexPath.section < searchResults.count else { return  nil }
            let searchResult = searchResults[indexPath.section]
            guard indexPath.row < searchResult.entries.count else { return nil }
            return searchResult.entries[indexPath.row].entry
        } else {
            let entryIndex = indexPath.row - announcements.count - groupsSorted.count
            guard entriesSorted.indices.contains(entryIndex) else { return nil }
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
        let entrySubtitleActions = Settings.EntryListDetail.allValues.map {
            entryListDetail in
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
        let permissions: DatabaseItemActionPermissions
        if let group = getGroup(at: indexPath) {
            permissions = delegate?.getActionPermissions(for: group) ?? DatabaseItemActionPermissions()
        } else if let entry = getEntry(at: indexPath) {
            permissions = delegate?.getActionPermissions(for: entry) ?? DatabaseItemActionPermissions()
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
        }
        return actions
    }
    

    private func makeCreateItemMenu(for button: UIBarButtonItem) -> UIMenu {
        let popoverAnchor = PopoverAnchor(barButtonItem: button)
        
        let createGroupAction = UIAction(
            title: LString.actionCreateGroup,
            image: nil,
            attributes: actionPermissions.canCreateGroup ? [] : [.disabled],
            handler: {
                [weak self, popoverAnchor] _ in
                guard let self = self else { return }
                self.delegate?.didPressCreateGroup(at: popoverAnchor, in: self)
            }
        )
        
        let createEntryAction = UIAction(
            title: LString.actionCreateEntry,
            image: nil,
            attributes: actionPermissions.canCreateEntry ? [] : [.disabled],
            handler: {
                [weak self, popoverAnchor] _ in
                guard let self = self else { return }
                self.delegate?.didPressCreateEntry(at: popoverAnchor, in: self)
            }
        )
        
        return UIMenu.make(
            title: "",
            reverse: false,
            options: [],
            children: [createGroupAction, createEntryAction]
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
            confirmationAlert.addAction(title: LString.actionDelete, style: .destructive) {
                [weak self] _ in
                guard let self = self else { return }
                self.delegate?.didPressDeleteGroup(targetGroup, at: popoverAnchor, in: self)
            }
        } else if let targetEntry = getEntry(at: indexPath) {
            confirmationAlert.title = targetEntry.resolvedTitle
            confirmationAlert.addAction(title: LString.actionDelete, style: .destructive) {
                [weak self] _ in
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
    

    func didPressRelocateItem(at indexPath: IndexPath, mode: ItemRelocationMode) {
        guard let selectedItem = getItem(at: indexPath) else {
            Diag.warning("No items selected for relocation")
            assertionFailure()
            return
        }
        
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        delegate?.didPressRelocateItem(selectedItem, mode: mode, at: popoverAnchor, in: self)
    }
    
    @IBAction func didPressSettings(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressSettings(at: popoverAnchor, in: self)
    }
    
    @IBAction func didPressLockDatabase(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        
        let confirmationAlert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        confirmationAlert.addAction(title: LString.actionLockDatabase, style: .destructive) {
            [weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressLockDatabase(in: self)
        }
        confirmationAlert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
        
        confirmationAlert.modalPresentationStyle = .popover
        popoverAnchor.apply(to: confirmationAlert.popoverPresentationController)
        present(confirmationAlert, animated: true, completion: nil)
    }
    
    @IBAction func didPressChangeDatabaseSettings(_ sender: UIBarButtonItem) {
        let popoverAnchor = PopoverAnchor(barButtonItem: sender)
        delegate?.didPressChangeMasterKey(at: popoverAnchor, in: self)
    }
}

extension GroupViewerVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        switch key {
        case .appLockEnabled, .rememberDatabaseKey:
            refreshAnnouncements()
        default:
            break
        }
    }
}


extension GroupViewerVC: UISearchResultsUpdating {
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

extension GroupViewerVC: UISearchControllerDelegate {
    public func didDismissSearchController(_ searchController: UISearchController) {
        refresh()
    }
}
