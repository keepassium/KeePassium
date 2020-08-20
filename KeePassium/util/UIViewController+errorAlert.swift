//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

extension UIViewController {
    
    func showErrorAlert(_ error: Error, title: String?=nil) {
        showErrorAlert(error.localizedDescription)
    }
    
    func showErrorAlert(_ message: String, title: String?=nil) {
        let alert = UIAlertController.make(
            title: title ?? LString.titleError,
            message: message)
        present(alert, animated: true, completion: nil)
    }
}
