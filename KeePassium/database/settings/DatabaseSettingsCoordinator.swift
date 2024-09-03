//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseSettingsCoordinatorDelegate: AnyObject {
    func didChangeDatabaseSettings(in coordinator: DatabaseSettingsCoordinator)
}

final class DatabaseSettingsCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: DatabaseSettingsCoordinatorDelegate?

    private let router: NavigationRouter
    private let dbRef: URLReference
    private let dbSettingsVC: DatabaseSettingsVC

    init(fileRef: URLReference, router: NavigationRouter) {
        self.dbRef = fileRef
        self.router = router
        dbSettingsVC = DatabaseSettingsVC.make()
        dbSettingsVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(dbSettingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
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
        router.pop(viewController: dbSettingsVC, animated: true, completion: nil)
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
}
