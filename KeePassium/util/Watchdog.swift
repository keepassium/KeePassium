//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol WatchdogDelegate: class {
    var isAppCoverVisible: Bool { get }
    func showAppCover(_ sender: Watchdog)
    func hideAppCover(_ sender: Watchdog)
    
    var isAppLockVisible: Bool { get }
    func showAppLock(_ sender: Watchdog)
    func hideAppLock(_ sender: Watchdog)

    func watchdogDidCloseDatabase(_ sender: Watchdog)
}

extension WatchdogDelegate {
    var isAppCoverVisible: Bool { return false }
    func showAppCover(_ sender: Watchdog) { }
    func hideAppCover(_ sender: Watchdog) { }
    var isAppLockVisible: Bool { return false }
    func showAppLock(_ sender: Watchdog) { }
    func hideAppLock(_ sender: Watchdog) { }
    func watchdogDidCloseDatabase(_ sender: Watchdog) { }
}

fileprivate extension WatchdogDelegate {
    var isAppLocked: Bool {
        return isAppLockVisible
    }
}

class Watchdog {
    public static let shared = Watchdog()
    
    public enum Notifications {
        public static let appLockDidEngage = Notification.Name("com.keepassium.Watchdog.appLockDidEngage")
        public static let databaseLockDidEngage = Notification.Name("com.keepassium.Watchdog.databaseLockDidEngage")
    }
    
    public var isDatabaseTimeoutExpired: Bool {
        if _isDatabaseTimeoutExpired {
           _isDatabaseTimeoutExpired = false
            return true
        } else {
            return false
        }
    }
    private var _isDatabaseTimeoutExpired = false
    
    private var isAppLaunchHandled = false
    
    public weak var delegate: WatchdogDelegate?
    
    private var appLockTimer: Timer?
    private var databaseLockTimer: Timer?
    private var isIgnoringMinimizationOnce = false
    
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
    }
    
    
    @objc private func appDidBecomeActive(_ notification: Notification) {
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
        delegate?.hideAppCover(self)
    }
    
    @objc private func appWillResignActive(_ notification: Notification) {
        willResignActive()
    }
    
    internal func willResignActive() {
        Diag.debug("App will resign active")
        guard let delegate = delegate else { return }
        delegate.showAppCover(self)
        if delegate.isAppLocked { return }

        let databaseTimeout = Settings.current.premiumDatabaseLockTimeout
        if databaseTimeout == .immediately && !isIgnoringMinimizationOnce {
            Diag.debug("Going to background: Database Lock engaged")
            engageDatabaseLock()
        }
        
        let appTimeout = Settings.current.appLockTimeout
        if appTimeout.triggerMode == .appMinimized && !isIgnoringMinimizationOnce {
            Diag.debug("Going to background: App Lock engaged")
            Watchdog.shared.restart() 
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
    
    @objc private func maybeLockDatabase() {
        if isShouldEngageDatabaseLock() {
            engageDatabaseLock()
        }
    }
    
    open func ignoreMinimizationOnce() {
        assert(!isIgnoringMinimizationOnce)
        isIgnoringMinimizationOnce = true
    }
    
    open func restart() {
        guard let delegate = delegate else { return }
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
            return secondsPassed > Double(timeout.seconds)
        }
    }
    
    private func isShouldEngageDatabaseLock() -> Bool {
        let timeout = Settings.current.premiumDatabaseLockTimeout
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
            return secondsPassed > Double(timeout.seconds)
        }
    }
    
    private func restartAppTimer() {
        if let appLockTimer = appLockTimer {
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
        if let databaseLockTimer = databaseLockTimer {
            databaseLockTimer.invalidate()
        }
        
        let timeout = Settings.current.premiumDatabaseLockTimeout
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
        guard let delegate = delegate else { return }
        guard !delegate.isAppLocked else { return }
        Diag.info("Engaging App Lock")
        appLockTimer?.invalidate()
        appLockTimer = nil
        delegate.showAppLock(self)
        NotificationCenter.default.post(name: Watchdog.Notifications.appLockDidEngage, object: self)
    }
    
    private func engageDatabaseLock() {
        Diag.info("Engaging Database Lock")
        self.databaseLockTimer?.invalidate()
        self.databaseLockTimer = nil
        
        let isLockDatabases = Settings.current.premiumIsLockDatabasesOnTimeout
        if isLockDatabases {
            DatabaseSettingsManager.shared.eraseAllMasterKeys()
        }
        DatabaseManager.shared.closeDatabase(
            clearStoredKey: isLockDatabases,
            ignoreErrors: true,
            completion: { 
                (errorMessage) in 
                self.delegate?.watchdogDidCloseDatabase(self)
                NotificationCenter.default.post(
                    name: Watchdog.Notifications.databaseLockDidEngage,
                    object: self)
            })
    }
    
    open func unlockApp() {
        guard let delegate = delegate else { return }
        guard delegate.isAppLocked else { return }
        delegate.hideAppCover(self)
        delegate.hideAppLock(self)
        restart()
    }
}
