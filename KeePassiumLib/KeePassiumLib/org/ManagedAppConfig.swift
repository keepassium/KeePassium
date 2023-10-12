//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

public final class ManagedAppConfig {
    public static let shared = ManagedAppConfig()

    private enum Key {
        static let managedConfig = "com.apple.configuration.managed"
        static let license = "license"
    }

    private var currentConfig: [String: Any]? {
        guard let rawObject = UserDefaults.standard.object(forKey: Key.managedConfig),
              let config = rawObject as? [String: Any]
        else {
            return nil
        }
        return config
    }
    private var intuneConfig: [String: Any]?

    private init() {
    }

    public func isManaged() -> Bool {
        let isForced = UserDefaults.standard.objectIsForced(forKey: Key.managedConfig)
        return isForced
    }
}

extension ManagedAppConfig {
    public func setIntuneAppConfig(_ config: [[AnyHashable: Any]]?) {
        guard let config = config,
              let firstConfig = config.first 
        else {
            intuneConfig = nil
            Diag.info("No app config provided by Intune")
            return
        }

        var newIntuneConfig = intuneConfig ?? [:]
        newIntuneConfig[Key.license] = firstConfig[Key.license] as? String
        intuneConfig = newIntuneConfig
    }
}

extension ManagedAppConfig {
    internal func getLicenseValue() -> String? {
        let anyValue = intuneConfig?[Key.license] ?? currentConfig?[Key.license]
        guard let rawLicenseValue = anyValue as? String else {
            if BusinessModel.isIntuneEdition {
                Diag.warning("Business license is not configured")
            }
            return nil
        }
        let licenseValue = rawLicenseValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return licenseValue
    }
}
