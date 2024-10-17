//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class AppProtectionSettingsCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()

    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter
    private let appProtectionSettingsVC: SettingsAppLockVC
    private let settingsNotifications: SettingsNotifications

    init(router: NavigationRouter) {
        self.router = router
        appProtectionSettingsVC = SettingsAppLockVC.instantiateFromStoryboard()
        settingsNotifications = SettingsNotifications()

        appProtectionSettingsVC.delegate = self
        settingsNotifications.observer = self
    }

    deinit {
        settingsNotifications.stopObserving()

        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        guard ManagedAppConfig.shared.isAppProtectionAllowed else {
            Diag.error("Blocked by organization's policy, cancelling")
            dismissHandler?(self)
            assertionFailure("This action should have been disabled in UI")
            return
        }
        router.push(appProtectionSettingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        settingsNotifications.startObserving()
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
    }

    @objc
    private func premiumStatusDidChange() {
        refresh()
    }

    func refresh() {
        guard let topVC = router.navigationController.topViewController,
              let topRefreshable = topVC as? Refreshable
        else {
            return
        }
        topRefreshable.refresh()
    }
}

extension AppProtectionSettingsCoordinator {
    private func showChangePasscode(isInitialSetup: Bool) {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = isInitialSetup ? .setup : .change
        passcodeInputVC.modalPresentationStyle = .formSheet
        passcodeInputVC.isCancelAllowed = true
        appProtectionSettingsVC.present(passcodeInputVC, animated: true, completion: nil)
    }

    private func showAppTimeoutSettingsPage() {
        let appTimeoutVC = SettingsAppTimeoutVC.instantiateFromStoryboard()
        router.push(appTimeoutVC, animated: true, onPop: nil)
    }
}

extension AppProtectionSettingsCoordinator: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else {
            return
        }
        refresh()
    }
}

extension AppProtectionSettingsCoordinator: SettingsAppLockViewControllerDelegate {
    func didPressAppTimeout(in viewController: SettingsAppLockVC) {
        showAppTimeoutSettingsPage()
    }

    func didPressChangePasscode(isInitialSetup: Bool, in viewController: SettingsAppLockVC) {
        showChangePasscode(isInitialSetup: isInitialSetup)
    }
}

extension AppProtectionSettingsCoordinator: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        if sender.mode == .setup {
            do {
                try Keychain.shared.removeAppPasscode() 
            } catch {
                Diag.error(error.localizedDescription)
                sender.showErrorAlert(error, title: LString.titleKeychainError)
                return
            }
        }
        refresh()
        sender.dismiss(animated: true, completion: nil)
    }

    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }

    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        sender.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            do {
                try Keychain.shared.setAppPasscode(passcode)
                self.appProtectionSettingsVC.showNotification(LString.titleNewPasscodeSaved)
            } catch {
                Diag.error(error.localizedDescription)
                self.appProtectionSettingsVC.showErrorAlert(error, title: LString.titleKeychainError)
            }
        }
    }
}
