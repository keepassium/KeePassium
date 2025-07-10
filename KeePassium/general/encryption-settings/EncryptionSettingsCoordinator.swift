//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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

final class EncryptionSettingsCoordinator: BaseCoordinator {


    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return _router }
    var saveSuccessHandler: (() -> Void)?

    weak var delegate: EncryptionSettingsCoordinatorDelegate?

    private let databaseFile: DatabaseFile
    private let encryptionSettingsVC: EncryptionSettingsVC

    init(databaseFile: DatabaseFile, router: NavigationRouter) {
        self.databaseFile = databaseFile
        guard let db2 = databaseFile.database as? Database2 else {
            fatalError("Requested format upgrade for KDB format, this should be blocked in UI.")
        }
        encryptionSettingsVC = EncryptionSettingsVC(settings: db2.encryptionSettings)
        super.init(router: router)
        encryptionSettingsVC.delegate = self
    }

    override func start() {
        guard ManagedAppConfig.shared.isDatabaseEncryptionSettingsAllowed else {
            Diag.error("Blocked by organization's policy, cancelling")
            _dismissHandler?(self)
            assertionFailure("This action should have been disabled in UI")
            return
        }
        super.start()
        _pushInitialViewController(encryptionSettingsVC, animated: true)
    }
}


extension EncryptionSettingsCoordinator: EncryptionSettingsVCDelegate {
    func didPressDismiss(in viewController: EncryptionSettingsVC) {
        dismiss()
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
            self?.dismiss()
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
