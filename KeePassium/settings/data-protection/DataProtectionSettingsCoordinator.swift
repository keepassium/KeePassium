//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class DataProtectionSettingsCoordinator: Coordinator, Refreshable {
    var childCoordinators = [Coordinator]()

    var dismissHandler: CoordinatorDismissHandler?

    private let router: NavigationRouter
    private let dataProtectionSettingsVC: SettingsDataProtectionVC

    init(router: NavigationRouter) {
        self.router = router
        dataProtectionSettingsVC = SettingsDataProtectionVC.instantiateFromStoryboard()
        dataProtectionSettingsVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(dataProtectionSettingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
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

extension DataProtectionSettingsCoordinator {
    private func showDatabaseTimeoutSettingsPage() {
        let databaseTimeoutVC = SettingsDatabaseTimeoutVC.make()
        databaseTimeoutVC.delegate = self
        router.push(databaseTimeoutVC, animated: true, onPop: nil)
    }

    private func showClipboardTimeoutSettingsPage() {
        let clipboardTimeoutVC = SettingsClipboardTimeoutVC.instantiateFromStoryboard()
        clipboardTimeoutVC.delegate = self
        router.push(clipboardTimeoutVC, animated: true, onPop: nil)
    }

    private func showShakeGestureActionSettings() {
        let shakeGestureActionVC = SettingsShakeGestureActionVC.make(delegate: self)
        router.push(shakeGestureActionVC, animated: true, onPop: nil)
    }
}

extension DataProtectionSettingsCoordinator: SettingsDataProtectionViewCoordinatorDelegate {
    func didPressDatabaseTimeout(in viewController: SettingsDataProtectionVC) {
        showDatabaseTimeoutSettingsPage()
    }

    func didPressClipboardTimeout(in viewController: SettingsDataProtectionVC) {
        showClipboardTimeoutSettingsPage()
    }

    func didPressShakeGestureAction(in viewController: SettingsDataProtectionVC) {
        showShakeGestureActionSettings()
    }

    func didToggleLockDatabasesOnTimeout(
        newValue: Bool,
        in viewController: SettingsDataProtectionVC
    ) {
        Settings.current.isLockDatabasesOnTimeout = newValue
        refresh()
    }
}

extension DataProtectionSettingsCoordinator: SettingsDatabaseTimeoutVCDelegate {
    func didSelectTimeout(
        _ timeout: Settings.DatabaseLockTimeout,
        in viewController: SettingsDatabaseTimeoutVC
    ) {
        Settings.current.databaseLockTimeout = timeout

        Watchdog.shared.restart() 

        if Settings.current.isManaged(key: .databaseLockTimeout) {
            viewController.showManagedSettingNotification()
        } else {
            DispatchQueue.main.async { [weak router] in
                router?.pop(viewController: viewController, animated: true)
            }
        }
    }
}

extension DataProtectionSettingsCoordinator: SettingsClipboardTimeoutVCDelegate {
    func didSelectTimeout(
        _ timeout: Settings.ClipboardTimeout,
        in viewController: SettingsClipboardTimeoutVC
    ) {
        Settings.current.clipboardTimeout = timeout
        refresh()

        if Settings.current.isManaged(key: .clipboardTimeout) {
            viewController.showManagedSettingNotification()
        } else {
            DispatchQueue.main.async { [weak router] in
                router?.pop(viewController: viewController, animated: true)
            }
        }
    }
}

extension DataProtectionSettingsCoordinator: SettingsShakeGestureActionVCDelegate {
    func didSelectShakeGesture(
        _ action: Settings.ShakeGestureAction,
        in viewController: SettingsShakeGestureActionVC
    ) {
        Settings.current.shakeGestureAction = action
        refresh()

        if Settings.current.isManaged(key: .shakeGestureAction) {
            viewController.showManagedSettingNotification()
        }
    }

    func didSetShakeGestureConfirmation(
        _ shouldConfirm: Bool,
        in viewController: SettingsShakeGestureActionVC
    ) {
        Settings.current.isConfirmShakeGestureAction = shouldConfirm
        refresh()

        if Settings.current.isManaged(key: .confirmShakeGestureAction) {
            viewController.showManagedSettingNotification()
        }
    }
}
