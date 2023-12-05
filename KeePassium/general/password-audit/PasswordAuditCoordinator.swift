//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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
    var saveSuccessHandler: (() -> Void)?

    weak var delegate: PasswordAuditCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseFile: DatabaseFile
    private let passwordAuditIntroVC: PasswordAuditVC
    private let passwordAuditService: PasswordAuditService
    private var passwordAuditResultsVC: PasswordAuditResultsVC?


    init(databaseFile: DatabaseFile, router: NavigationRouter) {
        self.databaseFile = databaseFile
        self.router = router
        self.passwordAuditIntroVC = PasswordAuditVC.instantiateFromStoryboard()

        var allEntries = [Entry]()
        databaseFile.database.root?.collectAllEntries(to: &allEntries)
        self.passwordAuditService = PasswordAuditService(
            hibpService: HIBPService(),
            entries: allEntries)
        self.passwordAuditService.delegate = self

        passwordAuditIntroVC.delegate = self
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.push(passwordAuditIntroVC, animated: true, onPop: { [weak self] in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
        startObservingPremiumStatus(#selector(premiumStatusDidChange))
    }

    @objc private func premiumStatusDidChange() {
        passwordAuditIntroVC.refresh()
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
    func didPressDismiss(in viewController: PasswordAuditVC) {
        router.dismiss(animated: true)
    }

    func didPressStartAudit(in viewController: PasswordAuditVC) {
        performPremiumActionOrOfferUpgrade(for: .canAuditPasswords, in: viewController) {
            [weak self, weak viewController] in
            viewController?.ensuringNetworkAccessPermitted { [weak self] in
                self?.performAudit()
            }
        }
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
    func didPressDismiss(in viewController: PasswordAuditResultsVC) {
        router.dismiss(animated: true)
    }

    func didPressDeleteEntries(entries: [Entry], in viewController: PasswordAuditResultsVC) {
        entries.forEach {
            databaseFile.database.delete(entry: $0)
        }
        saveDatabase(databaseFile)
    }

    func didPressExcludeEntries(entries: [Entry], in viewController: PasswordAuditResultsVC) {
        entries.forEach { entry in
            assert(entry is Entry2, "Tried to exclude unsupported entry type, check UI-level filters")
            (entry as? Entry2)?.qualityCheck = false
        }
        saveDatabase(databaseFile)
    }

    func didPressEditEntry(
        _ entry: Entry,
        at popoverAnchor: PopoverAnchor,
        in viewController: PasswordAuditResultsVC,
        onDismiss: @escaping () -> Void
    ) {
        delegate?.didPressEditEntry(entry, at: popoverAnchor, onDismiss: onDismiss)
    }

    func requestFormatUpgradeIfNecessary(
        in viewController: PasswordAuditResultsVC,
        didApprove: @escaping () -> Void
    ) {
        requestFormatUpgradeIfNecessary(
            in: viewController,
            for: databaseFile.database,
            and: .qualityCheckFlag,
            didApprove: didApprove
        )
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
