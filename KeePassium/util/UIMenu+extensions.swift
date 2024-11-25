//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension Notification.Name {
    static let reloadToolbar = Notification.Name("com.keepassium.toolbar.reloadToolbar")
}

extension UIMenu {
    convenience init(
        title: String = "",
        subtitle: String? = nil,
        image: UIImage? = nil,
        identifier: Identifier? = nil,
        options: Options = [],
        preferredElementSize: ElementSize = .automatic,
        inlineChildren: [UIMenuElement]
    ) {
        self.init(
            title: title,
            subtitle: subtitle,
            image: image,
            identifier: identifier,
            options: options.union(.displayInline),
            preferredElementSize: preferredElementSize,
            children: inlineChildren
        )
    }

    static func rebuildMainMenu() {
        UIMenuSystem.main.setNeedsRebuild()
        NotificationCenter.default.post(name: .reloadToolbar, object: nil)
    }

    public static func make(
        title: String = "",
        subtitle: String? = nil,
        reverse: Bool = false,
        options: UIMenu.Options = [],
        macOptions: UIMenu.Options? = nil,
        children: [UIMenuElement]
    ) -> UIMenu {
        if ProcessInfo.isRunningOnMac {
            return UIMenu(
                title: title,
                subtitle: subtitle,
                options: macOptions ?? options,
                children: children)
        } else {
            return UIMenu(
                title: title,
                subtitle: subtitle,
                options: options,
                children: reverse ? children.reversed() : children)
        }
    }

    public static func makeFileSortMenuItems(
        current: Settings.FilesSortOrder,
        handler: @escaping (Settings.FilesSortOrder) -> Void
    ) -> [UIMenuElement] {
        let sortOrderCustom = UIAction(
            title: Settings.FilesSortOrder.noSorting.title,
            attributes: [],
            state: (current == .noSorting) ? .on : .off,
            handler: { _ in
                handler(.noSorting)
            }
        )

        let sortByName = makeFileSortAction(
            title: Settings.FilesSortOrder.nameAsc.title,
            current: current,
            ascending: .nameAsc,
            descending: .nameDesc,
            handler: handler
        )
        let sortByDateCreated = makeFileSortAction(
            title: Settings.FilesSortOrder.creationTimeAsc.title,
            current: current,
            ascending: .creationTimeAsc,
            descending: .creationTimeDesc,
            handler: handler
        )
        let sortByDateModified = makeFileSortAction(
            title: Settings.FilesSortOrder.modificationTimeAsc.title,
            current: current,
            ascending: .modificationTimeAsc,
            descending: .modificationTimeDesc,
            handler: handler
        )

        return [sortOrderCustom, sortByName, sortByDateCreated, sortByDateModified]
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
                image: ProcessInfo.isRunningOnMac ? nil : .symbol(.chevronUp),
                attributes: [],
                state: .on,
                handler: { _ in handler(descending) }
            )
        case descending:
            return UIAction(
                title: title,
                image: ProcessInfo.isRunningOnMac ? nil : .symbol(.chevronDown),
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

    public static func makeDatabaseItemSortMenuItems(
        current: Settings.GroupSortOrder,
        reorderAction: UIAction?,
        handler: @escaping (Settings.GroupSortOrder) -> Void
    ) -> [UIMenuElement] {
        let sortOrderCustom = UIAction(
            title: Settings.GroupSortOrder.noSorting.title,
            attributes: [],
            state: (current == .noSorting) ? .on : .off,
            handler: { _ in
                handler(.noSorting)
            }
        )

        let sortByItemTitle = makeGroupSortAction(
            title: Settings.GroupSortOrder.nameAsc.title,
            current: current,
            ascending: .nameAsc,
            descending: .nameDesc,
            handler: handler
        )
        let sortByDateCreated = makeGroupSortAction(
            title: Settings.GroupSortOrder.creationTimeAsc.title,
            current: current,
            ascending: .creationTimeAsc,
            descending: .creationTimeDesc,
            handler: handler
        )
        let sortByDateModified = makeGroupSortAction(
            title: Settings.GroupSortOrder.modificationTimeAsc.title,
            current: current,
            ascending: .modificationTimeAsc,
            descending: .modificationTimeDesc,
            handler: handler
        )
        var result: [UIMenuElement] = [sortByItemTitle, sortByDateCreated, sortByDateModified, sortOrderCustom]
        if let reorderAction {
            result.append(UIMenu.make(options: .displayInline, children: [reorderAction]))
        }
        return result
    }

    private static func makeGroupSortAction(
        title: String,
        current: Settings.GroupSortOrder,
        ascending: Settings.GroupSortOrder,
        descending: Settings.GroupSortOrder,
        handler: @escaping (Settings.GroupSortOrder) -> Void
    ) -> UIAction {
        switch current {
        case ascending:
            return UIAction(
                title: title,
                image: ProcessInfo.isRunningOnMac ? nil : .symbol(.chevronUp),
                attributes: [],
                state: .on,
                handler: { _ in handler(descending) }
            )
        case descending:
            return UIAction(
                title: title,
                image: ProcessInfo.isRunningOnMac ? nil : .symbol(.chevronDown),
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
