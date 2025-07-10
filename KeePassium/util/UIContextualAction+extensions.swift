//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import UIKit

extension UIContextualAction {
    convenience init(
        style: Style = .normal,
        title: String? = nil,
        image: UIImage? = nil,
        color: UIColor? = nil,
        handler: @escaping Handler
    ) {
        self.init(style: style, title: title, handler: handler)
        if let image {
            self.image = image
        }
        if let color {
            self.backgroundColor = color
        }
    }
}
