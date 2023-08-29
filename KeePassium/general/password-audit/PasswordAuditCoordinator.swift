//  KeePassium Password Manager
//  Copyright © 2018-2023 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation
import KeePassiumLib
import UIKit

protocol PasswordAuditCoordinatorDelegate: AnyObject {
    func didPressEditEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        onDismiss: @escaping () -> Void)
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL)
}

final class PasswordAuditCoordinator: Coordinator {


    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    var databaseSaver: DatabaseSaver?
    var fileExportHelper: FileExportHelper?
    var savingProgressHost: ProgressViewHost? { return router }

    weak var delegate: PasswordAuditCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseFile: DatabaseFile
    private let passwordAuditService: PasswordAuditService
    private var passwordAuditResultsVC: PasswordAuditResultsVC?


    init(databaseFile: DatabaseFile, router: NavigationRouter) {
        self.databaseFile = databaseFile
        self.router = router
        
        var allEntries = [Entry]()
        databaseFile.database.root?.collectAllEntries(to: &allEntries)
        self.passwordAuditService = PasswordAuditService(
            hibpService: HIBPService(),
            entries: allEntries)
        self.passwordAuditService.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }


    func start() {
        let passwordAuditVC = PasswordAuditVC.instantiateFromStoryboard()
        passwordAuditVC.delegate = self

        router.push(passwordAuditVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }

    private func showResults(results: [PasswordAuditService.PasswordAudit]) {
        let passwordAuditResultsVC = PasswordAuditResultsVC.instantiateFromStoryboard()
        passwordAuditResultsVC.items = results
        passwordAuditResultsVC.allowedActions = getAllowedActionsForResults()
        passwordAuditResultsVC.delegate = self
        router.push(passwordAuditResultsVC, animated: true, onPop: nil)
    }
    
    private func getAllowedActionsForResults() -> [PasswordAuditResultsVC.AllowedAction] {
        if databaseFile.status.contains(.readOnly) {
            return []
        }
        if databaseFile.database is Database2 {
            return [.edit, .delete, .exclude]
        } else {
            return [.edit, .delete]
        }
    }

    private func performAudit() {
        router.showProgressView(
            title: LString.statusAuditingPasswords,
            allowCancelling: true,
            animated: true
        )

        passwordAuditService.performAudit { [weak self] result in
            guard let self else { return }
            switch result {
            case let .success(results):
                self.router.hideProgressView()
                self.showResults(results: results)
            case .failure(.canceled):
                self.router.hideProgressView(animated: true)
            case let .failure(error):
                Diag.error("Password audit failed [message: \(error.localizedDescription)]")
                self.showError(error.localizedDescription)
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: LString.titleError,
            message: String.localizedStringWithFormat(
                LString.Error.passwordAuditErrorTemplate,
                message),
            preferredStyle: .alert
        )
        alert.addAction(title: LString.actionCancel, style: .cancel) { [weak self] _ in
            self?.router.hideProgressView(animated: true)
        }
        alert.addAction(title: LString.actionRetry, style: .default) { [weak self] _ in
            Diag.info("Retrying password audit")
            self?.performAudit()
        }
        router.present(alert, animated: true, completion: nil)
    }
}


extension PasswordAuditCoordinator: PasswordAuditVCDelegate {
    func userDidDismiss() {
        router.dismiss(animated: true)
    }

    func userDidRequestStartPasswordAudit() {
        performAudit()
    }

    func passwordAuditDidFinish(results: [PasswordAuditService.PasswordAudit]) {
        let passwordAuditResultsVC = PasswordAuditResultsVC.instantiateFromStoryboard()
        self.passwordAuditResultsVC = passwordAuditResultsVC
        passwordAuditResultsVC.items = results
        passwordAuditResultsVC.delegate = self
        router.push(passwordAuditResultsVC, animated: true, onPop: nil)
    }
}


extension PasswordAuditCoordinator: PasswordAuditResultsVCDelegate {
    func userDidRequestDeleteEntries(entries: [Entry]) {
        entries.forEach {
            databaseFile.database.delete(entry: $0)
        }
        saveDatabase(databaseFile)
    }

    func userDidRequestExcludeEntries(entries: [Entry]) {
        entries.forEach { entry in
            assert(entry is Entry2, "Tried to exclude unsupported entry type, check UI-level filters")
            (entry as? Entry2)?.qualityCheck = false
        }
        saveDatabase(databaseFile)
    }

    func didPressEditEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        onDismiss: @escaping () -> Void
    ) {
        delegate?.didPressEditEntry(entry, at: popoverAnchor, onDismiss: onDismiss)
    }

    func requestFormatUpgradeIfNecessary(didApprove: @escaping () -> Void) {
        guard let db2 = databaseFile.database as? Database2 else {
            assertionFailure("Requested format upgrade for KDB format, this should be blocked in UI.")
            return
        }
        guard let newFormat = db2.formatUpgradeRequired(for: .qualityCheckFlag) else {
            didApprove()
            return
        }
        
        guard db2.formatVersion.hasMajorDifferences(with: newFormat) else {
            Diag.debug("Minor format version upgrade required, approving silently")
            db2.upgradeFormatVersion(to: newFormat)
            didApprove()
            return
        }
        
        let message = [
                String.localizedStringWithFormat(
                    LString.databaseFormatVersionUpgradeMessageTemplate,
                    db2.formatVersion.description,
                    newFormat.description),
                LString.titleDatabaseFormatConversionAllDataPreserved
            ].joined(separator: "\n\n")
        let confirmationAlert = UIAlertController.make(
            title: LString.titleDatabaseFormatVersionUpgrade,
            message: message,
            dismissButtonTitle: LString.actionCancel
        )
        confirmationAlert.addAction(title: LString.actionContinue, style: .default, preferred: true){ _ in
            Diag.debug("DB format upgrade approved by user")
            db2.upgradeFormatVersion(to: newFormat)
            didApprove()
        }
        passwordAuditResultsVC?.present(confirmationAlert, animated: true)
    }
}


extension PasswordAuditCoordinator: DatabaseSaving {
    func didRelocate(databaseFile: DatabaseFile, to newURL: URL) {
        delegate?.didRelocateDatabase(databaseFile, to: newURL)
    }
    
    func getDatabaseSavingErrorParent() -> UIViewController {
        return passwordAuditResultsVC!
    }
}


extension PasswordAuditCoordinator: PasswordAuditServiceDelegate {
    func progressDidUpdate(progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }
}
