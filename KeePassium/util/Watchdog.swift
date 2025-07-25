//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol WatchdogDelegate: AnyObject {
    var isAppCoverVisible: Bool { get }
    func showAppCover(_ sender: Watchdog)
    func hideAppCover(_ sender: Watchdog)

    var isAppLockVisible: Bool { get }
    func showAppLock(_ sender: Watchdog)
    func hideAppLock(_ sender: Watchdog)

    func mustCloseDatabase(_ sender: Watchdog, animate: Bool)
}

fileprivate extension WatchdogDelegate {
    var isAppLocked: Bool {
        return isAppLockVisible
    }
}

class Watchdog {
    public static let shared = Watchdog()

    private var isAppLaunchHandled = false

    public weak var delegate: WatchdogDelegate?

    private var appLockTimer: Timer?
    private var databaseLockTimer: Timer?
    private var isIgnoringMinimizationOnce = false
    public private(set) var isFirstLaunchAfterRestart = false

    private let screenIsLockedNotificationName = Notification.Name(rawValue: "com.apple.screenIsLocked")
    private let screenIsUnlockedNotificationName = Notification.Name(rawValue: "com.apple.screenIsUnlocked")
    private let nsWindowDidBecomeKeyNotificationName = Notification.Name(rawValue: "NSWindowDidBecomeKeyNotification")
    private let nsWindowDidResignKeyNotificationName = Notification.Name(rawValue: "NSWindowDidResignKeyNotification")

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil)
        #if targetEnvironment(macCatalyst)
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(macScreenDidLock),
                name: screenIsLockedNotificationName,
                object: nil)
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(macScreenDidUnlock),
                name: screenIsUnlockedNotificationName,
                object: nil)

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(macWindowDidBecomeKey),
                name: nsWindowDidBecomeKeyNotificationName,
                object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(macWindowDidResignKey),
                name: nsWindowDidResignKeyNotificationName,
                object: nil)
        #endif
    }


    @objc private func appDidBecomeActive(_ notification: Notification) {
        didBecomeActive()
    }

    @objc private func macWindowDidBecomeKey(_notification: Notification) {
        Diag.debug("Mac window did become key")
        didBecomeActive()
    }

    @objc private func macWindowDidResignKey(_notification: Notification) {
        Diag.debug("Mac window did resign key")
        willResignActive()
    }

    @objc private func macScreenDidUnlock(_notification: Notification) {
        Diag.debug("Screen unlocked")
        didBecomeActive()
    }

    internal func didBecomeActive() {
        Diag.debug("App did become active")
        restartAppTimer()
        restartDatabaseTimer()
        if isIgnoringMinimizationOnce {
            Diag.debug("Self-backgrounding ignored.")
            isIgnoringMinimizationOnce = false
        } else {
            maybeLockSomething()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            self.delegate?.hideAppCover(self)
        }
    }

    @objc private func appWillResignActive(_ notification: Notification) {
        willResignActive()
    }

    @objc private func macScreenDidLock(_notification: Notification) {
        Diag.debug("Screen locked")

        if Settings.current.isLockDatabasesOnScreenLock {
            Diag.debug("Screen locked: Database Lock engaged")
            engageDatabaseLock(reason: .systemEvent, animate: false)
        }

        if Settings.current.isAppLockEnabled && Settings.current.isLockAppOnScreenLock {
            Diag.debug("Screen locked: App Lock engaged")
            engageAppLock()
        }

        willResignActive()
    }

    internal func willResignActive() {
        Diag.debug("App will resign active")
        guard let delegate else { return }
        delegate.showAppCover(self)
        if delegate.isAppLocked { return }

        let databaseTimeout = Settings.current.databaseLockTimeout
        if databaseTimeout == .immediately && !isIgnoringMinimizationOnce {
            Diag.debug("Going to background: Database Lock engaged")
            engageDatabaseLock(reason: .timeout, animate: false)
        }

        let appTimeout = Settings.current.appLockTimeout
        if appTimeout.triggerMode == .appMinimized && !isIgnoringMinimizationOnce {
            Diag.debug("Going to background: App Lock engaged")
            Watchdog.shared.restart() 
        }

        if ProcessInfo.isRunningOnMac {
            return
        }

        appLockTimer?.invalidate()
        databaseLockTimer?.invalidate()
        appLockTimer = nil
        databaseLockTimer = nil
    }


    @objc private func maybeLockSomething() {
        maybeLockApp()
        maybeLockDatabase()
    }

    @objc private func maybeLockApp() {
        if isShouldEngageAppLock() {
            engageAppLock()
        }
    }

    open func ignoreMinimizationOnce() {
        assert(!isIgnoringMinimizationOnce)
        isIgnoringMinimizationOnce = true
    }

    open func restart() {
        guard let delegate else { return }
        guard !delegate.isAppLocked else { return }
        Settings.current.recentUserActivityTimestamp = Date.now
        restartAppTimer()
        restartDatabaseTimer()
    }

    private func isShouldEngageAppLock() -> Bool {
        let settings = Settings.current
        guard settings.isAppLockEnabled else { return false }

        if !isAppLaunchHandled && settings.isLockAppOnLaunch {
            isAppLaunchHandled = true
            return true
        }

        let timeout = Settings.current.appLockTimeout
        switch timeout {
        case .never: 
            return false
        case .immediately:
            return true
        default:
            let timestampOfRecentActivity = Settings.current
                .recentUserActivityTimestamp
                .timeIntervalSinceReferenceDate
            let timestampNow = Date.now.timeIntervalSinceReferenceDate
            let secondsPassed = timestampNow - timestampOfRecentActivity
            return secondsPassed > timeout.seconds
        }
    }

    @objc private func maybeLockDatabase() {
        if hasRebootedSinceLastTime() && Settings.current.isLockDatabasesOnReboot {
            Diag.debug("Device reboot detected, locking the databases")
            engageDatabaseLock(reason: .systemEvent, animate: false)
            return
        }

        let timeout = Settings.current.databaseLockTimeout
        switch timeout {
        case .never:
            return
        case .immediately:
            engageDatabaseLock(reason: .timeout, animate: false)
            return
        default:
            break
        }
        let timestampOfRecentActivity = Settings.current.recentUserActivityTimestamp
        let databaseLockTimestamp = timestampOfRecentActivity.addingTimeInterval(Double(timeout.seconds))
        let intervalSinceLocked = -databaseLockTimestamp.timeIntervalSinceNow
        if intervalSinceLocked > 0 {
            let isLockedJustNow = intervalSinceLocked < 0.2

            engageDatabaseLock(reason: .timeout, animate: isLockedJustNow)
        }
    }

    private func hasRebootedSinceLastTime() -> Bool {
        guard let currentBootTimestamp = UIDevice.current.bootTime() else {
            Diag.warning("Cannot get boot time, assuming changed")
            isFirstLaunchAfterRestart = true
            return true
        }
        do {
            guard let storedBootTimestamp = try Keychain.shared.getDeviceBootTimestamp() else {
                try Keychain.shared.setDeviceBootTimestamp(currentBootTimestamp)
                return false
            }
            if abs(currentBootTimestamp.timeIntervalSince(storedBootTimestamp)) < 1 {
                return false
            }
            try Keychain.shared.setDeviceBootTimestamp(currentBootTimestamp)
            isFirstLaunchAfterRestart = true
            return true
        } catch {
            Diag.error("Keychain access error, assuming boot time changed")
            isFirstLaunchAfterRestart = true
            return true
        }
    }

    private func restartAppTimer() {
        if let appLockTimer {
            appLockTimer.invalidate()
        }

        let timeout = Settings.current.appLockTimeout
        switch timeout.triggerMode {
        case .appMinimized:
            return
        case .userIdle:
            appLockTimer = Timer.scheduledTimer(
                timeInterval: Double(timeout.seconds),
                target: self,
                selector: #selector(maybeLockApp),
                userInfo: nil,
                repeats: false)
        }
    }

    private func restartDatabaseTimer() {
        if let databaseLockTimer {
            databaseLockTimer.invalidate()
        }

        let timeout = Settings.current.databaseLockTimeout
        Diag.verbose("Database Lock timeout: \(timeout.seconds)")
        switch timeout {
        case .never, .immediately:
            return
        default:
            databaseLockTimer = Timer.scheduledTimer(
                timeInterval: Double(timeout.seconds),
                target: self,
                selector: #selector(maybeLockDatabase),
                userInfo: nil,
                repeats: false)
        }
    }

    private func engageAppLock() {
        guard let delegate else { return }
        guard !delegate.isAppLocked else { return }
        Diag.info("Engaging App Lock")
        appLockTimer?.invalidate()
        appLockTimer = nil
        delegate.showAppLock(self)
    }

    private func engageDatabaseLock(reason: DatabaseLockReason, animate: Bool) {
        Diag.info("Engaging Database Lock")
        self.databaseLockTimer?.invalidate()
        self.databaseLockTimer = nil

        let mustLock: Bool
        switch reason {
        case .systemEvent:
            mustLock = true
        case .timeout:
            mustLock = Settings.current.isLockDatabasesOnTimeout
        }
        if mustLock {
            DatabaseSettingsManager.shared.eraseAllMasterKeys()
        }
        delegate?.mustCloseDatabase(self, animate: animate)
    }

    func unlockApp() {
        guard let delegate else { return }
        guard delegate.isAppLocked else { return }
        AppEraser.registerSuccessfulAppUnlock()
        delegate.hideAppCover(self)
        delegate.hideAppLock(self)
        restart()
    }
}
