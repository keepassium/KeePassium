//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseSettingsCoordinatorDelegate: AnyObject {
    func didChangeDatabaseSettings(in coordinator: DatabaseSettingsCoordinator)
}

final class DatabaseSettingsCoordinator: BaseCoordinator {
    weak var delegate: DatabaseSettingsCoordinatorDelegate?

    private let dbRef: URLReference
    private let dbSettingsVC: DatabaseSettingsVC

    init(fileRef: URLReference, router: NavigationRouter) {
        self.dbRef = fileRef
        dbSettingsVC = DatabaseSettingsVC.make()
        super.init(router: router)
        dbSettingsVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(dbSettingsVC, animated: true)
        let dsm = DatabaseSettingsManager.shared
        dbSettingsVC.isReadOnlyAccess = dsm.isReadOnly(dbRef)
        dbSettingsVC.isQuickTypeEnabled = dsm.isQuickTypeEnabled(dbRef)
        dbSettingsVC.fallbackStrategy = dsm.getFallbackStrategy(dbRef, forAutoFill: false)
        dbSettingsVC.autoFillFallbackStrategy = dsm.getFallbackStrategy(dbRef, forAutoFill: true)
        dbSettingsVC.availableFallbackStrategies = dsm.getAvailableFallbackStrategies(dbRef)
        dbSettingsVC.fallbackTimeout = dsm.getFallbackTimeout(dbRef, forAutoFill: false)
        dbSettingsVC.autoFillFallbackTimeout = dsm.getFallbackTimeout(dbRef, forAutoFill: true)
        dbSettingsVC.externalUpdateBehavior = dsm.getExternalUpdateBehavior(dbRef)
    }
}

extension DatabaseSettingsCoordinator: DatabaseSettingsDelegate {
    func didPressClose(in viewController: DatabaseSettingsVC) {
        _router.pop(viewController: dbSettingsVC, animated: true, completion: nil)
    }

    func canChangeReadOnly(in viewController: DatabaseSettingsVC) -> Bool {
        switch dbRef.location {
        case .internalBackup: 
            return false
        case .external,
             .remote,
             .internalDocuments,
             .internalInbox:
            return true
        }
    }

    func canChangeQuickTypeEnabled(in viewController: DatabaseSettingsVC) -> Bool {
        return Settings.current.isQuickTypeEnabled
    }

    func didChangeSettings(isReadOnlyFile: Bool, in viewController: DatabaseSettingsVC) {
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.isReadOnlyFile = isReadOnlyFile
        }
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didChangeSettings(isQuickTypeEnabled: Bool, in viewController: DatabaseSettingsVC) {
        if !isQuickTypeEnabled {
            QuickTypeAutoFillStorage.removeAll()
        }
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.isQuickTypeEnabled = isQuickTypeEnabled
        }
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didChangeSettings(
        newFallbackStrategy: UnreachableFileFallbackStrategy,
        forAutoFill: Bool,
        in viewController: DatabaseSettingsVC
    ) {
        if forAutoFill {
            DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
                dbSettings.autofillFallbackStrategy = newFallbackStrategy
            }
            viewController.autoFillFallbackStrategy = newFallbackStrategy
        } else {
            DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
                dbSettings.fallbackStrategy = newFallbackStrategy
            }
            viewController.fallbackStrategy = newFallbackStrategy
        }
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didChangeSettings(
        newFallbackTimeout: TimeInterval,
        forAutoFill: Bool,
        in viewController: DatabaseSettingsVC
    ) {
        if forAutoFill {
            DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
                dbSettings.autofillFallbackTimeout = newFallbackTimeout
            }
            viewController.autoFillFallbackTimeout = newFallbackTimeout
        } else {
            DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
                dbSettings.fallbackTimeout = newFallbackTimeout
            }
            viewController.fallbackTimeout = newFallbackTimeout
        }
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didChangeSettings(
        newExternalUpdateBehavior: ExternalUpdateBehavior,
        in viewController: DatabaseSettingsVC
    ) {
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.externalUpdateBehavior = newExternalUpdateBehavior
        }
        viewController.externalUpdateBehavior = newExternalUpdateBehavior
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didPressDataProtection(in viewController: DatabaseSettingsVC) {
        let databaseSettingsDataProtectionVC = DatabaseSettingsDataProtectionVC.make(delegate: self)

        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: dbRef)
        databaseSettingsDataProtectionVC.rememberMasterKey = dbSettings?.isRememberMasterKey
        databaseSettingsDataProtectionVC.rememberKeyFile = dbSettings?.isRememberKeyFile
        databaseSettingsDataProtectionVC.cachesDerivedEncryptionKey = dbSettings?.isRememberFinalKey

        _router.push(databaseSettingsDataProtectionVC, animated: true, onPop: nil)
    }
}

extension DatabaseSettingsCoordinator: DatabaseSettingsDataProtectionVCDelegate {
    func didChangeRememberMasterKey(
        _ rememberMasterKey: Bool?,
        in viewController: DatabaseSettingsDataProtectionVC
    ) {
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.isRememberMasterKey = rememberMasterKey

            viewController.rememberMasterKey = dbSettings.isRememberMasterKey

            if dbSettings.isRememberMasterKey == false ||
               (rememberMasterKey == nil && !Settings.current.isRememberDatabaseKey) {
                dbSettings.clearMasterKey()
            }
        }
        viewController.showNotificationIfManaged(setting: .rememberDatabaseKey)
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didChangeRememberKeyFile(
        _ rememberKeyFile: Bool?,
        in viewController: DatabaseSettingsDataProtectionVC
    ) {
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.isRememberKeyFile = rememberKeyFile

            viewController.rememberKeyFile = dbSettings.isRememberKeyFile
        }
        viewController.showNotificationIfManaged(setting: .keepKeyFileAssociations)
        delegate?.didChangeDatabaseSettings(in: self)
    }

    func didChangeRememberDerivedKey(
        _ rememberDerivedKey: Bool?,
        in viewController: DatabaseSettingsDataProtectionVC
    ) {
        DatabaseSettingsManager.shared.updateSettings(for: dbRef) { dbSettings in
            dbSettings.isRememberFinalKey = rememberDerivedKey

            viewController.cachesDerivedEncryptionKey = dbSettings.isRememberFinalKey

            if dbSettings.isRememberFinalKey == false ||
               (rememberDerivedKey == nil && !Settings.current.isRememberDatabaseFinalKey) {
                dbSettings.clearFinalKey()
            }
        }
        viewController.showNotificationIfManaged(setting: .rememberDatabaseFinalKey)
        delegate?.didChangeDatabaseSettings(in: self)
    }
}
