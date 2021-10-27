//  KeePassium Password Manager
//  Copyright © 2018–2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension UIMenu {
    public static func makeFileSortMenu(
        current: Settings.FilesSortOrder,
        handler: @escaping (Settings.FilesSortOrder) -> Void
    ) -> UIMenu {
        let sortByNone = UIAction(
            title: LString.titleSortByNone,
            attributes: [],
            state: (current == .noSorting) ? .on : .off,
            handler: { _ in
                handler(.noSorting)
            }
        )
        
        let sortByName = makeFileSortAction(
            title: LString.titleSortByFileName,
            current: current,
            ascending: .nameAsc,
            descending: .nameDesc,
            handler: handler
        )
        let sortByDateCreated = makeFileSortAction(
            title: LString.titleSortByDateCreated,
            current: current,
            ascending: .creationTimeAsc,
            descending: .creationTimeDesc,
            handler: handler
        )
        let sortByDateModified = makeFileSortAction(
            title: LString.titleSortByDateModified,
            current: current,
            ascending: .modificationTimeAsc,
            descending: .modificationTimeDesc,
            handler: handler
        )

        return UIMenu(
            title: LString.titleSortBy,
            options: .displayInline,
            children: [sortByNone, sortByName, sortByDateCreated, sortByDateModified].reversed()
        )
    }
    
    private static func makeFileSortAction(
        title: String,
        current: Settings.FilesSortOrder,
        ascending: Settings.FilesSortOrder,
        descending: Settings.FilesSortOrder,
        handler: @escaping (Settings.FilesSortOrder) -> Void
    ) -> UIAction {
        switch current {
        case ascending:
            return UIAction(
                title: title,
                image: UIImage.get(.chevronUp),
                attributes: [],
                state: .on,
                handler: { _ in handler(descending) }
            )
        case descending:
            return UIAction(
                title: title,
                image: UIImage.get(.chevronDown),
                attributes: [],
                state: .on,
                handler: { _ in handler(ascending) }
            )
        default:
            return UIAction(
                title: title,
                image: nil,
                attributes: [],
                state: .off,
                handler: { _ in
                    if current.isAscending ?? true {
                        handler(ascending)
                    } else {
                        handler(descending)
                    }
                }
            )
        }
    }
}
