//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class CollectionViewControllerWithContextActions: UICollectionViewController {

    func getContextActionsForItem(at indexPath: IndexPath) -> [ContextualAction] {
        return []
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        canEditItemAt indexPath: IndexPath
    ) -> Bool {
        let itemActions = getContextActionsForItem(at: indexPath)
        return itemActions.count > 0
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let menuActions = getContextActionsForItem(at: indexPath)
            .map { $0.toMenuAction() }

        guard menuActions.count > 0 else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            return UIMenu(title: "", children: menuActions)
        }
    }
}
