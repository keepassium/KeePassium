//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib
import LocalAuthentication

extension MainCoordinator {
    internal func _canUseBiometrics() -> Bool {
        return Settings.current.isBiometricAppLockEnabled
        && LAContext.isBiometricsAvailable()
        && Keychain.shared.isBiometricAuthPrepared()
    }

    internal func _showAppLockScreen() {
        guard !isAppLockVisible else { return }

        #if targetEnvironment(macCatalyst)
        _removeMacToolbar()
        _rootSplitVC.dismiss(animated: false)
        #endif

        let isRepeatedLockOnMac = ProcessInfo.isRunningOnMac && !_isInitialAppLock
        _isInitialAppLock = false
        if _canUseBiometrics() && !isRepeatedLockOnMac {
            _performBiometricUnlock()
        } else {
            showPasscodeRequest()
        }
        UIMenu.rebuildMainMenu()
    }

    internal func _performBiometricUnlock() {
        guard !_isBiometricAuthShown,
              _canUseBiometrics()
        else {
            return
        }

        let timeSinceLastSuccess = abs(Date.now.timeIntervalSince(_lastSuccessfulBiometricAuthTime))
        if timeSinceLastSuccess < LAContext.biometricAuthReuseDuration {
            print("Skipping repeated biometric prompt")
            _watchdog.unlockApp()
            return
        }

        print("Showing biometrics request")
        showBiometricsBackground()
        _lastSuccessfulBiometricAuthTime = .distantPast
        Keychain.shared.performBiometricAuth { [weak self] success in
            guard let self else { return }
            _isBiometricAuthShown = false
            if success {
                Diag.warning("Biometric auth successful")
                _lastSuccessfulBiometricAuthTime = Date.now
                _watchdog.unlockApp()
            } else {
                Diag.warning("Biometric auth failed")
                _lastSuccessfulBiometricAuthTime = .distantPast
                showPasscodeRequest()
            }
            hideBiometricsBackground()
        }
        _isBiometricAuthShown = true
    }
}

extension MainCoordinator: WatchdogDelegate {
    var isAppCoverVisible: Bool {
        if ProcessInfo.isRunningOnMac { return false }
        return _appCoverWindow != nil
    }
    var isAppLockVisible: Bool {
        return _appLockWindow != nil || _isBiometricAuthShown
    }
    func showAppCover(_ sender: Watchdog) {
        if ProcessInfo.isRunningOnMac { return }
        showAppCoverScreen()
    }
    func hideAppCover(_ sender: Watchdog) {
        if ProcessInfo.isRunningOnMac { return }
        hideAppCoverScreen()
    }
    func showAppLock(_ sender: Watchdog) {
        _showAppLockScreen()
    }
    func hideAppLock(_ sender: Watchdog) {
        hideAppLockScreen()
    }
    func mustCloseDatabase(_ sender: Watchdog, animate: Bool) {
        _databaseViewerCoordinator?.closeDatabase(
            shouldLock: Settings.current.isLockDatabasesOnTimeout,
            reason: .databaseTimeout,
            animated: animate,
            completion: nil
        )
    }
}

extension MainCoordinator {
    private func showAppCoverScreen() {
        guard _appCoverWindow == nil else { return }

        guard let currentScene = _mainWindow.windowScene else {
            fatalError("Main window has no scene")
        }
        let appCoverWindow = UIWindow(windowScene: currentScene)
        appCoverWindow.bounds = currentScene.screen.bounds
        appCoverWindow.windowLevel = UIWindow.Level.alert
        self._appCoverWindow = appCoverWindow

        let coverVC = AppCoverVC.make()
        DispatchQueue.main.async { [appCoverWindow, coverVC] in
            UIView.performWithoutAnimation {
                appCoverWindow.rootViewController = coverVC
                appCoverWindow.makeKeyAndVisible()
            }
            print("App cover shown")
            coverVC.view.accessibilityViewIsModal = true
            coverVC.view.snapshotView(afterScreenUpdates: true)
        }
    }

    private func hideAppCoverScreen() {
        guard let _appCoverWindow else { return }
        _appCoverWindow.isHidden = true
        self._appCoverWindow = nil
        print("App cover hidden")

        _mainWindow.makeKeyAndVisible()
        if isAppLockVisible {
            _appLockWindow?.makeKeyAndVisible()
        }
    }

    private func showPasscodeRequest() {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .verification
        passcodeInputVC.isCancelAllowed = false
        passcodeInputVC.isBiometricsAllowed = _canUseBiometrics()

        guard let currentScene = _mainWindow.windowScene else {
            fatalError("Main window has no scene")
        }
        let appLockWindow = UIWindow(windowScene: currentScene)
        appLockWindow.bounds = currentScene.screen.bounds
        appLockWindow.windowLevel = UIWindow.Level.alert
        UIView.performWithoutAnimation {
            appLockWindow.rootViewController = passcodeInputVC
            appLockWindow.makeKeyAndVisible()
            _mainWindow.isHidden = true
        }
        passcodeInputVC.view.accessibilityViewIsModal = true
        passcodeInputVC.view.snapshotView(afterScreenUpdates: true)

        self._appLockWindow = appLockWindow
        print("passcode request shown")
    }

    private func showBiometricsBackground() {
        guard _biometricsBackgroundWindow == nil else { return }

        guard let currentScene = _mainWindow.windowScene else {
            fatalError("Main window has no scene")
        }
        let window = UIWindow(windowScene: currentScene)
        window.bounds = currentScene.screen.bounds
        window.windowLevel = UIWindow.Level.alert + 1
        let coverVC = AppCoverVC.make()

        UIView.performWithoutAnimation {
            window.rootViewController = coverVC
            window.makeKeyAndVisible()
        }
        print("Biometrics background shown")
        self._biometricsBackgroundWindow = window

        coverVC.view.snapshotView(afterScreenUpdates: true)
    }

    private func hideAppLockScreen() {
        guard isAppLockVisible else { return }
        #if targetEnvironment(macCatalyst)
        _setupMacToolbar()
        #endif

        _appLockWindow?.resignKey()
        _appLockWindow?.isHidden = true
        _appLockWindow = nil
        UIMenu.rebuildMainMenu()

        _mainWindow.makeKeyAndVisible()
        print("appLockWindow hidden")
    }

    private func hideBiometricsBackground() {
        guard let window = _biometricsBackgroundWindow else { return }
        window.isHidden = true
        _biometricsBackgroundWindow = nil
        print("Biometrics background hidden")
    }
}
