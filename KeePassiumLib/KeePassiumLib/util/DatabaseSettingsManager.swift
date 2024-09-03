//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

public class DatabaseSettingsManager {
    public static let shared = DatabaseSettingsManager()

    init() {
    }

    public func getSettings(for databaseFile: DatabaseFile) -> DatabaseSettings? {
        return getSettings(for: databaseFile.descriptor)
    }

    public func getSettings(for databaseRef: URLReference) -> DatabaseSettings? {
        return getSettings(for: databaseRef.getDescriptor())
    }

    public func getOrMakeSettings(for databaseFile: DatabaseFile) -> DatabaseSettings {
        return getOrMakeSettings(for: databaseFile.descriptor)
    }

    public func getOrMakeSettings(for databaseRef: URLReference) -> DatabaseSettings {
        return getOrMakeSettings(for: databaseRef.getDescriptor())
    }

    public func setSettings(_ dbSettings: DatabaseSettings, for databaseFile: DatabaseFile) {
        setSettings(dbSettings, for: databaseFile.descriptor)
    }

    public func setSettings(_ dbSettings: DatabaseSettings, for databaseRef: URLReference) {
        setSettings(dbSettings, for: databaseRef.getDescriptor())
    }

    public func updateSettings(for databaseFile: DatabaseFile, updater: (DatabaseSettings) -> Void) {
        updateSettings(for: databaseFile.descriptor, updater: updater)
    }

    public func updateSettings(for databaseRef: URLReference, updater: (DatabaseSettings) -> Void) {
        updateSettings(for: databaseRef.getDescriptor(), updater: updater)
    }

    public func removeSettings(for databaseRef: URLReference, onlyIfUnused: Bool) {
        removeSettings(for: databaseRef.getDescriptor(), onlyIfUnused: onlyIfUnused)
        if isQuickTypeEnabled(databaseRef) {
            QuickTypeAutoFillStorage.removeAll()
        }
    }

    public func forgetAllKeyFiles() {
        do {
            try updateAllSettings { $0.setAssociatedKeyFile(nil) }
        } catch {
            Diag.error("Failed to forget all key files associations [message: \(error.localizedDescription)]")
        }
    }

    public func forgetAllHardwareKeys() {
        do {
            try updateAllSettings { $0.setAssociatedYubiKey(nil) }
        } catch {
            Diag.error("Failed to forget all hardware key associations [message: \(error.localizedDescription)]")
        }
    }

    public func removeAllAssociations(of keyFileRef: URLReference) {
        guard let keyFileDescriptor = keyFileRef.getDescriptor() else { return }
        do {
            try updateAllSettings { dbSettings in
                if let associatedKeyFile = dbSettings.associatedKeyFile,
                   associatedKeyFile.getDescriptor() == keyFileDescriptor
                {
                    dbSettings.setAssociatedKeyFile(nil)
                }
            }
        } catch {
            Diag.error("Failed to remove links to key file [message: \(error.localizedDescription)]")
        }
    }

    public func eraseAllMasterKeys() {
        do {
            try updateAllSettings { $0.clearMasterKey() }
        } catch {
            Diag.error("Failed to erase all master keys [message: \(error.localizedDescription)]")
        }
    }

    public func eraseAllFinalKeys() {
        do {
            try updateAllSettings { $0.clearFinalKey() }
        } catch {
            Diag.error("Failed to erase all master keys [message: \(error.localizedDescription)]")
        }
    }


    public func isReadOnly(_ databaseRef: URLReference) -> Bool {
        switch databaseRef.location {
        case .internalBackup:
            return true
        case .external,
             .remote,
             .internalDocuments,
             .internalInbox:
            break
        }

        guard let dbSettings = getSettings(for: databaseRef) else {
            return false
        }
        return dbSettings.isReadOnlyFile
    }

    public func isQuickTypeEnabled(_ databaseFile: DatabaseFile) -> Bool {
        let isEnabledForApp = Settings.current.premiumIsQuickTypeEnabled
        if let isEnabledForDB = getSettings(for: databaseFile)?.isQuickTypeEnabled {
            return isEnabledForDB && isEnabledForApp
        } else {
            return isEnabledForApp
        }
    }

    public func isQuickTypeEnabled(_ databaseRef: URLReference) -> Bool {
        let isEnabledForApp = Settings.current.premiumIsQuickTypeEnabled
        if let isEnabledForDB = getSettings(for: databaseRef)?.isQuickTypeEnabled {
            return isEnabledForDB && isEnabledForApp
        } else {
            return isEnabledForApp
        }
    }

    public func getQuickTypeDatabaseCount() -> Int {
        let allDatabaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: false
        )
        let quickTypeDatabases = allDatabaseRefs.filter { isQuickTypeEnabled($0) }
        return quickTypeDatabases.count
    }

    public func getAvailableFallbackStrategies(
        _ databaseRef: URLReference
    ) -> Set<UnreachableFileFallbackStrategy> {
        switch databaseRef.location {
        case .internalBackup,
             .internalInbox:
            return [.showError]
        case .external:
            return [.showError, .useCache, .reAddDatabase]
        case .internalDocuments,
             .remote:
            return [.showError, .useCache]
        }
    }

    public func getFallbackStrategy(
        _ databaseRef: URLReference,
        forAutoFill: Bool
    ) -> UnreachableFileFallbackStrategy {
        switch databaseRef.location {
        case .internalBackup,
             .internalInbox:
            return .showError
        case .internalDocuments,
             .external,
             .remote:
            if forAutoFill,
               let autoFillValue = getSettings(for: databaseRef)?.autofillFallbackStrategy
            {
                return autoFillValue
            }
            return getSettings(for: databaseRef)?.fallbackStrategy ?? .useCache
        }
    }

    public func getFallbackTimeout(_ databaseRef: URLReference, forAutoFill: Bool) -> TimeInterval {
        if forAutoFill,
           let autoFillValue = getSettings(for: databaseRef)?.autofillFallbackTimeout
        {
            return autoFillValue
        }
        return getSettings(for: databaseRef)?.fallbackTimeout ?? URLReference.defaultTimeoutDuration
    }

    public func getExternalUpdateBehavior(_ databaseRef: URLReference) -> ExternalUpdateBehavior {
        return getSettings(for: databaseRef)?.externalUpdateBehavior ?? .checkAndNotify
    }

    private func getSettings(for descriptor: URLReference.Descriptor?) -> DatabaseSettings? {
        guard let descriptor = descriptor else {
            Diag.warning("Cannot get database descriptor")
            assertionFailure()
            return nil
        }
        do {
            if let dbSettings = try Keychain.shared.getDatabaseSettings(for: descriptor) { 
                return dbSettings
            }
            return nil
        } catch {
            Diag.warning(error.localizedDescription)
            return nil
        }
    }

    private func getOrMakeSettings(for descriptor: URLReference.Descriptor?) -> DatabaseSettings {
        guard let descriptor = descriptor else {
            Diag.warning("Cannot get database descriptor")
            assertionFailure()
            return DatabaseSettings()
        }
        if let storedSettings = getSettings(for: descriptor) {
            return storedSettings
        }
        let defaultResult = DatabaseSettings()
        return defaultResult
    }

    private func setSettings(_ dbSettings: DatabaseSettings, for descriptor: URLReference.Descriptor?) {
        guard let descriptor = descriptor else {
            Diag.warning("Cannot get database descriptor")
            assertionFailure()
            return
        }

        do {
            try Keychain.shared.setDatabaseSettings(dbSettings, for: descriptor) 
        } catch {
            Diag.error(error.localizedDescription)
        }
    }

    private func updateSettings(for descriptor: URLReference.Descriptor?, updater: (DatabaseSettings) -> Void) {
        let dbSettings = getOrMakeSettings(for: descriptor)
        updater(dbSettings)
        setSettings(dbSettings, for: descriptor)
    }

    private func updateAllSettings(updater: (DatabaseSettings) -> Void) throws {
        try Keychain.shared.updateAllDatabaseSettings(updater: updater)
    }

    private func removeSettings(for descriptor: URLReference.Descriptor?, onlyIfUnused: Bool) {
        guard let descriptor = descriptor else {
            Diag.warning("Cannot get database descriptor")
            assertionFailure()
            return
        }

        if onlyIfUnused {
            let allDatabaseDescriptors = FileKeeper.shared.getAllReferences(
                fileType: .database,
                includeBackup: true)
                .map { $0.getDescriptor() }
            if allDatabaseDescriptors.contains(descriptor) {
                return
            }
        }

        do {
            try Keychain.shared.removeDatabaseSettings(for: descriptor)
        } catch {
            Diag.error(error.localizedDescription)
        }
    }
}
