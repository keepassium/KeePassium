//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
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
    var imageName: SystemImageName?
    var style: Style
    var color: UIColor?
    var handler: (() -> Void)
    
    var image: UIImage? {
        guard let imageName = imageName else {
            return nil
        }
        return UIImage.get(imageName)
    }

    @available(iOS 13, *)
    public func toMenuAction() -> UIAction {
        return UIAction(
            title: title,
            image: image,
            handler: { action in
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
            handler: { action in
                handler()
            }
        )
    }
    
    public func toContextualAction(tableView: UITableView) -> UIContextualAction {
        let contextualAction: UIContextualAction
        switch style {
        case .default, .cancel:
            contextualAction = UIContextualAction(style: .normal, title: title) {
                [weak tableView] (action, sourceView, completion) in
                tableView?.setEditing(false, animated: true)
                handler()
                completion(true)
            }
        case .destructive:
            contextualAction = UIContextualAction(style: .destructive, title: title) {
                [weak tableView] (action, sourceView, completion) in
                tableView?.setEditing(false, animated: true)
                handler()
                if #available(iOS 13, *) {
                    completion(true)
                } else {
                    completion(false) 
                }
            }

        }
        contextualAction.image = image
        contextualAction.backgroundColor = color
        return contextualAction
    }
}
