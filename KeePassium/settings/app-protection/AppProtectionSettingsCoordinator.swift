//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import LocalAuthentication.LABiometryType

final class AppProtectionSettingsCoordinator: BaseCoordinator {
    internal let _appProtectionSettingsVC: AppProtectionSettingsVC

    override init(router: NavigationRouter) {
        _appProtectionSettingsVC = AppProtectionSettingsVC()
        super.init(router: router)
        _appProtectionSettingsVC.delegate = self
    }

    override func start() {
        guard ManagedAppConfig.shared.isAppProtectionAllowed else {
            Diag.error("Blocked by organization's policy, cancelling")
            _dismissHandler?(self)
            assertionFailure("This action should have been disabled in UI")
            return
        }
        super.start()
        _pushInitialViewController(_appProtectionSettingsVC, animated: true)
        applySettingsToVC()
    }

    override func refresh() {
        super.refresh()
        applySettingsToVC()
        _appProtectionSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        _appProtectionSettingsVC.isAppProtectionEnabled = Settings.current.isAppLockEnabled
        _appProtectionSettingsVC.isUseBiometric = Settings.current.isBiometricAppLockEnabled
        _appProtectionSettingsVC.timeout = Settings.current.appLockTimeout
        _appProtectionSettingsVC.isLockOnScreenLock = Settings.current.isLockAppOnScreenLock
        _appProtectionSettingsVC.isLockOnAppLaunch = Settings.current.isLockAppOnLaunch
        _appProtectionSettingsVC.isLockOnFailedPasscode = Settings.current.isLockAllDatabasesOnFailedPasscode
        _appProtectionSettingsVC.passcodeAttemptsBeforeAppReset = Settings.current.passcodeAttemptsBeforeAppReset
        updateBiometricsSupport()
    }

    private func updateBiometricsSupport() {
        let context = LAContext()
        let isSupported = context.canEvaluatePolicy(
            LAPolicy.deviceOwnerAuthenticationWithBiometrics,
            error: nil)
        if !isSupported {
            Settings.current.isBiometricAppLockEnabled = false
        }
        _appProtectionSettingsVC.isBiometricsSupported = isSupported

        _appProtectionSettingsVC.biometryType = context.biometryType
    }
}

extension AppProtectionSettingsCoordinator: AppProtectionSettingsVC.Delegate {
    func didChangeAppProtectionEnabled(_ isEnabled: Bool, in viewController: AppProtectionSettingsVC) {
        if isEnabled {
            _showChangePasscode(isInitialSetup: true)
            return
        }

        guard !ManagedAppConfig.shared.isRequireAppPasscodeSet else {
            viewController.showManagedSettingNotification()
            refresh()
            return
        }
        Settings.current.isHideAppLockSetupReminder = false
        do {
            try Keychain.shared.removeAppPasscode()
        } catch {
            Diag.error(error.localizedDescription)
            viewController.showErrorAlert(error, title: LString.titleKeychainError)
        }
    }

    func didPressChangePasscode(in viewController: AppProtectionSettingsVC) {
        _showChangePasscode(isInitialSetup: false)
    }

    func didChangeIsUseBiometric(_ isUseBiometric: Bool, in viewController: AppProtectionSettingsVC) {
        let keychain = Keychain.shared
        if keychain.prepareBiometricAuth(isUseBiometric) {
            Settings.current.isBiometricAppLockEnabled = isUseBiometric
        } else {
            Settings.current.isBiometricAppLockEnabled = keychain.isBiometricAuthPrepared()
        }
        viewController.showNotificationIfManaged(setting: .biometricAppLockEnabled)
        refresh()
    }

    func didChangeTimeout(_ timeout: Settings.AppLockTimeout, in viewController: AppProtectionSettingsVC) {
        Settings.current.appLockTimeout = timeout
        viewController.showNotificationIfManaged(setting: .appLockTimeout)
        Watchdog.shared.restart()
        refresh()
    }

    func didChangeIsLockOnScreenLock(_ isLockAppOnScreenLock: Bool, in viewController: AppProtectionSettingsVC) {
        Settings.current.isLockAppOnScreenLock = isLockAppOnScreenLock
        viewController.showNotificationIfManaged(setting: .lockAppOnScreenLock)
        refresh()
    }

    func didChangeIsLockOnAppLaunch(_ isLockOnAppLaunch: Bool, in viewController: AppProtectionSettingsVC) {
        Settings.current.isLockAppOnLaunch = isLockOnAppLaunch
        viewController.showNotificationIfManaged(setting: .lockAppOnLaunch)
        refresh()
    }

    func didChangeIsLockOnFailedPasscode(_ isLockOnFailedPasscode: Bool, in viewController: AppProtectionSettingsVC) {
        Settings.current.isLockAllDatabasesOnFailedPasscode = isLockOnFailedPasscode
        viewController.showNotificationIfManaged(setting: .lockAllDatabasesOnFailedPasscode)
        refresh()
    }

    func didChangePasscodeAttemptsBeforeAppReset(
        _ attempts: Settings.PasscodeAttemptsBeforeAppReset,
        in viewController: AppProtectionSettingsVC
    ) {
        Settings.current.passcodeAttemptsBeforeAppReset = attempts
        viewController.showNotificationIfManaged(setting: .passcodeAttemptsBeforeAppReset)
        refresh()
    }
}
