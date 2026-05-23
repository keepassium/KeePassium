//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabaseViewerCoordinator {
    internal func _pushInitialGroupViewers(replacingTopVC: Bool) {
        guard let initialGroupUUID = _initialGroupUUID,
              let initialGroup = _database.root?.findGroup(byUUID: initialGroupUUID)
        else {
            guard let rootGroup = _database.root else {
                Diag.error("No root group found in database")
                assertionFailure()
                return
            }
            _pushGroupViewer(for: rootGroup, replacingTopVC: replacingTopVC, animated: true)
            _maybeActivateInitialSearch()
            return
        }

        var groupStack = [Group]()
        var currentGroup: Group? = initialGroup
        while let subgroup = currentGroup {
            groupStack.append(subgroup)
            currentGroup = currentGroup?.parent
        }
        groupStack.reverse()

        let rootGroup = groupStack.removeFirst()
        _pushGroupViewer(for: rootGroup, replacingTopVC: replacingTopVC, animated: false)

        groupStack.forEach { subgroup in
            DispatchQueue.main.async { [self] in
                _pushGroupViewer(for: subgroup, animated: false)
            }
        }
        _maybeActivateInitialSearch()
    }

    internal func _pushGroupViewer(for group: Group, replacingTopVC: Bool = false, animated: Bool) {
        if let previousGroupViewer = _groupViewers.last {
            previousGroupViewer.setEditing(false, animated: animated)
            _searchQuery = nil
            _updateData(searchQuery: nil)
            DispatchQueue.main.async {
                previousGroupViewer.cancelSearch()
            }
        }

        let previousGroup = _currentGroup
        _currentGroup = group

        group.touch(.accessed)
        let groupViewerVC = GroupViewerVC(
            group: group,
            itemDecorator: ItemDecorator(coordinator: self),
            toolbarDecorator: ToolbarDecorator(for: group, coordinator: self),
            emptySpaceDecorator: EmptySpaceDecorator(
                permissions: _currentGroupPermissions,
                coordinator: self
            )
        )
        groupViewerVC.delegate = self
        _groupViewers.append(groupViewerVC)

        let isCustomTransition = replacingTopVC && animated
        if isCustomTransition {
            _primaryRouter.prepareCustomTransition(
                duration: vcAnimationDuration,
                type: .fade,
                timingFunction: .easeOut
            )
        }
        _primaryRouter.push(
            groupViewerVC,
            animated: animated && !isCustomTransition,
            replaceTopViewController: replacingTopVC,
            onPop: { [weak self, weak groupViewerVC] in
                guard let self else { return }
                self._currentGroup = previousGroup
                let removedVC = _groupViewers.removeLast()
                assert(removedVC === groupViewerVC)
                if _groupViewers.isEmpty {
                    _showEntry(nil)
                    _dismissHandler?(self)
                    delegate?.didLeaveDatabase(in: self)
                } else {
                    refresh(animated: false)
                }
                UIMenu.rebuildMainMenu()
            }
        )

        refresh(animated: animated)
        UIMenu.rebuildMainMenu()
    }

    internal func _showGroupContent(_ group: Group, in groupViewerVC: GroupViewerVC) {
        guard group.isSmartGroup else {
            groupViewerVC.setStandardGroupContents(groups: group.groups, entries: group.entries)
            return
        }

        let query = group.smartGroupQuery
        assert(query.isNotEmpty, "A smart group without a query?")
        let searchResults = _searchHelper.findEntriesAndGroups(
            in: _database,
            searchText: query,
            onlyAutoFillable: false,
            excludeGroupUUID: group.uuid
        )
        groupViewerVC.setSmartGroupContents(
            searchResults,
            prominentOTPs: isOTPSmartGroup(group, searchResults: searchResults)
        )
    }

    private func isOTPSmartGroup(_ group: Group, searchResults: SearchResults) -> Bool {
        guard group.isSmartGroup else {
            return false
        }
        if group.notes == "otp:*" {
            return true
        }

        let itemsFoundCount = searchResults.reduce(0) { currentCount, groupedItem in
            currentCount + groupedItem.scoredItems.count
        }
        let maxNonOTPItems = Int(0.1 * Double(itemsFoundCount))
        var nonOTPItems = 0
        for groupedItems in searchResults {
            for scoredItem in groupedItems.scoredItems {
                if let entry2 = scoredItem.item as? Entry2,
                   entry2.hasValidTOTP
                {
                    continue
                } else {
                    nonOTPItems += 1
                }
                if nonOTPItems > maxNonOTPItems {
                    return false
                }
            }
        }
        return true
    }
}

extension DatabaseViewerCoordinator {
    internal func _showGroupEditor(_ mode: GroupEditorCoordinator.Mode) {
        _primaryRouter.dismissModals(animated: true) { [self] in
            _showGroupEditor(mode, at: nil)
        }
    }

    private func _showGroupEditor(_ mode: GroupEditorCoordinator.Mode, at popoverAnchor: PopoverAnchor?) {
        Diag.info("Will edit group")
        guard let parent = _currentGroup else {
            Diag.warning("Parent group is not defined")
            assertionFailure()
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet, at: popoverAnchor)
        let groupEditorCoordinator = GroupEditorCoordinator(
            router: modalRouter,
            databaseFile: _databaseFile,
            parent: parent,
            mode: mode
        )
        groupEditorCoordinator.delegate = self
        groupEditorCoordinator.start()

        _presenterForModals.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(groupEditorCoordinator, onDismiss: nil)
    }
}

extension DatabaseViewerCoordinator {
    internal func _confirmAndDeleteGroup(_ group: Group, at popoverAnchor: PopoverAnchor) {
        let alert = UIAlertController.make(
            title: group.name,
            message: nil,
            dismissButtonTitle: LString.actionCancel
        )
        alert.addAction(title: LString.actionDelete, style: .destructive) { [weak self, weak group] _ in
            guard let self, let group else { return }
            _deleteGroupConfirmed(group)
        }
        alert.modalPresentationStyle = .popover
        popoverAnchor.apply(to: alert.popoverPresentationController)
        let presenter = _topGroupViewer ?? _presenterForModals
        presenter.present(alert, animated: true)
    }

    private func _deleteGroupConfirmed(_ group: Group) {
        _database.delete(group: group)
        group.touch(.accessed)
        saveDatabase(_databaseFile)
    }

    internal func _confirmAndEmptyRecycleBinGroup(_ recycleBin: Group, at popoverAnchor: PopoverAnchor) {
        let alert = UIAlertController.make(
            title: LString.confirmEmptyRecycleBinGroup,
            message: nil,
            dismissButtonTitle: LString.actionCancel
        )
        alert.addAction(title: LString.actionEmptyRecycleBinGroup, style: .destructive) {
            [weak self, weak recycleBin] _ in
            guard let self, let recycleBin else { return }
            emptyRecycleBinGroupConfirmed(recycleBin)
        }
        alert.modalPresentationStyle = .popover
        popoverAnchor.apply(to: alert.popoverPresentationController)
        let presenter = _topGroupViewer ?? _presenterForModals
        presenter.present(alert, animated: true)
    }

    private func emptyRecycleBinGroupConfirmed(_ recycleBinGroup: Group) {
        recycleBinGroup.groups.forEach {
            _database.delete(group: $0)
        }
        recycleBinGroup.entries.forEach {
            _database.delete(entry: $0)
        }
        recycleBinGroup.touch(.accessed)
        saveDatabase(_databaseFile)
    }
}

extension DatabaseViewerCoordinator: GroupViewerVC.Delegate {
    func didChangeSearchQuery(_ text: String?, in viewController: GroupViewerVC) {
        _didChangeSearchQuery(text, in: viewController)
    }

    func didSelectGroup(
        _ group: Group,
        cause: ItemActivationCause?,
        in viewController: GroupViewerVC
    ) -> Bool {
        if cause != nil {
            _pushGroupViewer(for: group, animated: true)
            return false
        } else {
            return true
        }
    }

    func didSelectEntry(
        _ entry: Entry,
        cause: ItemActivationCause?,
        in viewController: GroupViewerVC
    ) -> Bool {
        if cause != nil {
            _selectEntry(entry)

            let shouldRemainSelected = !_splitViewController.isCollapsed
            return shouldRemainSelected
        } else {
            _showEntry(entry)
            return true
        }
    }

    func didReorderItems(
        of group: Group,
        groups: [Group],
        entries: [Entry],
        in viewController: GroupViewerVC
    ) {
        let areGroupsReordered = !group.groups.elementsEqual(groups, by: { $0.runtimeUUID == $1.runtimeUUID })
        let areEntriesReordered = !group.entries.elementsEqual(entries, by: { $0.runtimeUUID == $1.runtimeUUID })
        guard areGroupsReordered || areEntriesReordered else {
            return
        }
        group.touch(.modified)
        group.groups = groups
        group.entries = entries
        _hasUnsavedBulkChanges = true
        if viewController.isEditing {
            DispatchQueue.main.async {
                self.refresh()
            }
        } else {
            _saveUnsavedBulkChanges(onSuccess: nil)
        }
    }

    func shouldAllowBulkSelection(in viewController: GroupViewerVC) -> Bool {
        return _currentGroupPermissions.contains(.selectItems)
    }

    func shouldAllowReorder(in viewController: GroupViewerVC) -> Bool {
        return _canReorderItems
    }

    func shouldAllowDragRelocation(
        of databaseItem: DatabaseItem,
        into group: Group? = nil,
        in viewController: GroupViewerVC
    ) -> Bool {
        return _canMoveItem(databaseItem, to: group)
    }

    internal func _canMoveItem(_ databaseItem: DatabaseItem, to group: Group? = nil) -> Bool {
        let permissions = DatabaseViewerPermissionManager.getPermissions(for: databaseItem, in: _databaseFile)
        guard permissions.contains(.moveItem) else {
            return false
        }

        if let group {
            return group.isAllowedDestination(for: databaseItem)
        }
        return true
    }

    func canDropFiles(_ files: [UIDragItem], onto entry: Entry, in viewController: GroupViewerVC) -> Bool {
        return _canDropFiles(files, onto: entry, in: viewController)
    }

    func didDropFiles(_ files: [UIDragItem], onto entry: Entry, in viewController: GroupViewerVC) {
        _didDropFiles(files, onto: entry, in: viewController)
    }

    internal func _canDeleteItem(_ databaseItem: DatabaseItem) -> Bool {
        let permissions = DatabaseViewerPermissionManager.getPermissions(for: databaseItem, in: _databaseFile)
        return permissions.contains(.deleteItem)
    }
}

extension DatabaseViewerCoordinator: GroupEditorCoordinatorDelegate {
    func didUpdateGroup(_ group: Group, in coordinator: GroupEditorCoordinator) {
        refresh()
        StoreReviewSuggester.maybeShowAppReview(
            appVersion: AppInfo.version,
            occasion: .didEditItem,
            presenter: UIApplication.shared.currentActiveScene
        )
    }
}
