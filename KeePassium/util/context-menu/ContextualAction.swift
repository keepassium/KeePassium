//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

struct ContextualAction {
    public enum Style {
        case `default`
        case destructive
        case cancel
    }

    var title: String
    var imageName: SymbolName?
    var style: Style
    var color: UIColor?
    var handler: (() -> Void)

    public func toMenuAction() -> UIAction {
        var image: UIImage?
        if let imageName {
            image = .symbol(imageName)
        }
        return UIAction(
            title: title,
            image: image,
            attributes: (style == .destructive) ? [.destructive] : [],
            handler: { _ in
                handler()
            }
        )
    }

    public func toAlertAction() -> UIAlertAction {
        let alertActionStyle: UIAlertAction.Style
        switch style {
        case .default:
            alertActionStyle = .default
        case .destructive:
            alertActionStyle = .destructive
        case .cancel:
            alertActionStyle = .cancel
        }

        return UIAlertAction(
            title: title,
            style: alertActionStyle,
            handler: { _ in
                handler()
            }
        )
    }

    public func toContextualAction(tableView: UITableView) -> UIContextualAction {
        let contextualAction: UIContextualAction
        switch style {
        case .default, .cancel:
            contextualAction = UIContextualAction(style: .normal, title: title) {
                [weak tableView] _, _, completion in
                tableView?.setEditing(false, animated: true)
                handler()
                completion(true)
            }
        case .destructive:
            contextualAction = UIContextualAction(style: .destructive, title: title) {
                [weak tableView] _, _, completion in
                tableView?.setEditing(false, animated: true)
                handler()
                completion(true)
            }
        }
        if let imageName {
            contextualAction.image = .symbol(imageName)
        } else {
            contextualAction.image = nil
        }
        contextualAction.backgroundColor = color
        return contextualAction
    }
}
