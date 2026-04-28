//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import Foundation

extension Settings {
    public var isAutoFillFinishedOK: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillFinishedOK.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            _updateAndNotify(
                oldValue: isAutoFillFinishedOK,
                newValue: newValue,
                key: Keys.autoFillFinishedOK)

            UserDefaults.appGroupShared.synchronize()
        }
    }

    public var isCopyTOTPOnAutoFill: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.copyTOTPOnAutoFill.rawValue)
                as? Bool

            if #available(iOS 18, *) {
                return stored ?? false
            } else {
                return stored ?? true
            }
        }
        set {
            _updateAndNotify(
                oldValue: isCopyTOTPOnAutoFill,
                newValue: newValue,
                key: .copyTOTPOnAutoFill)
        }
    }

    public var autoFillPerfectMatch: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillPerfectMatch.rawValue)
                as? Bool
            return stored ?? true
        }
        set {
            _updateAndNotify(
                oldValue: autoFillPerfectMatch,
                newValue: newValue,
                key: .autoFillPerfectMatch)
        }
    }

    public var acceptAutoFillInput: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.acceptAutoFillInput.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            _updateAndNotify(
                oldValue: acceptAutoFillInput,
                newValue: newValue,
                key: .acceptAutoFillInput)
        }
    }

    public var isQuickTypeEnabled: Bool {
        get {
            if let managedValue = ManagedAppConfig.shared.getBoolIfLicensed(.enableQuickTypeAutoFill) {
                return managedValue
            }
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.quickTypeEnabled.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            _updateAndNotify(
                oldValue: isQuickTypeEnabled,
                newValue: newValue,
                key: .quickTypeEnabled)
        }
    }
}

extension Settings {
    public var autoFillContextSavingMode: AutoFillContextSavingMode {
        get {
            if let rawValue = UserDefaults.appGroupShared
                    .string(forKey: Keys.autoFillContextSavingMode.rawValue),
               let mode = AutoFillContextSavingMode(rawValue: rawValue)
            {
                return mode
            }
            return .inactive
        }
        set {
            _updateAndNotify(
                oldValue: autoFillContextSavingMode.rawValue,
                newValue: newValue.rawValue,
                key: .autoFillContextSavingMode)
        }
    }

    public var autoFillContextSavingModeChosenTimestamp: Date? {
        get {
            if let storedTimestamp = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillContextSavingModeChosenTimestamp.rawValue) as? Date
            {
                return storedTimestamp
            }
            return nil
        }
        set {
            UserDefaults.appGroupShared
                .set(newValue, forKey: Keys.autoFillContextSavingModeChosenTimestamp.rawValue)
            if newValue != autoFillContextSavingModeChosenTimestamp {
                _postChangeNotification(changedKey: .autoFillContextSavingModeChosenTimestamp)
            }
        }
    }
}

extension Settings {
    public var isAutoFillIncludeExpiredEntries: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillIncludeExpiredEntries.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            _updateAndNotify(
                oldValue: isAutoFillIncludeExpiredEntries,
                newValue: newValue,
                key: .autoFillIncludeExpiredEntries)
        }
    }

    public var isAutoFillIncludeEntriesWithAutoFillDisabled: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillIncludeEntriesWithAutoFillDisabled.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            _updateAndNotify(
                oldValue: isAutoFillIncludeEntriesWithAutoFillDisabled,
                newValue: newValue,
                key: .autoFillIncludeEntriesWithAutoFillDisabled)
        }
    }

    public var isAutoFillIncludeGroupsWithAutoFillDisabled: Bool {
        get {
            let stored = UserDefaults.appGroupShared
                .object(forKey: Keys.autoFillIncludeGroupsWithAutoFillDisabled.rawValue)
                as? Bool
            return stored ?? false
        }
        set {
            _updateAndNotify(
                oldValue: isAutoFillIncludeGroupsWithAutoFillDisabled,
                newValue: newValue,
                key: .autoFillIncludeGroupsWithAutoFillDisabled)
        }
    }

    public var autoFillInclusionOptions: AutoFillInclusionOptions {
        var options: AutoFillInclusionOptions = []

        if isAutoFillIncludeExpiredEntries {
            options.insert(.expiredEntries)
        }
        if isAutoFillIncludeEntriesWithAutoFillDisabled {
            options.insert(.entriesWithAutoFillDisabled)
        }
        if isAutoFillIncludeGroupsWithAutoFillDisabled {
            options.insert(.groupsWithAutoFillDisabled)
        }

        return options
    }
}
