//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation
import KeePassiumLib
import UIKit

final class AutoTypeHelper {
    private let macUtils: MacUtils
    private var hasRequestedAccessibilityPermission = false

    init?(macUtils: MacUtils?) {
        guard let macUtils else {
            return nil
        }
        self.macUtils = macUtils
    }

    func tryPerformAutoType(from viewController: UIViewController, username: String, password: String) {
        if macUtils.isAccessibilityPermissionGranted() {
            Diag.debug("Accessibility permission granted, starting auto-type")
            performAutoType(from: viewController, username: username, password: password)
            return
        }

        Diag.debug("Accessibility permission not granted or denied")
        if hasRequestedAccessibilityPermission {
            Diag.debug("Accessibility permission was already requested but denied, showing alert")
            let messageParts = [
                LString.messageAutoTypeAccessibilityNeeded1,
                LString.messageAutoTypeAccessibilityNeeded2,
            ]
            let alert = UIAlertController.make(
                title: LString.titleAutoTypeAccessibility,
                message: messageParts.joined(separator: "\n\n"),
                dismissButtonTitle: LString.actionCancel)
            alert.addAction(title: LString.actionOpenAccessibilitySettings, preferred: true) { [weak self] _ in
                self?.macUtils.openAccessibilityPermissionSettings()
            }
            viewController.present(alert, animated: true)
        } else {
            Diag.debug("Requesting accessibility permission")
            hasRequestedAccessibilityPermission = true
            macUtils.requestAccessibilityPermission()
        }
    }

    private func performAutoType(from viewController: UIViewController, username: String, password: String) {
        macUtils.hideApplication()
        macUtils.performAutoType(username: username, password: password) { [weak self] success in
            if !success {
                Diag.error("Auto-type script error")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.macUtils.activate()
                    viewController.showErrorAlert(LString.titleAutoTypeFailed, title: LString.actionAutoType)
                }
            }
        }
    }
}
