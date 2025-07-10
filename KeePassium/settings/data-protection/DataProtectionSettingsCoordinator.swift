//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

final class DataProtectionSettingsCoordinator: BaseCoordinator {
    internal let _dataProtectionSettingsVC: DataProtectionSettingsVC

    override init(router: NavigationRouter) {
        _dataProtectionSettingsVC = DataProtectionSettingsVC()
        super.init(router: router)
        _dataProtectionSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(_dataProtectionSettingsVC, animated: true)
        applySettingsToVC()
    }

    override func refresh() {
        super.refresh()
        applySettingsToVC()
        _dataProtectionSettingsVC.refresh()
    }

    private func applySettingsToVC() {
        let vc = _dataProtectionSettingsVC
        let s = Settings.current
        vc.isRememberMasterKeys = s.isRememberDatabaseKey
        vc.databaseTimeout = s.databaseLockTimeout
        vc.isLockOnReboot = s.isLockDatabasesOnReboot
        vc.isLockOnTimeout = s.isLockDatabasesOnTimeout
        vc.isLockOnScreenLock = s.isLockDatabasesOnScreenLock
        vc.shakeAction = s.shakeGestureAction
        vc.isConfirmShakeAction = s.isConfirmShakeGestureAction
        vc.clipboardTimeout = s.clipboardTimeout
        vc.isUseUniversalClipboard = s.isUniversalClipboardEnabled
        vc.isHideProtectedFields = s.isHideProtectedFields
        vc.isRememberKeyFiles = s.isKeepKeyFileAssociations
        vc.isRememberFinalKeys = s.isRememberDatabaseFinalKey
    }
}

extension DataProtectionSettingsCoordinator {
    internal func _clearMasterKeys(notify: Bool, presenter: UIViewController) {
        DatabaseSettingsManager.shared.eraseAllMasterKeys()
        if notify {
            presenter.showNotification(
                LString.masterKeysClearedTitle,
                image: .symbol(.key, tint: .iconTint),
                hidePrevious: true,
                duration: 1
            )
        }
    }

    internal func _clearKeyFileAssociations(notify: Bool, presenter: UIViewController) {
        DatabaseSettingsManager.shared.forgetAllKeyFiles()
        if notify {
            presenter.showNotification(
                LString.keyFileAssociationsClearedTitle,
                image: .symbol(.keyFile, tint: .iconTint),
                hidePrevious: true,
                duration: 1
            )
        }
    }
}

extension DataProtectionSettingsCoordinator: DataProtectionSettingsVC.Delegate {
    func didChangeRememberMasterKeys(_ isRemember: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isRememberDatabaseKey = isRemember
        viewController.showNotificationIfManaged(setting: .rememberDatabaseKey)
        refresh()
        if !Settings.current.isRememberDatabaseKey {
            let isManaged = ManagedAppConfig.shared.isManaged(key: .rememberDatabaseKey)
            _clearMasterKeys(notify: !isManaged, presenter: viewController)
        }
    }

    func didPressClearMasterKeys(in viewController: DataProtectionSettingsVC) {
        _clearMasterKeys(notify: true, presenter: viewController)
    }

    func didChangeDatabaseTimeout(
        _ timeout: Settings.DatabaseLockTimeout,
        in viewController: DataProtectionSettingsVC
    ) {
        Settings.current.databaseLockTimeout = timeout
        Watchdog.shared.restart()
        viewController.showNotificationIfManaged(setting: .databaseLockTimeout)
        refresh()
    }

    func didChangeLockOnReboot(_ isLockOnRestart: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isLockDatabasesOnReboot = isLockOnRestart
        viewController.showNotificationIfManaged(setting: .lockDatabasesOnReboot)
        refresh()
    }

    func didChangeLockOnTimeout(_ isLockOnTimeout: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isLockDatabasesOnTimeout = isLockOnTimeout
        viewController.showNotificationIfManaged(setting: .lockDatabasesOnTimeout)
        refresh()
    }

    func didChangeLockOnScreenLock(
        _ isLockOnScreenLock: Bool,
        in viewController: DataProtectionSettingsVC
    ) {
        Settings.current.isLockDatabasesOnScreenLock = isLockOnScreenLock
        viewController.showNotificationIfManaged(setting: .lockDatabasesOnScreenLock)
        refresh()
    }

    func didChangeShakeAction(
        _ action: Settings.ShakeGestureAction,
        in viewController: DataProtectionSettingsVC
    ) {
        Settings.current.shakeGestureAction = action
        viewController.showNotificationIfManaged(setting: .shakeGestureAction)
        refresh()
    }

    func didChangeConfirmShakeAction(_ isConfirm: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isConfirmShakeGestureAction = isConfirm
        viewController.showNotificationIfManaged(setting: .confirmShakeGestureAction)
        refresh()
    }

    func didChangeClipboardTimeout(
        _ timeout: Settings.ClipboardTimeout,
        in viewController: DataProtectionSettingsVC
    ) {
        Settings.current.clipboardTimeout = timeout
        viewController.showNotificationIfManaged(setting: .clipboardTimeout)
        refresh()
    }

    func didChangeUseUniversalClipboard(_ isUse: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isUniversalClipboardEnabled = isUse
        viewController.showNotificationIfManaged(setting: .universalClipboardEnabled)
        refresh()
    }

    func didChangeHideProtectedFields(_ isHide: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isHideProtectedFields = isHide
        viewController.showNotificationIfManaged(setting: .hideProtectedFields)
        refresh()
    }

    func didChangeRememberKeyFiles(_ isRemember: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isKeepKeyFileAssociations = isRemember
        refresh()
        viewController.showNotificationIfManaged(setting: .keepKeyFileAssociations)
        if !Settings.current.isKeepKeyFileAssociations {
            let isManaged = ManagedAppConfig.shared.isManaged(key: .keepKeyFileAssociations)
            _clearKeyFileAssociations(notify: !isManaged, presenter: viewController)
        }
    }

    func didPressClearKeyFileAssociations(in viewController: DataProtectionSettingsVC) {
        _clearKeyFileAssociations(notify: true, presenter: viewController)

    }

    func didChangeRememberFinalKeys(_ isRemember: Bool, in viewController: DataProtectionSettingsVC) {
        Settings.current.isRememberDatabaseFinalKey = isRemember
        refresh()
        viewController.showNotificationIfManaged(setting: .rememberDatabaseFinalKey)
        if !Settings.current.isRememberDatabaseFinalKey {
            DatabaseSettingsManager.shared.eraseAllFinalKeys()
            Diag.info("Final keys erased successfully")
        }
    }
}
