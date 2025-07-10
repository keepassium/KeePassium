//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

protocol FilePickerToolbarDecorator {
    func getToolbarItems() -> [UIBarButtonItem]?
    func getLeadingItemGroups() -> [UIBarButtonItemGroup]?
    func getTrailingItemGroups() -> [UIBarButtonItemGroup]?
}

protocol FilePickerItemDecorator: AnyObject {
    func getLeadingSwipeActions(forFile item: FilePickerItem.FileInfo) -> [UIContextualAction]?
    func getTrailingSwipeActions(forFile item: FilePickerItem.FileInfo) -> [UIContextualAction]?
    func getAccessories(for fileItem: FilePickerItem.FileInfo) -> [UICellAccessory]?
    func getContextMenu(for item: FilePickerItem.FileInfo, at popoverAnchor: PopoverAnchor) -> UIMenu?
}

typealias FilePickerAppearance = UICollectionLayoutListConfiguration.Appearance

class FilePickerVC: UIViewController {
    protocol Delegate: AnyObject {
        func needsRefresh(_ viewController: FilePickerVC)

        func shouldAcceptUserSelection(_ fileRef: URLReference, in viewController: FilePickerVC) -> Bool

        func didSelectFile(
            _ fileRef: URLReference?,
            cause: FileActivationCause?,
            in viewController: FilePickerVC)
    }

    weak var delegate: Delegate?

    private enum Section: Int, CaseIterable {
        case announcements
        case noFile
        case files
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, FilePickerItem>!
    private let toolbarDecorator: FilePickerToolbarDecorator?
    private let itemDecorator: FilePickerItemDecorator?
    private let fileType: FileType

    private var announcementItems = [FilePickerItem]()
    private var noFileItem: FilePickerItem?
    private var fileItems = [FilePickerItem]()

    private var collectionView: UICollectionView!
    private var refreshControl = UIRefreshControl()

    private var isInSinglePanelMode: Bool {
        splitViewController?.isCollapsed ?? true
    }
    override var canBecomeFirstResponder: Bool { true }

    init(
        fileType: FileType,
        toolbarDecorator: FilePickerToolbarDecorator?,
        itemDecorator: FilePickerItemDecorator?,
        appearance: FilePickerAppearance
    ) {
        self.fileType = fileType
        self.toolbarDecorator = toolbarDecorator
        self.itemDecorator = itemDecorator
        super.init(nibName: nil, bundle: nil)
        initCollectionView(appearance: appearance)
        setupCollectionView()
        setupDataSource()
    }

    private func initCollectionView(appearance: FilePickerAppearance) {
        let trailingActionsProvider = { [weak self] (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
            guard let self else { return nil }
            switch dataSource.itemIdentifier(for: indexPath) {
            case .announcement, .noFile:
                return nil
            case .file(let fileItem):
                if let actions = itemDecorator?.getTrailingSwipeActions(forFile: fileItem) {
                    return UISwipeActionsConfiguration(actions: actions)
                }
                return nil
            case .none:
                assertionFailure()
                return nil
            }
        }
        let leadingActionsProvider = { [weak self] (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
            guard let self else { return nil }
            switch dataSource.itemIdentifier(for: indexPath) {
            case .announcement, .noFile:
                return nil
            case .file(let fileItem):
                if let actions = itemDecorator?.getLeadingSwipeActions(forFile: fileItem) {
                    return UISwipeActionsConfiguration(actions: actions)
                }
                return nil
            case .none:
                assertionFailure()
                return nil
            }
        }

        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            var config: UICollectionLayoutListConfiguration
            switch Section(rawValue: sectionIndex) {
            case .announcements:
                config = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
            case .noFile:
                config = UICollectionLayoutListConfiguration(appearance: appearance)
            case .files:
                config = UICollectionLayoutListConfiguration(appearance: appearance)
            case .none:
                assertionFailure()
                return nil
            }
            config.leadingSwipeActionsConfigurationProvider = leadingActionsProvider
            config.trailingSwipeActionsConfigurationProvider = trailingActionsProvider
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.allowsSelection = true
        collectionView.allowsFocus = true
        collectionView.selectionFollowsFocus = true
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isInSinglePanelMode {
            collectionView.selectItem(at: nil, animated: false, scrollPosition: [])
        }
        delegate?.needsRefresh(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if isInSinglePanelMode {
            becomeFirstResponder()
        }
    }

    private func setupCollectionView() {
        collectionView.register(
            FilePickerCell.self,
            forCellWithReuseIdentifier: FilePickerCell.reuseIdentifier)
        collectionView.register(
            AnnouncementCollectionCell.self,
            forCellWithReuseIdentifier: AnnouncementCollectionCell.reuseIdentifier)
        collectionView.delegate = self

        view.addSubview(collectionView)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        refreshControl.backgroundColor = .clear
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func setupDataSource() {
        let fileCellRegistration = UICollectionView.CellRegistration<FilePickerCell, FilePickerItem.FileInfo> {
            [weak itemDecorator] cell, indexPath, item in
            let accessories = itemDecorator?.getAccessories(for: item)
            cell.configure(with: item, accessories: accessories)
        }
        let noFileCellRegistration = UICollectionView.CellRegistration
            <SelectableCollectionViewListCell, FilePickerItem.TitleImage>
        {
            cell, indexPath, item in
            var config = UIListContentConfiguration.cell()
            config.text = item.title
            config.secondaryText = item.subtitle
            config.image = item.image
            config.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = config
        }

        dataSource = UICollectionViewDiffableDataSource<Section, FilePickerItem>(
            collectionView: collectionView
        ) { collectionView, indexPath, item -> UICollectionViewCell? in
            switch item {
            case .announcement(let announcement):
                let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: AnnouncementCollectionCell.reuseIdentifier,
                    for: indexPath
                ) as! AnnouncementCollectionCell
                cell.configure(with: announcement)
                return cell
            case .noFile(let item):
                return collectionView.dequeueConfiguredReusableCell(
                    using: noFileCellRegistration,
                    for: indexPath,
                    item: item)
            case .file(let fileInfo):
                return collectionView.dequeueConfiguredReusableCell(
                    using: fileCellRegistration,
                    for: indexPath,
                    item: fileInfo)
            }
        }
    }

    @objc private func didPullToRefresh(_ sender: UIRefreshControl) {
        delegate?.needsRefresh(self)
        waitUntilDraggingEnds { [weak self] in
            guard let self else { return }
            refreshControl.endRefreshing()
            collectionView.setContentOffset(
                CGPoint(x: 0, y: -collectionView.adjustedContentInset.top),
                animated: true)
        }
    }

    private func waitUntilDraggingEnds(completion: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            if collectionView.isDragging {
                waitUntilDraggingEnds(completion: completion)
            } else {
                completion()
            }
        }
    }

    func refreshControls() {
        setupToolbar()
        setupNavbar()
    }

    private func setupToolbar() {
        let toolbarItems = toolbarDecorator?.getToolbarItems()
        setToolbarItems(toolbarItems, animated: false)
    }

    private func setupNavbar() {
        navigationItem.leadingItemGroups = toolbarDecorator?.getLeadingItemGroups() ?? []
        navigationItem.trailingItemGroups = toolbarDecorator?.getTrailingItemGroups() ?? []
    }

    public func setFileRefs(_ refs: [URLReference]) {
        let sortOrder = Settings.current.filesSortOrder
        let sortedRefs = refs.sorted { sortOrder.compare($0, $1) }
        let sortedItems = sortedRefs.map {
            FilePickerItem.FileInfo(source: $0, fileType: fileType)
        }
        self.fileItems = sortedItems.map { FilePickerItem.file($0) }
        applySnapshot()
    }

    public func setAnnouncements(_ announcements: [AnnouncementItem]) {
        self.announcementItems = announcements.map {
            FilePickerItem.announcement($0)
        }
        applySnapshot()
    }

    public func setNoSelectionItem(_ item: FilePickerItem.TitleImage?) {
        if let item {
            self.noFileItem = FilePickerItem.noFile(item)
        } else {
            self.noFileItem = nil
        }
        applySnapshot()
    }

    public func setEnabled(_ enabled: Bool) {
        let alpha: CGFloat = enabled ? 1.0 : 0.5
        navigationController?.navigationBar.isUserInteractionEnabled = enabled
        navigationItem.leadingItemGroups.forEach {
            $0.barButtonItems.forEach { $0.isEnabled = enabled }
        }
        navigationItem.trailingItemGroups.forEach {
            $0.barButtonItems.forEach { $0.isEnabled = enabled }
        }
        collectionView.isUserInteractionEnabled = enabled
        toolbarItems?.forEach {
            $0.isEnabled = enabled
        }
        UIView.animate(withDuration: 0.5) { [self] in
            collectionView.alpha = alpha
        }
    }

    public func selectFile(_ fileRef: URLReference?, animated: Bool) {
        if let fileRef {
            guard let indexPath = getIndexPath(for: fileRef) else {
                return
            }
            collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: .centeredVertically)
            return
        }

        if let noFileItem,
           let noFileIndexPath = dataSource.indexPath(for: noFileItem)
        {
            collectionView.selectItem(at: noFileIndexPath, animated: animated, scrollPosition: .top)
        } else {
            collectionView.selectItem(at: nil, animated: animated, scrollPosition: .centeredVertically)
        }
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FilePickerItem>()
        if let noFileItem {
            snapshot.appendSections([.announcements, .noFile, .files])
            snapshot.appendItems([noFileItem], toSection: .noFile)
        } else {
            snapshot.appendSections([.announcements, .files])
        }
        snapshot.appendItems(announcementItems, toSection: .announcements)
        snapshot.appendItems(fileItems, toSection: .files)

        snapshot.reconfigureItems(fileItems)
        dataSource.apply(snapshot, animatingDifferences: true)

    }

    private func animateSelectionDenied(at indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        cell.contentView.shake()
    }

    private func getIndexPath(for fileRef: URLReference) -> IndexPath? {
        let uuid = fileRef.runtimeUUID

        let itemByUUID = fileItems.first(where: {
            if case .file(let fileInfo) = $0 {
                return fileInfo.uuid == uuid
            }
            return false
        })
        if let itemByUUID {
            return dataSource.indexPath(for: itemByUUID)
        }

        let itemByEquality = fileItems.first(where: {
            if case .file(let fileInfo) = $0 {
                return fileRef == fileInfo.source
            }
            return false
        })
        if let itemByEquality {
            return dataSource.indexPath(for: itemByEquality)
        }
        return nil
    }
}

extension FilePickerVC {
    override var keyCommands: [UIKeyCommand]? {
        return [
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(didPressEnter)),
            UIKeyCommand(
                action: #selector(didPressRefresh),
                hotkey: .refreshList,
                discoverabilityTitle: LString.actionRefreshList
            )
        ]
    }

    @objc private func didPressEnter() {
        guard let indexPaths = collectionView.indexPathsForSelectedItems,
              let selectedIndexPath = indexPaths.first
        else { return }
        handlePrimaryAction(at: selectedIndexPath, cause: .keyPress)
    }

    @objc private func didPressRefresh() {
        delegate?.needsRefresh(self)
    }
}

extension FilePickerVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return isSelectableCell(at: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        return isSelectableCell(at: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        canPerformPrimaryActionForItemAt indexPath: IndexPath
    ) -> Bool {
        return isSelectableCell(at: indexPath)
    }

    private func isSelectableCell(at indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .announcement:
            return false
        case .noFile, .file:
            return true
        case .none:
            return false
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isInSinglePanelMode {
            return
        }
        switch dataSource.itemIdentifier(for: indexPath) {
        case .announcement:
            return
        case .noFile:
            delegate?.didSelectFile(nil, cause: nil, in: self)
            return
        case .file(let fileItem):
            guard let fileRef = fileItem.source else { assertionFailure(); return }
            guard delegate?.shouldAcceptUserSelection(fileRef, in: self) ?? true else {
                animateSelectionDenied(at: indexPath)
                break
            }
            delegate?.didSelectFile(fileRef, cause: nil, in: self)
        case .none:
            assertionFailure()
            return
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performPrimaryActionForItemAt indexPath: IndexPath
    ) {
        handlePrimaryAction(at: indexPath, cause: .touch)
    }

    private func handlePrimaryAction(at indexPath: IndexPath, cause: FileActivationCause?) {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .announcement:
            assertionFailure("Announcements should not be selectable")
        case .noFile:
            delegate?.didSelectFile(nil, cause: cause, in: self)
        case .file(let fileItem):
            guard let fileRef = fileItem.source else {
                assertionFailure()
                return
            }
            guard delegate?.shouldAcceptUserSelection(fileRef, in: self) ?? true else {
                animateSelectionDenied(at: indexPath)
                break
            }
            delegate?.didSelectFile(fileRef, cause: cause, in: self)
        case .none:
            assertionFailure()
            return
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .announcement, .noFile:
            return nil
        case .file(let fileItem):
            guard let popoverAnchor = collectionView.cellForItem(at: indexPath)?.asPopoverAnchor else {
                assertionFailure()
                return nil
            }
            return UIContextMenuConfiguration(actionProvider: { [weak itemDecorator] _ in
                itemDecorator?.getContextMenu(for: fileItem, at: popoverAnchor)
            })
        case .none:
            assertionFailure()
            return nil
        }
    }
}

extension FilePickerVC: BusyStateIndicating {
    func indicateState(isBusy: Bool) {
        if isBusy {
            view.makeToastActivity(.center)
        } else {
            view.hideToastActivity()
        }
    }
}
