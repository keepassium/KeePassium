//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

enum AppEraser {
    private static let failedAttemptsKey = "com.keepassium.failedAppUnlockAttempts"

    public static func resetApp(completion: (() -> Void)?) {
        Diag.warning("Erasing all app data")
        Keychain.shared.reset()
        UserDefaults.eraseAppGroupShared()
        FileKeeper.shared.deleteAllInternalFiles { [self] in
            setFailedUnlockAttempts(0)
            completion?()
        }
    }

    static func registerFailedAppPasscodeAttempt(afterReset: @escaping (() -> Void)) -> Bool {
        let maxAttempts = Settings.current.passcodeAttemptsBeforeAppReset
        if maxAttempts == .never {
            return false
        }

        let attempts = getFailedUnlockAttempts() + 1
        setFailedUnlockAttempts(attempts)

        Diag.debug("Failed app unlock attempt: \(attempts)/\(maxAttempts.rawValue)")
        let mustReset = attempts >= maxAttempts.rawValue
        if mustReset {
            Diag.warning("Passcode attempts limit reached, resetting the app")
            AppEraser.resetApp(completion: afterReset)
        }
        return mustReset
    }

    static func registerSuccessfulAppUnlock() {
        setFailedUnlockAttempts(0)
    }

    private static func getFailedUnlockAttempts() -> Int {
        return UserDefaults.appGroupShared.integer(forKey: Self.failedAttemptsKey)
    }

    private static func setFailedUnlockAttempts(_ count: Int) {
        UserDefaults.appGroupShared.set(count, forKey: Self.failedAttemptsKey)
        UserDefaults.appGroupShared.synchronize()
    }
}
