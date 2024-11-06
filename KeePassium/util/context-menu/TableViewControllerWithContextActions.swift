//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class TableViewControllerWithContextActions: UITableViewController {

    func getContextActionsForRow(at indexPath: IndexPath, forSwipe: Bool) -> [ContextualAction] {
        return []
    }


    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        let rowActions = getContextActionsForRow(at: indexPath, forSwipe: true)
        return rowActions.count > 0
    }

    override func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        let swipeActions = getContextActionsForRow(at: indexPath, forSwipe: true)
            .sorted { ($0.style == .destructive) && ($0.style != $1.style) }
            .map { $0.toContextualAction(tableView: tableView) }
        guard swipeActions.count > 0 else {
            return nil
        }
        return UISwipeActionsConfiguration(actions: swipeActions)
    }

    override func tableView(
        _ tableView: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {
        let menuActions = getContextActionsForRow(at: indexPath, forSwipe: false)
            .map { $0.toMenuAction() }

        guard menuActions.count > 0 else {
            return nil
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            return UIMenu(title: "", children: menuActions)
        }
    }
}
