//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
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

    public func removeSettings(for databaseFile: DatabaseFile, onlyIfUnused: Bool) {
        removeSettings(for: databaseFile.descriptor, onlyIfUnused: onlyIfUnused)
    }

    public func removeSettings(for databaseRef: URLReference, onlyIfUnused: Bool) {
        removeSettings(for: databaseRef.getDescriptor(), onlyIfUnused: onlyIfUnused)
    }

    public func forgetAllKeyFiles() {
        let allDatabaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: true
        )
        for dbRef in allDatabaseRefs {
            let dbDescriptor = dbRef.getDescriptor()
            guard let dbSettings = getSettings(for: dbDescriptor) else { continue }
            dbSettings.setAssociatedKeyFile(nil)
            setSettings(dbSettings, for: dbDescriptor)
        }
    }
    
    public func forgetAllHardwareKeys() {
        let allDatabaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: true
        )
        for dbRef in allDatabaseRefs {
            let dbDescriptor = dbRef.getDescriptor()
            guard let dbSettings = getSettings(for: dbDescriptor) else { continue }
            dbSettings.setAssociatedYubiKey(nil)
            setSettings(dbSettings, for: dbDescriptor)
        }
    }

    public func removeAllAssociations(of keyFileRef: URLReference) {
        guard let keyFileDescriptor = keyFileRef.getDescriptor() else { return }
        let allDatabaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: true
        )
        
        for dbRef in allDatabaseRefs {
            let dbDescriptor = dbRef.getDescriptor()
            guard let dbSettings = getSettings(for: dbDescriptor) else { continue }
            if let associatedKeyFile = dbSettings.associatedKeyFile,
               associatedKeyFile.getDescriptor() == keyFileDescriptor
            {
                dbSettings.setAssociatedKeyFile(nil)
                setSettings(dbSettings, for: dbDescriptor)
            }
        }
    }
    
    public func eraseAllMasterKeys() {
        let allDatabaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: true
        )
        for dbRef in allDatabaseRefs {
            let dbDescriptor = dbRef.getDescriptor()
            guard let dbSettings = getSettings(for: dbDescriptor) else { continue }
            dbSettings.clearMasterKey()
            setSettings(dbSettings, for: dbDescriptor)
        }
    }
    
    public func eraseAllFinalKeys() {
        let allDatabaseRefs = FileKeeper.shared.getAllReferences(
            fileType: .database,
            includeBackup: true
        )
        for dbRef in allDatabaseRefs {
            let dbDescriptor = dbRef.getDescriptor()
            guard let dbSettings = getSettings(for: dbDescriptor) else { continue }
            dbSettings.clearFinalKey()
            setSettings(dbSettings, for: dbDescriptor)
        }
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
