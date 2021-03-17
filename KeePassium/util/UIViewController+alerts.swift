//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension UIViewController {
    
    func showErrorAlert(_ error: Error, title: String?=nil) {
        showErrorAlert(error.localizedDescription, title: title)
    }
    
    func showErrorAlert(_ message: String, title: String?=nil) {
        let alert = UIAlertController.make(
            title: title ?? LString.titleError,
            message: message)
        present(alert, animated: true, completion: nil)
        
        StoreReviewSuggester.registerEvent(.trouble)
    }
    
    func showNotification(
        _ message: String,
        title: String?=nil)
    {
        var hostView: UIView = self.view
        if hostView is UITableView, let navVC = self.navigationController {
            hostView = navVC.view
        }
        hostView.makeToast(
            message,
            duration: 2.0,
            position: .top,
            title: title,
            image: nil,
            completion: nil
        )
    }
}
