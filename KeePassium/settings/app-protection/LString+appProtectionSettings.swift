//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension LString {
    // swiftlint:disable line_length
    public static let appLockWithBiometricsSubtitleTemplate = NSLocalizedString(
        "[Settings/AppLock/subtitle] App Lock, %@, timeout",
        value: "App Lock, %@, timeout",
        comment: "Settings: subtitle of the `App Protection` section. biometryTypeName will be either 'Touch ID' or 'Face ID'. [biometryTypeName: String]")
    public static let appLockWithPasscodeSubtitle = NSLocalizedString(
        "[Settings/AppLock/subtitle] App Lock, passcode, timeout",
        value: "App Lock, passcode, timeout",
        comment: "Settings: subtitle of the `App Protection` section when biometric auth is not available.")

    public static let titleAppProtection = titleAppProtectionSettings
    public static let titleAppProtectionSettings = NSLocalizedString(
        "[Settings/AppLock/title]",
        value: "App Protection",
        comment: "Settings section: protection of the app from unauthorized access")
    public static let callToActionActivateAppProtection = NSLocalizedString(
        "[Settings/AppLoc/Activate/callToAction]",
        value: "Activate App Protection",
        comment: "Call to action (protect the app from unauthorized access)")
    public static let appProtectionDescription = NSLocalizedString(
        "[Settings/AppLock/Activate/description]",
        value: "Protect KeePassium from unauthorized access.",
        comment: "Description of `Activate app protection` call to action.")
    public static let titleUseBiometryTypeTemplate = NSLocalizedString(
        "[Settings/AppLock/Biometric/title] Use %@",
        value: "Use %@",
        comment: "Settings switch: whether App Protection is allowed to use Touch ID/Face ID. Example: 'Use Touch ID'. [biometryTypeName: String]")
    public static let biometricAppProtectionDescription = NSLocalizedString(
        "[Settings/AppLock/Biometric/description]",
        value: "Allows biometric authentication as a quick (but less secure) alternative to passcode.",
        comment: "Description of biometric unlock settings")

    public static let appProtectionTimeoutTitle = NSLocalizedString(
        "[Settings/AppLock/Timeout/title]",
        value: "Timeout",
        comment: "Title for App Lock Timeout setting")
    public static let appProtectionTimeoutDescription = NSLocalizedString(
        "[Settings/AppLock/Timeout/description]",
        value: "The app will automatically lock up after this time.",
        comment: "Description of the App Lock Timeout setting")
    public static let appProtectionTimeoutNeverTitle = NSLocalizedString(
        "[Settings/AppLockTimeout/Never/title]",
        value: "Never",
        comment: "An option in Settings. Will be shown as 'App Lock: Timeout: Never'")
    public static let appProtectionTimeoutImmediatelyTitle = NSLocalizedString(
        "[Settings/AppLockTimeout/Immediately/title] ",
        value: "Immediately",
        comment: "An option in Settings. Will be shown as 'App Lock: Timeout: Immediately'")
    public static let appProtectionTimeoutAfterLeavingAppDescription = NSLocalizedString(
        "[Settings/AppLockTimeout/AfterLeavingApp/description]",
        value: "After leaving the app",
        comment: "Description of those 'App Protection Timeout' options that trigger when the app is minimized. For example: 'Timeout: 3 seconds (After leaving the app)")
    public static let appProtectionTimeoutAfterLastInteractionDescription = NSLocalizedString(
        "[Settings/AppLockTimeout/description] After last interaction",
        value: "After last interaction",
        comment: "Description of those 'App Protection Timeout' options that trigger when the user has been idle for a while. For example: 'Timeout: 3 seconds (After last interaction)")

    public static let lockAppOnScreenLockTitle = NSLocalizedString(
        "[Settings/AppLock/LockOnScreenLock/title]",
        value: "Lock on macOS Screen Lock",
        comment: "Title of a yes/no setting: whether to lock app when computer screen is locked (see https://support.apple.com/en-gb/guide/mac-help/mchl8e8b6a34/mac)")
    public static let lockAppOnScreenLockDescription = NSLocalizedString(
        "[Settings/AppLock/LockOnScreenLock/description]",
        value: "Ensures KeePassium is locked when you lock your Mac.",
        comment: "Explanation for the `Lock on macOS Screen Lock` setting")
    public static let lockAppOnLaunchTitle = NSLocalizedString(
        "[Settings/AppLock/LockOnLaunch/title]",
        value: "Lock on App Launch",
        comment: "Setting switch: whether to lock the app after it was terminated and relaunched.")
    public static let lockAppOnLaunchDescription = NSLocalizedString(
        "[Settings/AppLock/LockOnLaunch/description]",
        value: "Ensures KeePassium is locked after you force-close the app or restart the device.",
        comment: "Explanation for the `Lock on App Launch` setting")

    public static let wrongPasscodeTitle = NSLocalizedString(
        "[Settings/AppLock/WrongPasscode/title]",
        value: "Wrong Passcode",
        comment: "Settings section: what happens if user enters incorrect App Protection passcode.")

    public static let lockOnWrongPasscodeTitle = NSLocalizedString(
        "[Settings/AppLock/LockOnWrongPasscode/title]",
        value: "Lock on Wrong Passcode",
        comment: "Title in the settings: whether to lock databases when user enters a wrong app protection passcode.")
    public static let lockOnWrongPasscodeDescription = NSLocalizedString(
        "[Settings/AppLock/LockOnWrongPasscode/description]",
        value: "If you enter a wrong app protection passcode, KeePassium will close all databases and clear all master keys from the keychain.",
        comment: "Description of the `Lock on Wrong Passcode` setting")

    public static let passcodeAttemptsUntilAppResetTitle = NSLocalizedString(
        "[Settings/AppLock/PasscodeAttemptsUntilAppReset/title]",
        value: "Attempts Until App Reset",
        comment: "Title in the settings: number of failed passcode attempts that will reset the app into 'just installed' state.")
    public static let passcodeAttemptsUntilAppResetDescription = NSLocalizedString(
        "[Settings/AppLock/PasscodeAttemptsUntilAppReset/description]",
        value: "App reset will delete all the stored keys, settings, database backups, imported files, and links to external files. However, if app reset is triggered from AutoFill, imported files may remain due to technical limitations.",
        comment: "Description of the `Passcode Attempts Until App Reset` setting")
    public static let passcodeAttemptsUntilAppResetNeverTitle = NSLocalizedString(
        "[Settings/AppLock/PasscodeAttemptsUntilAppReset/Never/title]",
        value: "Do not reset",
        comment: "An option in Settings. Will be shown as 'Passcode Attempts Until App Reset: Do not reset'")
    // swiftlint:enable line_length
}

extension Settings.AppLockTimeout {
    public var fullTitle: String {
        switch self {
        case .never:
            return LString.appProtectionTimeoutNeverTitle
        case .immediately:
            return LString.appProtectionTimeoutImmediatelyTitle
        default:
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.collapsesLargestUnit = true
            formatter.maximumUnitCount = 2
            formatter.unitsStyle = .full
            guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                assertionFailure()
                return "?"
            }
            return result
        }
    }
    public var shortTitle: String {
        switch self {
        case .never:
            return LString.appProtectionTimeoutNeverTitle
        case .immediately:
            return LString.appProtectionTimeoutImmediatelyTitle
        default:
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute, .second]
            formatter.collapsesLargestUnit = true
            formatter.maximumUnitCount = 2
            formatter.unitsStyle = .brief
            guard let result = formatter.string(from: TimeInterval(self.rawValue)) else {
                assertionFailure()
                return "?"
            }
            return result
        }
    }
    public var description: String? {
        switch triggerMode {
        case .appMinimized:
            return LString.appProtectionTimeoutAfterLeavingAppDescription
        case .userIdle:
            return LString.appProtectionTimeoutAfterLastInteractionDescription
        }
    }
}

extension Settings.PasscodeAttemptsBeforeAppReset {
    public var title: String {
        switch self {
        case .never:
            return LString.passcodeAttemptsUntilAppResetNeverTitle
        case .after1, .after3, .after5, .after10:
            return String(rawValue)
        }
    }
}
