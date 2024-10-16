//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib

protocol EncryptionSettingsCoordinatorDelegate: AnyObject {
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

final class EncryptionSettingsCoordinator: Coordinator {


    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }
    var saveSuccessHandler: (() -> Void)?

    weak var delegate: EncryptionSettingsCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseFile: DatabaseFile
    private let encryptionSettingsVC: EncryptionSettingsVC

    init(databaseFile: DatabaseFile, router: NavigationRouter) {
        self.databaseFile = databaseFile
        self.router = router

        guard let db2 = databaseFile.database as? Database2 else {
            fatalError("Requested format upgrade for KDB format, this should be blocked in UI.")
        }

        encryptionSettingsVC = EncryptionSettingsVC(settings: db2.encryptionSettings)
        encryptionSettingsVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        guard ManagedAppConfig.shared.isDatabaseEncryptionSettingsAllowed else {
            Diag.error("Blocked by organization's policy, cancelling")
            dismissHandler?(self)
            assertionFailure("This action should have been disabled in UI")
            return
        }

        router.push(encryptionSettingsVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
}


extension EncryptionSettingsCoordinator: EncryptionSettingsVCDelegate {
    func didPressDismiss(in viewController: EncryptionSettingsVC) {
        router.dismiss(animated: true)
    }

    func didPressDone(in viewController: EncryptionSettingsVC, settings: EncryptionSettings) {
        guard let db2 = databaseFile.database as? Database2 else {
            assertionFailure("Requested format upgrade for KDB format, this should be blocked in UI.")
            return
        }

        if let newFormat = db2.formatUpgradeRequired(for: settings),
            db2.formatVersion.hasMajorDifferences(with: newFormat) {
            Diag.info("Chosen encryption settings need \(newFormat), silently upgrading")
            db2.upgradeFormatVersion(to: newFormat)
        }

        Diag.info("Changing database encryption settings [settings: \(settings)]")
        db2.applyEncryptionSettings(settings: settings)

        saveDatabase(databaseFile) { [weak self] in
            self?.router.dismiss(animated: true)
        }
    }
}


extension EncryptionSettingsCoordinator: DatabaseSaving {
    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return encryptionSettingsVC
    }
}
