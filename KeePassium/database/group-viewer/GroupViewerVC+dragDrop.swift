//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import UniformTypeIdentifiers

extension GroupViewerVC: UICollectionViewDragDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        dragSessionIsRestrictedToDraggingApplication session: any UIDragSession
    ) -> Bool {
        true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: any UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard let item = _dataSource.itemIdentifier(for: indexPath),
              let dragItem = asDragItem(item)
        else { return [] }
        return [dragItem]
    }

    func collectionView(
        _ collectionView: UICollectionView,
        itemsForAddingTo session: any UIDragSession,
        at indexPath: IndexPath,
        point: CGPoint
    ) -> [UIDragItem] {
        guard let item = _dataSource.itemIdentifier(for: indexPath),
              let dragItem = asDragItem(item)
        else {
            return []
        }
        return [dragItem]
    }

    private func asDragItem(_ item: Item) -> UIDragItem? {
        guard let delegate else { return nil }
        switch item {
        case .announcement, .emptyStatePlaceholder:
            return nil
        case .group(let group):
            let canRelocateItem = delegate.shouldAllowDragRelocation(of: group, into: nil, in: self)
            guard _canReorderItem(item) || canRelocateItem else {
                return nil
            }
        case .entry(let entry):
            let canRelocateItem = delegate.shouldAllowDragRelocation(of: entry, into: nil, in: self)
            guard _canReorderItem(item) || canRelocateItem else {
                return nil
            }
        }
        let provider = NSItemProvider(object: "" as NSString)
        let dragItem = UIDragItem(itemProvider: provider)
        dragItem.localObject = item
        return dragItem
    }
}

extension GroupViewerVC: UICollectionViewDropDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        canHandle session: UIDropSession
    ) -> Bool {
        if session.localDragSession != nil {
            return true
        }
        return session.hasItemsConforming(toTypeIdentifiers: [UTType.item.identifier])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        let inSameVC = collectionView.hasActiveDrag

        if session.localDragSession == nil {
            guard let destinationIndexPath,
                  let targetItem = _dataSource.itemIdentifier(for: destinationIndexPath),
                  case .entry(let entry) = targetItem
            else {
                return UICollectionViewDropProposal(operation: .cancel)
            }
            if delegate?.canDropFiles(session.items, onto: entry, in: self) ?? false {
                return UICollectionViewDropProposal(operation: .copy, intent: .insertIntoDestinationIndexPath)
            } else {
                return UICollectionViewDropProposal(operation: .forbidden)
            }
        }

        guard let destinationIndexPath,
              let targetItem = _dataSource.itemIdentifier(for: destinationIndexPath)
        else {
            if inSameVC {
                return UICollectionViewDropProposal(operation: .cancel)
            }
            let sourceItems = session.items.map { $0.localObject as! Item }
            if let intent = getMoveIntent(for: sourceItems, to: _group) {
                return UICollectionViewDropProposal(operation: .move, intent: intent)
            }
            return UICollectionViewDropProposal(operation: .cancel)
        }

        switch targetItem {
        case .announcement, .emptyStatePlaceholder:
            return UICollectionViewDropProposal(operation: .cancel)
        case .group, .entry:
            break
        }

        if session.items.count == 1 {
            let sourceItem = session.items.first!.localObject as! Item
            if let intent = guessMoveIntent(for: sourceItem, to: targetItem, inSameVC: inSameVC) {
                return UICollectionViewDropProposal(operation: .move, intent: intent)
            }
        } else{
            let sourceItems = session.items.map { $0.localObject as! Item }
            if let intent = guessMoveIntent(for: sourceItems, to: targetItem, inSameVC: inSameVC) {
                return UICollectionViewDropProposal(operation: .move, intent: intent)
            }
        }
        return UICollectionViewDropProposal(operation: .cancel)
    }

    private func guessMoveIntent(
        for sourceItem: Item,
        to targetItem: Item,
        inSameVC: Bool
    ) -> UICollectionViewDropProposal.Intent? {
        guard let delegate else { return nil }
        switch (sourceItem, targetItem) {
        case let (.entry(sourceEntry), .entry):
            if inSameVC {
                if _canReorderItem(sourceItem) {
                    return .insertAtDestinationIndexPath
                }
            } else {
                if delegate.shouldAllowDragRelocation(of: sourceEntry, into: _group, in: self) {
                    return .unspecified
                }
            }
        case let (.group(sourceGroup), .entry):
            if inSameVC {
                return nil
            } else {
                if delegate.shouldAllowDragRelocation(of: sourceGroup, into: _group, in: self) {
                    return .unspecified
                }
            }
        case let (.entry(sourceEntry), .group(targetGroup)):
            if delegate.shouldAllowDragRelocation(of: sourceEntry, into: targetGroup, in: self) {
                return .insertIntoDestinationIndexPath
            }
        case let (.group(sourceGroup), .group(targetGroup)):
            if inSameVC && _canReorderItem(sourceItem) {
                return .insertAtDestinationIndexPath
            }
            let isSameGroup = (sourceGroup.runtimeUUID == targetGroup.runtimeUUID)
            if delegate.shouldAllowDragRelocation(of: sourceGroup, into: targetGroup, in: self)
                && !isSameGroup
            {
                return .insertIntoDestinationIndexPath
            }
        default:
            assertionFailure()
        }
        return nil
    }

    private func guessMoveIntent(
        for sourceItems: [Item],
        to targetItem: Item,
        inSameVC: Bool
    ) -> UICollectionViewDropProposal.Intent? {
        var sourceHasEntries = false
        var sourceHasGroups = false
        sourceItems.forEach {
            if case .group = $0 {
                sourceHasGroups = true
            } else if case .entry = $0 {
                sourceHasEntries = true
            }
        }

        switch (sourceHasGroups, sourceHasEntries, targetItem) {
        case (false, true, .entry):
            if inSameVC {
                return nil
            } else {
                if canRelocateAll(sourceItems, into: self._group) {
                    return .unspecified
                }
            }
        case (true, _, .entry):
            return nil
        case (_, _, .group(let targetGroup)):
            if sourceItems.contains(targetItem) {
                return nil
            }
            if canRelocateAll(sourceItems, into: targetGroup) {
                return .insertIntoDestinationIndexPath
            }
        case (_, _, .announcement),
             (_, _, .emptyStatePlaceholder):
            assertionFailure()
        case (false, false, _):
            assertionFailure("What are you dragging?")
        }
        return nil
    }

    private func getMoveIntent(
        for sourceItems: [Item],
        to targetGroup: Group
    ) -> UICollectionViewDropProposal.Intent? {
        if canRelocateAll(sourceItems, into: targetGroup) {
            return .unspecified
        } else {
            return nil
        }
    }

    private func canRelocateAll(_ sourceItems: [Item], into targetGroup: Group) -> Bool {
        guard let delegate else { assertionFailure(); return false }
        let result = sourceItems.allSatisfy {
            switch $0 {
            case .announcement, .emptyStatePlaceholder:
                fatalError()
            case let .group(group):
                return delegate.shouldAllowDragRelocation(of: group, into: targetGroup, in: self)
            case let .entry(entry):
                return delegate.shouldAllowDragRelocation(of: entry, into: targetGroup, in: self)
            }
        }
        return result
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: any UICollectionViewDropCoordinator
    ) {
        let inSameVC = collectionView.hasActiveDrag

        let targetGroup: Group
        switch (coordinator.proposal.operation, coordinator.proposal.intent) {
        case (.copy, _):
            guard let destinationIndexPath = coordinator.destinationIndexPath,
                  let targetItem = _dataSource.itemIdentifier(for: destinationIndexPath),
                  case .entry(let entry) = targetItem
            else {
                Diag.warning("External file drop has no valid entry destination")
                return
            }
            delegate?.didDropFiles(coordinator.items.map(\.dragItem), onto: entry, in: self)
            return
        case (.move, .insertIntoDestinationIndexPath):
            guard let destinationIndexPath = coordinator.destinationIndexPath,
                  let destinationItem = _dataSource.itemIdentifier(for: destinationIndexPath)
            else {
                assertionFailure("No destination for drop")
                return
            }
            guard case let .group(destinationGroup) = destinationItem else {
                assertionFailure("Destination item is not a group")
                return
            }
            targetGroup = destinationGroup
        case (.move, .unspecified):
            targetGroup = self._group
        case (.move, .insertAtDestinationIndexPath):
            if inSameVC {
                assertionFailure("Same-group reordering should have been handled by collection's dropDelegate")
                return
            } else {
                targetGroup = self._group
            }
        default:
            assertionFailure("Unexpected operation/intent")
            return
        }

        let sourceListItems = coordinator.items.map { $0.dragItem.localObject as! Item }
        let sourceDatabaseItems = sourceListItems.compactMap { (listItem: Item) -> DatabaseItem? in
            switch listItem {
            case .announcement, .emptyStatePlaceholder:
                assertionFailure()
                return nil
            case .group(let group):
                return group
            case .entry(let entry):
                return entry
            }
        }
        delegate?.didDragItems(sourceDatabaseItems, into: targetGroup)
    }

}
