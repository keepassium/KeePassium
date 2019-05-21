//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIAlertController {
    
    static func make(
        title: String?,
        message: String?,
        cancelButtonTitle: String? = nil
        ) -> UIAlertController
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let cancelAction = UIAlertAction(
            title: cancelButtonTitle ?? LString.actionDismiss,
            style: .cancel,
            handler: nil)
        alert.addAction(cancelAction)
        return alert
    }
}
