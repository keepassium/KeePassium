//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension UIAlertController {

    static func make(
        title: String?,
        message: String?,
        dismissButtonTitle: String = LString.actionDismiss
    ) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(title: dismissButtonTitle, style: .cancel, handler: nil)
        return alert
    }

    @discardableResult
    func addAction(
        title: String?,
        style: UIAlertAction.Style = .default,
        preferred: Bool = false,
        handler: ((UIAlertAction) -> Void)?
    ) -> UIAlertController {
        let action = UIAlertAction(title: title, style: style, handler: handler)
        self.addAction(action)
        if preferred {
            self.preferredAction = action
        }
        return self
    }
}
