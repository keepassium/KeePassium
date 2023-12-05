//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension UIViewController {

    func showErrorAlert(_ error: Error, title: String? = nil) {
        var message = error.localizedDescription
        if let localizedError = error as? LocalizedError,
           let recoverySuggestion = localizedError.recoverySuggestion
        {
            message += "\n" + recoverySuggestion
        }
        showErrorAlert(message, title: title)
    }

    func showErrorAlert(_ message: String, title: String? = nil) {
        let alert = UIAlertController.make(
            title: title ?? LString.titleError,
            message: message,
            dismissButtonTitle: LString.actionOK)
        present(alert, animated: true, completion: nil)

        StoreReviewSuggester.registerEvent(.trouble)
    }

    func ensuringNetworkAccessPermitted(allowed completion: @escaping () -> Void) {
        requestingNetworkAccessPermission { isAllowed in
            if isAllowed {
                completion()
            }
        }
    }

    func requestingNetworkAccessPermission(completion: @escaping (_ isAllowed: Bool) -> Void) {
        if Settings.current.isNetworkAccessAllowed {
            completion(true)
            return
        }

        let isManaged = Settings.current.isManaged(key: .networkAccessAllowed)
        let networkModeAlert = UIAlertController(
            title: LString.titleNetworkAccessSettings,
            message: isManaged ? LString.thisSettingIsManaged : LString.allowNetwokAccessQuestionText,
            preferredStyle: .alert
        )
        if !isManaged {
            networkModeAlert.addAction(title: LString.titleAllowNetworkAccess, style: .default) { _ in
                Diag.info("Network access is allowed by the user")
                Settings.current.isNetworkAccessAllowed = true
                completion(true)
            }
        }
        networkModeAlert.addAction(title: LString.titleStayOffline, style: .cancel) { _ in
            Diag.info("Network access is denied by the user")
            Settings.current.isNetworkAccessAllowed = false
            completion(false)
        }
        present(networkModeAlert, animated: true)
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
        position: ToastPosition = .top,
        action: ToastAction? = nil,
        duration: TimeInterval = 5.0
    ) {
        var style = ToastStyle()
        style.buttonColor = .actionTint

        let hostView = getHostViewForToastNotifications()
        let toastView = hostView.toastViewForMessage(
            message,
            title: title,
            image: image,
            action: action,
            style: style
        )
        hostView.showToast(
            toastView,
            duration: duration,
            position: position,
            action: action,
            completion: nil
        )
    }

    func showSuccessNotification(_ message: String, icon: SymbolName) {
        showNotification(
            message,
            image: .symbol(icon)
        )
    }

    func showNotificationIfManaged(setting key: Settings.Keys) {
        if Settings.current.isManaged(key: key) {
            showManagedSettingNotification()
        }
    }

    func showManagedSettingNotification() {
        hideAllToasts()
        showNotification(
            LString.thisSettingIsManaged,
            image: .symbol(.person2BadgeGearshape)?
                .withTintColor(.iconTint, renderingMode: .alwaysOriginal)
        )
    }

    func hideAllToasts() {
        getHostViewForToastNotifications().hideAllToasts()
    }
}
