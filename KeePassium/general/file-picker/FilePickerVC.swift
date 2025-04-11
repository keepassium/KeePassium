//  KeePassium Password Manager
//  Copyright © 2018-2024 KeePassium Labs <info@keepassium.com>
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

class FilePickerVC: UIViewController {
    protocol Delegate: AnyObject {
        func needsRefresh(_ viewController: FilePickerVC)

        func shouldAcceptUserSelection(_ fileRef: URLReference, in viewController: FilePickerVC) -> Bool

        func didSelectFile(
            _ fileRef: URLReference,
            cause: FileActivationCause?,
            in viewController: FilePickerVC)
    }

    weak var delegate: Delegate?

    private enum Section: Int, CaseIterable {
        case announcements
        case files
    }
    private var dataSource: UICollectionViewDiffableDataSource<Section, FilePickerItem>!
    private let toolbarDecorator: FilePickerToolbarDecorator?
    private let itemDecorator: FilePickerItemDecorator?
    private let fileType: FileType

    private var announcementItems = [FilePickerItem]()
    private var fileItems = [FilePickerItem]()

    private var collectionView: UICollectionView!

    private var isInSinglePanelMode: Bool {
        splitViewController?.isCollapsed ?? true
    }
    override var canBecomeFirstResponder: Bool { true }

    init(
        fileType: FileType,
        toolbarDecorator: FilePickerToolbarDecorator?,
        itemDecorator: FilePickerItemDecorator?
    ) {
        self.fileType = fileType
        self.toolbarDecorator = toolbarDecorator
        self.itemDecorator = itemDecorator
        super.init(nibName: nil, bundle: nil)
        initCollectionView()
        setupCollectionView()
        setupDataSource()
    }

    private func initCollectionView() {
        let trailingActionsProvider = { [weak self] (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
            guard let self else { return nil }
            switch dataSource.itemIdentifier(for: indexPath) {
            case .file(let fileItem):
                if let actions = itemDecorator?.getTrailingSwipeActions(forFile: fileItem) {
                    return UISwipeActionsConfiguration(actions: actions)
                }
                return nil
            default:
                return nil
            }
        }
        let leadingActionsProvider = { [weak self] (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
            guard let self else { return nil }
            switch dataSource.itemIdentifier(for: indexPath) {
            case .file(let fileItem):
                if let actions = itemDecorator?.getLeadingSwipeActions(forFile: fileItem) {
                    return UISwipeActionsConfiguration(actions: actions)
                }
                return nil
            default:
                return nil
            }
        }

        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            switch Section(rawValue: sectionIndex) {
            case .announcements:
                let config = UICollectionLayoutListConfiguration(appearance: .sidebarPlain)
                return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            case .files:
                var config = UICollectionLayoutListConfiguration(appearance: .plain)
                config.leadingSwipeActionsConfigurationProvider = leadingActionsProvider
                config.trailingSwipeActionsConfigurationProvider = trailingActionsProvider
                return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
            default:
                return nil
            }
        }
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.allowsSelection = true
        collectionView.allowsFocus = true
        collectionView.selectionFollowsFocus = true
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }

    private func setupDataSource() {
        let fileCellRegistration = UICollectionView.CellRegistration<FilePickerCell, FilePickerItem.FileInfo> {
            [weak itemDecorator] cell, indexPath, item in
            let accessories = itemDecorator?.getAccessories(for: item)
            cell.configure(with: item, accessories: accessories)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5){
            sender.endRefreshing()
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
        guard let fileRef else {
            collectionView.selectItem(at: nil, animated: animated, scrollPosition: .centeredVertically)
            return
        }

        guard let indexPath = getIndexPath(for: fileRef) else {
            return
        }
        collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: .centeredVertically)
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, FilePickerItem>()
        snapshot.appendSections(Section.allCases)

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
            UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(didPressEnter))
        ]
    }

    @objc private func didPressEnter() {
        guard let indexPaths = collectionView.indexPathsForSelectedItems,
              let selectedIndexPath = indexPaths.first
        else { return }
        handlePrimaryAction(at: selectedIndexPath, cause: .keyPress)
    }
}

extension FilePickerVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        return trueIfFile(at: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        return trueIfFile(at: indexPath)
    }

    private func trueIfFile(at indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .announcement:
            return false
        case .file:
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
        case .file(let fileItem):
            guard let fileRef = fileItem.source else { assertionFailure(); return }
            guard delegate?.shouldAcceptUserSelection(fileRef, in: self) ?? true else {
                animateSelectionDenied(at: indexPath)
                break
            }
            delegate?.didSelectFile(fileRef, cause: nil, in: self)
        case .none:
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
        case .announcement:
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
