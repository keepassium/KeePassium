//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension DatabasePickerCoordinator {
    func buildMenu(with builder: any UIMenuBuilder, isDatabaseShown: Bool) {
        if !isDatabaseShown {
            builder.insertChild(makeFileSortOrderMenu(), atEndOfMenu: .view)
        }
    }

    private func makeFileSortOrderMenu() -> UIMenu {
        let actions = UIMenu.makeFileSortMenuItems(current: Settings.current.filesSortOrder) {
            [weak self] newSortOrder in
            Settings.current.filesSortOrder = newSortOrder
            self?.refresh()
            UIMenu.rebuildMainMenu()
        }
        return UIMenu(
            title: LString.titleSortFilesBy,
            identifier: .fileSortOrder,
            options: .singleSelection,
            children: actions
        )
    }
}
