//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

enum PopoverAnchor {
    case sourceItem(item: UIPopoverPresentationControllerSourceItem)
    case viewRect(view: UIView, rect: CGRect)

    public func apply(to popover: UIPopoverPresentationController?) {
        guard let popover else { return }
        switch self {
        case .sourceItem(let item):
            popover.sourceItem = item
        case let .viewRect(view, rect):
            popover.sourceView = view
            popover.sourceRect = rect
        }
    }
}

extension UIPopoverPresentationControllerSourceItem {
    var asPopoverAnchor: PopoverAnchor {
        return PopoverAnchor.sourceItem(item: self)
    }
}

extension UITableView {
    func popoverAnchor(at indexPath: IndexPath) -> PopoverAnchor {
        guard let cell = cellForRow(at: indexPath) else {
            assertionFailure("Cannot create popover for non-existent cell")
            return PopoverAnchor.sourceItem(item: self)
        }
        return PopoverAnchor.sourceItem(item: cell)
    }
}
