//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

struct GroupViewerItemDecoratorContext {
    var isSearchMode: Bool
    var popoverAnchor: PopoverAnchor
    var otpDisplayMode: OTPDisplayMode
    weak var contentView: UIView?
}

protocol GroupViewerItemDecorator: AnyObject {
    typealias Item = GroupViewerItem
    typealias Context = GroupViewerItemDecoratorContext

    func getLeadingSwipeActions(
        for item: Item,
        context: Context
    ) -> [UIContextualAction]?

    func getTrailingSwipeActions(
        for item: Item,
        context: Context
    ) -> [UIContextualAction]?

    func getAccessories(for item: Item, context: Context) -> [UICellAccessory]?
    func getAccessories(for group: Group, context: Context) -> [UICellAccessory]?
    func getAccessories(for entry: Entry, context: Context) -> [UICellAccessory]?

    func getContextMenu(for item: Item, context: Context) -> UIMenu?

    func getAccessibilityActions(for item: Item, context: Context) -> [UIAccessibilityCustomAction]?
    func getAccessibilityActions(for group: Group, context: Context) -> [UIAccessibilityCustomAction]?
    func getAccessibilityActions(for entry: Entry, context: Context) -> [UIAccessibilityCustomAction]?
}
