//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices
import KeePassiumLib

protocol EntryFinderCoordinatorDelegate: AnyObject {
    func didLeaveDatabase(in coordinator: EntryFinderCoordinator)
    func didSelectEntry(_ entry: Entry, in coordinator: EntryFinderCoordinator)

    func didPressReinstateDatabase(_ fileRef: URLReference, in coordinator: EntryFinderCoordinator)
}

final class EntryFinderCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: EntryFinderCoordinatorDelegate?

    private let router: NavigationRouter
    private let entryFinderVC: EntryFinderVC

    private let originalRef: URLReference
    private let databaseFile: DatabaseFile
    private let database: Database
    private let loadingWarnings: DatabaseLoadingWarnings?
    private var announcements = [AnnouncementItem]()

    private var shouldAutoSelectFirstMatch: Bool = false
    private var serviceIdentifiers: [ASCredentialServiceIdentifier]
    private let searchHelper = SearchHelper()

    private let vcAnimationDuration = 0.3

    init(
        router: NavigationRouter,
        originalRef: URLReference,
        databaseFile: DatabaseFile,
        loadingWarnings: DatabaseLoadingWarnings?,
        serviceIdentifiers: [ASCredentialServiceIdentifier]
    ) {
        self.router = router
        self.originalRef = originalRef
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.loadingWarnings = loadingWarnings
        self.serviceIdentifiers = serviceIdentifiers

        entryFinderVC = EntryFinderVC.instantiateFromStoryboard()
        entryFinderVC.delegate = self

        entryFinderVC.navigationItem.title = databaseFile.visibleFileName
    }

    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start() {
        router.prepareCustomTransition(
            duration: vcAnimationDuration,
            type: .fade,
            timingFunction: .easeOut
        )
        router.push(
            entryFinderVC,
            animated: false, 
            replaceTopViewController: true,
            onPop: { [weak self] in
                guard let self = self else { return }
                self.dismissHandler?(self)
                self.delegate?.didLeaveDatabase(in: self)
            }
        )

        updateAnnouncements()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2 * vcAnimationDuration) { [weak self] in
            self?.showInitialMessages()
        }
    }

    func stop(animated: Bool, completion: (() -> Void)?) {
        router.pop(viewController: entryFinderVC, animated: animated, completion: completion)
    }
}

extension EntryFinderCoordinator {
    public func lockDatabase() {
        DatabaseSettingsManager.shared.updateSettings(for: originalRef) {
            $0.clearMasterKey()
        }
        router.pop(viewController: entryFinderVC, animated: true)
        Diag.info("Database locked")
    }

    private func updateCallerID() {
        if serviceIdentifiers.isEmpty {
            entryFinderVC.callerID = nil
            return
        }

        let callerID = serviceIdentifiers
            .map { $0.identifier }
            .joined(separator: " | ")
        entryFinderVC.callerID = callerID
    }

    private func showInitialMessages() {
        if let loadingWarnings = loadingWarnings, !loadingWarnings.isEmpty {
            showLoadingWarnings(loadingWarnings)
            return
        }
    }

    private func showLoadingWarnings(_ warnings: DatabaseLoadingWarnings) {
        guard !warnings.isEmpty else { return }

        DatabaseLoadingWarningsVC.present(warnings, in: entryFinderVC, onLockDatabase: lockDatabase)
        StoreReviewSuggester.registerEvent(.trouble)
    }

    private func openQuickAutoFillPromo() {
        QuickAutoFillPrompt.dismissDate = Date.now
        URLOpener(entryFinderVC).open(url: URL.AppHelp.quickAutoFillIntro, completionHandler: nil)
    }

    private func setupAutomaticSearchResults() {
        let results = searchHelper.find(database: database, serviceIdentifiers: serviceIdentifiers)
        if results.isEmpty {
            entryFinderVC.activateManualSearch()
            return
        }

        if let perfectMatch = results.perfectMatch,
           Settings.current.autoFillPerfectMatch
        {
            delegate?.didSelectEntry(perfectMatch, in: self)
        } else {
            entryFinderVC.setSearchResults(results)
        }
    }

    private func performManualSearch(searchText: String) {
        var searchResults = FuzzySearchResults(exactMatch: [], partialMatch: [])
        searchResults.exactMatch = searchHelper
            .find(database: database, searchText: searchText)
        searchResults.partialMatch = []
        entryFinderVC.setSearchResults(searchResults)
    }
}

extension EntryFinderCoordinator {
    private func updateAnnouncements() {
        announcements.removeAll()
        if databaseFile.status.contains(.localFallback) {
            announcements.append(makeFallbackDatabaseAnnouncement(for: entryFinderVC))
        }
        if let qafAnnouncment = maybeMakeQuickAutoFillAnnouncment(for: entryFinderVC) {
            announcements.append(qafAnnouncment)
        }
        entryFinderVC.refreshAnnouncements()
    }

    private func maybeMakeQuickAutoFillAnnouncment(
        for viewController: EntryFinderVC
    ) -> AnnouncementItem? {
        let isQuickTypeEnabled = DatabaseSettingsManager.shared.isQuickTypeEnabled(databaseFile)
        guard !isQuickTypeEnabled && QuickAutoFillPrompt.shouldShow else {
            return nil
        }

        let announcement = AnnouncementItem(
            title: LString.callToActionActivateQuickAutoFill,
            body: LString.premiumFeatureQuickAutoFillDescription,
            actionTitle: LString.actionLearnMore,
            image: .symbol(.infoCircle),
            onDidPressAction: { [weak self] _ in
                self?.openQuickAutoFillPromo()
            },
            onDidPressClose: { [weak self] _ in
                QuickAutoFillPrompt.dismissDate = Date.now
                self?.updateAnnouncements()
            }
        )
        QuickAutoFillPrompt.lastSeenDate = Date.now
        return announcement
    }

    private func makeFallbackDatabaseAnnouncement(
        for viewController: EntryFinderVC
    ) -> AnnouncementItem {
        let actionTitle: String?
        switch originalRef.error {
        case .authorizationRequired(_, let recoveryAction):
            actionTitle = recoveryAction
        default:
            actionTitle = nil
        }
        let announcement = AnnouncementItem(
            title: LString.databaseIsFallbackCopy,
            body: originalRef.error?.errorDescription,
            actionTitle: actionTitle,
            image: .symbol(.iCloudSlash),
            onDidPressAction: { [weak self, weak viewController] _ in
                guard let self = self else { return }
                self.delegate?.didPressReinstateDatabase(originalRef, in: self)
                viewController?.refreshAnnouncements()
            }
        )
        return announcement
    }
}

extension EntryFinderCoordinator: EntryFinderDelegate {
    func getAnnouncements(for viewController: EntryFinderVC) -> [AnnouncementItem] {
        return announcements
    }

    func didLoadViewController(_ viewController: EntryFinderVC) {
        updateCallerID()
        setupAutomaticSearchResults()
    }

    func didChangeSearchQuery(_ searchText: String, in viewController: EntryFinderVC) {
        performManualSearch(searchText: searchText)
    }

    func didSelectEntry(_ entry: Entry, in viewController: EntryFinderVC) {
        delegate?.didSelectEntry(entry, in: self)
    }

    func didPressLockDatabase(in viewController: EntryFinderVC) {
        lockDatabase()
    }
}

extension LString {
    public static let callToActionActivateQuickAutoFill = NSLocalizedString(
        "[QuickAutoFill/Activate/callToAction]",
        value: "Activate Quick AutoFill",
        comment: "Call to action, invites the user to enable the Quick AutoFill feature")
}
