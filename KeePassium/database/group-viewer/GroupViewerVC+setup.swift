//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UIKit

extension GroupViewerVC {
    internal func _setupCollectionView(appearance: GroupViewerAppearance) {
        let trailingActionsProvider = { [weak self] (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
            guard let self else { return nil }
            guard let item = _dataSource.itemIdentifier(for: indexPath) else {
                assertionFailure()
                return nil
            }

            let cell = _collectionView.cellForItem(at: indexPath)
            let context = GroupViewerItemDecoratorContext(
                isSearchMode: showsSearchResults,
                popoverAnchor: PopoverAnchor.sourceItem(item: cell ?? _collectionView),
                otpDisplayMode: _getOTPDisplayModeForItem(item),
                contentView: cell?.contentView)
            guard let actions = _itemDecorator?.getTrailingSwipeActions(for: item, context: context) else {
                return nil
            }
            return UISwipeActionsConfiguration(actions: actions)
        }
        let leadingActionsProvider = { [weak self] (indexPath: IndexPath) -> UISwipeActionsConfiguration? in
            guard let self else { return nil }
            guard let item = _dataSource.itemIdentifier(for: indexPath) else {
                assertionFailure()
                return nil
            }

            let cell = _collectionView.cellForItem(at: indexPath)
            let context = GroupViewerItemDecoratorContext(
                isSearchMode: showsSearchResults,
                popoverAnchor: PopoverAnchor.sourceItem(item: cell ?? _collectionView),
                otpDisplayMode: _getOTPDisplayModeForItem(item),
                contentView: cell?.contentView)
            guard let actions = _itemDecorator?.getLeadingSwipeActions(for: item, context: context) else {
                return nil
            }
            return UISwipeActionsConfiguration(actions: actions)
        }

        let layout = UICollectionViewCompositionalLayout { [unowned self]  sectionIndex, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: appearance)
            switch _dataSource.sectionIdentifier(for: sectionIndex) {
            case .announcements:
                config.headerMode = .none
                config.footerMode = .none
            case let .groups(footer),
                 let .entries(footer):
                config.headerMode = .none
                config.footerMode = footer != nil ? .supplementary : .none
                config.leadingSwipeActionsConfigurationProvider = leadingActionsProvider
                config.trailingSwipeActionsConfigurationProvider = trailingActionsProvider
            case let .foundCluster(_, header, footer):
                config.headerMode = header != nil ? .supplementary : .none
                config.footerMode = footer != nil ? .supplementary : .none
                config.leadingSwipeActionsConfigurationProvider = leadingActionsProvider
                config.trailingSwipeActionsConfigurationProvider = trailingActionsProvider
            case .none:
                assertionFailure()
                return nil
            }
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }

        _collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        _collectionView.backgroundColor = .clear
        _collectionView.allowsSelection = true
        _collectionView.allowsFocus = true
        _collectionView.selectionFollowsFocus = true
        _collectionView.allowsMultipleSelectionDuringEditing = true
        _collectionView.allowsMultipleSelection = true
        _collectionView.remembersLastFocusedIndexPath = true
        _collectionView.delegate = self

         _collectionView.dragInteractionEnabled = true
        _collectionView.dragDelegate = self
        _collectionView.dropDelegate = self
        _collectionView.reorderingCadence = .immediate

        view.addSubview(_collectionView)

        _collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            _collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            _collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            _collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            _collectionView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])
    }

    internal func _setupDataSource(appearance: GroupViewerAppearance) {
        let announcementCellRegistration = AnnouncementCollectionCell.makeRegistration(
            appearance: appearance
        )
        let groupCellRegistration = makeGroupCellRegistration()
        let entryCellRegistration = makeEntryCellRegistration()
        let placeholderCellRegistration = makePlaceholderCellRegistration()
        let headerCellRegistration = makeHeaderCellRegistration()
        let footerCellRegistration = makeFooterCellRegistration()

        _dataSource = DataSource(collectionView: _collectionView) {
            collectionView, indexPath, item -> UICollectionViewCell? in
            switch item {
            case .announcement(let announcement):
                return collectionView.dequeueConfiguredReusableCell(
                    using: announcementCellRegistration,
                    for: indexPath,
                    item: announcement)
            case .emptyStatePlaceholder(let text):
                return collectionView.dequeueConfiguredReusableCell(
                    using: placeholderCellRegistration,
                    for: indexPath,
                    item: text)
            case .group(let group):
                return collectionView.dequeueConfiguredReusableCell(
                    using: groupCellRegistration,
                    for: indexPath,
                    item: group)
            case .entry(let entry):
                return collectionView.dequeueConfiguredReusableCell(
                    using: entryCellRegistration,
                    for: indexPath,
                    item: entry)
            }
        }
        _dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            switch kind {
            case UICollectionView.elementKindSectionHeader:
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: headerCellRegistration,
                    for: indexPath)
            case UICollectionView.elementKindSectionFooter:
                return collectionView.dequeueConfiguredReusableSupplementary(
                    using: footerCellRegistration,
                    for: indexPath)
            default:
                return nil
            }
        }
        _dataSource.reorderingHandlers.canReorderItem = _canReorderItem
        _dataSource.reorderingHandlers.didReorder = _didReorderItems
    }

    private func makeGroupCellRegistration() -> UICollectionView.CellRegistration<GroupViewerGroupCell, Group> {
        UICollectionView.CellRegistration<GroupViewerGroupCell, Group> {
            [weak self] cell, indexPath, group in
            guard let self else { return }
            let context = GroupViewerItemDecoratorContext(
                isSearchMode: showsSearchResults,
                popoverAnchor: cell.asPopoverAnchor,
                otpDisplayMode: _getOTPDisplayModeForItem(group),
                contentView: cell.contentView)
            let accessories = _itemDecorator?.getAccessories(for: group, context: context)
            let accessibilityActions = _itemDecorator?.getAccessibilityActions(for: group, context: context)
            cell.configure(with: group, accessories: accessories)
            cell.accessibilityCustomActions = accessibilityActions ?? []
        }
    }

    private func makeEntryCellRegistration() -> UICollectionView.CellRegistration<GroupViewerEntryCell, Entry> {
        UICollectionView.CellRegistration<GroupViewerEntryCell, Entry> {
            [weak self] cell, indexPath, entry in
            guard let self else { return }
            let context = GroupViewerItemDecoratorContext(
                isSearchMode: showsSearchResults,
                popoverAnchor: cell.asPopoverAnchor,
                otpDisplayMode: _getOTPDisplayModeForItem(entry),
                contentView: cell.contentView)
            let accessories = _itemDecorator?.getAccessories(for: entry, context: context)
            let accessibilityActions = _itemDecorator?.getAccessibilityActions(for: entry, context: context)
            cell.configure(with: entry, accessories: accessories)
            cell.accessibilityCustomActions = accessibilityActions ?? []
        }
    }

    private func makePlaceholderCellRegistration() ->
        UICollectionView.CellRegistration<UICollectionViewListCell, String>
    {
        return UICollectionView.CellRegistration<UICollectionViewListCell, String> {
            cell, indexPath, value in
            var content = UIListContentConfiguration.cell()
            content.text = value
            content.textProperties.color = .secondaryLabel
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
        }
    }

    private func makeHeaderCellRegistration() ->
        UICollectionView.SupplementaryRegistration<UICollectionViewListCell>
    {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) {
            [weak self] supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            guard let section = self?._dataSource.sectionIdentifier(for: indexPath.section) else {
                assertionFailure()
                return
            }
            content.text = section.headerTitle
            supplementaryView.contentConfiguration = content
        }
    }

    private func makeFooterCellRegistration() ->
        UICollectionView.SupplementaryRegistration<UICollectionViewListCell>
    {
        return UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) {
            [weak self] supplementaryView, elementKind, indexPath in
            var content = supplementaryView.defaultContentConfiguration()
            guard let section = self?._dataSource.sectionIdentifier(for: indexPath.section) else {
                assertionFailure()
                return
            }
            content.text = section.footerText
            content.textProperties.alignment = .center
            content.textProperties.font = .preferredFont(forTextStyle: .footnote)
            supplementaryView.contentConfiguration = content
        }
    }
}
