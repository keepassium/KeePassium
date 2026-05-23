//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UIKit

typealias GroupViewerAppearance = UICollectionLayoutListConfiguration.Appearance

final class GroupViewerVC: UIViewController {
    protocol Delegate: AnyObject {
        func didChangeSearchQuery(_ text: String?, in viewController: GroupViewerVC)

        func didSelectGroup(
            _ group: Group,
            cause: ItemActivationCause?,
            in viewController: GroupViewerVC
        ) -> Bool

        func didSelectEntry(
            _ entry: Entry,
            cause: ItemActivationCause?,
            in viewController: GroupViewerVC
        ) -> Bool

        func shouldAllowBulkSelection(in viewController: GroupViewerVC) -> Bool

        func shouldAllowReorder(in viewController: GroupViewerVC) -> Bool

        func didReorderItems(
            of group: Group,
            groups: [Group],
            entries: [Entry],
            in viewController: GroupViewerVC
        )

        func shouldAllowDragRelocation(
            of databaseItem: DatabaseItem,
            into group: Group?,
            in viewController: GroupViewerVC
        ) -> Bool

        func didDragItems(_ items: [DatabaseItem], into targetGroup: Group)

        func canDropFiles(_ files: [UIDragItem], onto entry: Entry, in viewController: GroupViewerVC) -> Bool

        func didDropFiles(_ files: [UIDragItem], onto entry: Entry, in viewController: GroupViewerVC)
    }

    weak var delegate: Delegate?

    public var showsSearchResults: Bool {
        switch _items {
        case .standard:
            return false
        case .smartGroup, .foundManually:
            return true
        }
    }
    internal let _group: Group
    internal var _dataSource: DataSource!
    internal let _itemDecorator: GroupViewerItemDecorator?
    internal let _toolbarDecorator: GroupViewerToolbarDecorator?
    internal let _emptySpaceDecorator: GroupViewerEmptySpaceDecorator?

    internal var _announcements = [Item]()
    internal var _items: DataViewModel = .empty

    internal var _otpDisplayMode: OTPDisplayMode = .protected
    internal var _otpDisplayModeForItem: [UUID: OTPDisplayMode] = [:]

    internal var _collectionView: UICollectionView!
    internal var _searchController: UISearchController!

    internal var isInSinglePanelMode: Bool {
        splitViewController?.isCollapsed ?? true
    }
    override var canBecomeFirstResponder: Bool { true }

    override var canDismissFromKeyboard: Bool {
        true
    }

    init(
        group: Group,
        itemDecorator: GroupViewerItemDecorator?,
        toolbarDecorator: GroupViewerToolbarDecorator?,
        emptySpaceDecorator: GroupViewerEmptySpaceDecorator?
    ) {
        self._group = group
        self._itemDecorator = itemDecorator
        self._toolbarDecorator = toolbarDecorator
        self._emptySpaceDecorator = emptySpaceDecorator
        super.init(nibName: nil, bundle: nil)

        view.backgroundColor = .systemBackground
        let appearance: GroupViewerAppearance = .plain
        _setupCollectionView(appearance: appearance)
        _setupDataSource(appearance: appearance)
        _setupSearch()
        self.title = group.name
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        _otpDisplayModeForItem.removeAll()
        refresh(animated: false)
    }

    func refresh(animated: Bool) {
        _applySnapshot(animated: animated)
        _updateToolbars(animated: animated)
    }

    public func refreshVisibleCells() {
        assert(Thread.isMainThread)
        let visibleItems = _collectionView.indexPathsForVisibleItems.compactMap {
            _dataSource.itemIdentifier(for: $0)
        }
        guard !visibleItems.isEmpty else {
            return
        }
        var snapshot = _dataSource.snapshot()
        snapshot.reconfigureItems(visibleItems)
        _dataSource.apply(snapshot, animatingDifferences: false)
    }

    public func selectEntry(_ entry: Entry?, animated: Bool) {
        if let entry {
            guard let indexPath = _getIndexPath(for: entry) else {
                return
            }
            _collectionView.selectItem(at: indexPath, animated: animated, scrollPosition: [])
        } else {
            _collectionView.selectItem(at: nil, animated: animated, scrollPosition: [])
        }
    }

    public func setOTPDisplayMode(_ mode: OTPDisplayMode, for entry: Entry) {
        if mode == _otpDisplayMode {
            _otpDisplayModeForItem.removeValue(forKey: entry.runtimeUUID)
        } else {
            _otpDisplayModeForItem[entry.runtimeUUID] = mode
        }
    }

    internal func _updateToolbars(animated: Bool) {
        let mode: GroupViewerToolbarMode
        let selectedDatabaseItems = _getSelectedDatabaseItems()
        if isEditing || selectedDatabaseItems.count > 1 {
            mode = .bulkEdit(
                showsSearchResults: showsSearchResults,
                selectedItems: selectedDatabaseItems)
        } else {
            mode = .normal(showsSearchResults: showsSearchResults)
        }
        let toolbarItems = _toolbarDecorator?.getToolbarItems(mode: mode)
        setToolbarItems(toolbarItems, animated: false)

        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.setLeftBarButtonItems(
            _toolbarDecorator?.getLeftBarButtonItems(mode: mode),
            animated: animated)
        navigationItem.setRightBarButtonItems(
            _toolbarDecorator?.getRightBarButtonItems(mode: mode),
            animated: animated)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        _collectionView.isEditing = editing

        _collectionView.dragInteractionEnabled = !editing
        if editing {
            _searchController.searchBar.isEnabled = false
        } else {
            _searchController.searchBar.isEnabled = true
            _otpDisplayModeForItem.removeAll()
            _collectionView.indexPathsForSelectedItems?.forEach {
                _collectionView.deselectItem(at: $0, animated: false)
            }
        }
        refresh(animated: animated)
    }

    internal func _getOTPDisplayModeForItem(_ item: Item) -> OTPDisplayMode {
        switch item {
        case .announcement, .emptyStatePlaceholder:
            return _otpDisplayMode
        case let .entry(entry):
            return _otpDisplayModeForItem[entry.runtimeUUID] ?? _otpDisplayMode
        case let .group(group):
            return _otpDisplayModeForItem[group.runtimeUUID] ?? _otpDisplayMode
        }
    }

    internal func _getOTPDisplayModeForItem(_ databaseItem: DatabaseItem) -> OTPDisplayMode {
        return _otpDisplayModeForItem[databaseItem.runtimeUUID] ?? _otpDisplayMode
    }
}
