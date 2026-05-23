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
    override var keyCommands: [UIKeyCommand]? {
        let searchKey = UIKeyCommand(action: #selector(didPressSearch), hotkey: .search)

        let enterKey = UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(_didPressEnter))
        enterKey.wantsPriorityOverSystemBehavior = true

        return [searchKey, enterKey] + (super.keyCommands ?? [])
    }

    @objc private func didPressSearch() {
        activateManualSearch()
    }

    @objc internal func _didPressEnter() {
        if let selectedIndexPath = _collectionView.indexPathsForSelectedItems?.first {
            _handlePrimaryAction(at: selectedIndexPath, cause: .keyPress)
            return
        }

        guard let indexPath = getFirstSelectableIndexPath() else { return }
        _collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        _collectionView.cellForItem(at: indexPath)?.becomeFirstResponder()
    }

    override func selectAll(_ sender: Any?) {
        guard isBulkSelectionAllowed else {
            return
        }
        let indexPathsToSelect = selectableIndexPaths
        guard !indexPathsToSelect.isEmpty else {
            return
        }
        if !isEditing {
            setEditing(true, animated: false)
        }
        deselectAllItems()
        indexPathsToSelect.forEach {
            _collectionView.selectItem(at: $0, animated: false, scrollPosition: [])
        }
        _updateToolbars(animated: true)
    }

    private var isBulkSelectionAllowed: Bool {
        return delegate?.shouldAllowBulkSelection(in: self) ?? false
    }

    private var selectableIndexPaths: [IndexPath] {
        let snapshot = _dataSource.snapshot()
        return snapshot.itemIdentifiers.compactMap { item in
            guard _isSelectableItem(item) else {
                return nil
            }
            return _dataSource.indexPath(for: item)
        }
    }

    private func deselectAllItems() {
        _collectionView.indexPathsForSelectedItems?.forEach {
            _collectionView.deselectItem(at: $0, animated: false)
        }
    }

    internal func _handlePrimaryAction(at indexPath: IndexPath, cause: ItemActivationCause?) {
        guard let selectedItem = _dataSource.itemIdentifier(for: indexPath) else {
            assertionFailure()
            return
        }
        var keepSelected = false
        switch selectedItem {
        case .announcement, .emptyStatePlaceholder:
            assertionFailure("This item should not be selectable")
            return
        case .group(let group):
            keepSelected = delegate?.didSelectGroup(group, cause: cause, in: self) ?? false
        case let .entry(entry):
            keepSelected = delegate?.didSelectEntry(entry, cause: cause, in: self) ?? false
        }
        if !keepSelected {
            _collectionView.deselectItem(at: indexPath, animated: true)
        }
    }

    internal func _isSelectableItem(_ item: Item?) -> Bool {
        switch item {
        case .announcement, .emptyStatePlaceholder:
            return false
        case .group, .entry:
            return true
        case .none:
            return false
        }
    }

    internal func _isSelectableCell(at indexPath: IndexPath) -> Bool {
        return _isSelectableItem(_dataSource.itemIdentifier(for: indexPath))
    }

    private func getFirstSelectableIndexPath() -> IndexPath? {
        let snapshot = _dataSource.snapshot()
        guard let selectableItem = snapshot.itemIdentifiers.first(where: { _isSelectableItem($0) }),
              let result = _dataSource.indexPath(for: selectableItem)
        else {
            return nil
        }
        return result
    }
}

extension GroupViewerVC: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        if isEditing {
            return false
        } else {
            return _isSelectableCell(at: indexPath)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        return _isSelectableCell(at: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        canPerformPrimaryActionForItemAt indexPath: IndexPath
    ) -> Bool {
        if isEditing {
            return false
        } else {
            return _isSelectableCell(at: indexPath)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        _updateToolbars(animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        _updateToolbars(animated: true)
        if isInSinglePanelMode {
            return
        }

        var keepSelected = false
        switch _dataSource.itemIdentifier(for: indexPath) {
        case .announcement, .emptyStatePlaceholder:
            return
        case .group(let group):
            if isEditing {
                keepSelected = true
            } else {
                keepSelected = delegate?.didSelectGroup(group, cause: nil, in: self) ?? false
            }
        case .entry(let entry):
            if isEditing {
                keepSelected = true
            } else {
                keepSelected = delegate?.didSelectEntry(entry, cause: nil, in: self) ?? false
            }
        case .none:
            assertionFailure()
            return
        }
        if !keepSelected {
            _collectionView.deselectItem(at: indexPath, animated: true)
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performPrimaryActionForItemAt indexPath: IndexPath
    ) {
        _handlePrimaryAction(at: indexPath, cause: .touch)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
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
        guard let itemMenu = _itemDecorator?.getContextMenu(for: item, context: context) else {
            return nil
        }
        return UIContextMenuConfiguration(actionProvider: { _ in itemMenu })
    }
}
