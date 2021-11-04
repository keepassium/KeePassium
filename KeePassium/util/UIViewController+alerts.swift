//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

fileprivate let toastIconSize = CGSize(width: 25, height: 25)

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
    
    private func getHostViewForToastNotifications() -> UIView {
        var hostVC: UIViewController = self
        if hostVC is UITableViewController, let navVC = self.navigationController {
            hostVC = navVC
        }
        if hostVC is UINavigationController, let splitVC = hostVC.splitViewController {
            hostVC = splitVC
        }
        return hostVC.view
    }
    
    func showNotification(
        _ message: String,
        title: String? = nil,
        image: UIImage? = nil,
        imageSize: CGSize? = nil,
        duration: TimeInterval = 3.0)
    {
        var style = ToastStyle()
        style.backgroundColor = .darkGray
        if let imageSize = imageSize {
            style.imageSize = imageSize
        }
        getHostViewForToastNotifications().makeToast(
            message,
            duration: duration,
            position: .top,
            title: title,
            image: image,
            style: style,
            completion: nil
        )
    }
    
    func showSuccessNotification(_ message: String) {
        let checkmarkIcon: UIImage?
        if #available(iOS 13, *) {
            checkmarkIcon = UIImage.get(.checkmark)?
                .withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        } else {
            checkmarkIcon = UIImage.get(.checkmark)
        }
        showNotification(
            message,
            image: checkmarkIcon,
            imageSize: toastIconSize
        )
    }
    
    func hideAllToasts() {
        getHostViewForToastNotifications().hideAllToasts()
    }
}
