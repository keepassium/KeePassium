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

    @available(iOS 18.0, *)
    func didSelectText(_ text: String, in coordinator: EntryFinderCoordinator)

    func didPressReinstateDatabase(_ fileRef: URLReference, in coordinator: EntryFinderCoordinator)

    func didPressCreatePasskey(
        with params: PasskeyRegistrationParams,
        target entry: Entry?,
        presenter: UIViewController,
        in coordinator: EntryFinderCoordinator)
}

final class EntryFinderCoordinator: Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?
    weak var delegate: EntryFinderCoordinatorDelegate?

    private let router: NavigationRouter
    private let entryFinderVC: EntryFinderVC

    private let originalRef: URLReference
    let databaseFile: DatabaseFile
    let database: Database
    private let loadingWarnings: DatabaseLoadingWarnings?
    private var announcements = [AnnouncementItem]()

    private var shouldAutoSelectFirstMatch: Bool = false
    private var serviceIdentifiers: [ASCredentialServiceIdentifier]
    private var passkeyRelyingParty: String?
    private let passkeyRegistrationParams: PasskeyRegistrationParams?
    private let searchHelper = SearchHelper()
    private var isSelectingPasskeyCreationTarget = false

    private let vcAnimationDuration = 0.3

    private let autoFillMode: AutoFillMode?

    init(
        router: NavigationRouter,
        originalRef: URLReference,
        databaseFile: DatabaseFile,
        loadingWarnings: DatabaseLoadingWarnings?,
        serviceIdentifiers: [ASCredentialServiceIdentifier],
        passkeyRelyingParty: String?,
        passkeyRegistrationParams: PasskeyRegistrationParams?,
        autoFillMode: AutoFillMode?
    ) {
        self.router = router
        self.originalRef = originalRef
        self.databaseFile = databaseFile
        self.database = databaseFile.database
        self.loadingWarnings = loadingWarnings
        self.serviceIdentifiers = serviceIdentifiers
        self.passkeyRelyingParty = passkeyRelyingParty
        self.passkeyRegistrationParams = passkeyRegistrationParams
        self.autoFillMode = autoFillMode

        entryFinderVC = EntryFinderVC.instantiateFromStoryboard()
        entryFinderVC.delegate = self
        entryFinderVC.autoFillMode = autoFillMode

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
        let serviceID = serviceIdentifiers.first?.identifier
        entryFinderVC.callerID = serviceID ?? passkeyRelyingParty
    }

    private func showInitialMessages() {
        if let loadingWarnings, !loadingWarnings.isEmpty {
            showLoadingWarnings(loadingWarnings)
            return
        }

        if let passkeyRegistrationParams {
            showPasskeyRegistration(passkeyRegistrationParams)
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
        let results = searchHelper.find(
            database: database,
            serviceIdentifiers: serviceIdentifiers,
            passkeyRelyingParty: passkeyRelyingParty)
        if results.isEmpty && autoFillMode != .passkeyRegistration {
            entryFinderVC.activateManualSearch(query: autoFillMode?.query)
            return
        }

        if let perfectMatch = results.perfectMatch,
           Settings.current.autoFillPerfectMatch,
           autoFillMode != .passkeyRegistration
        {
            delegate?.didSelectEntry(perfectMatch, in: self)
        } else {
            entryFinderVC.setSearchResults(results)
        }
    }

    private func performManualSearch(searchText: String) {
        var searchResults = FuzzySearchResults(exactMatch: [], partialMatch: [])
        searchResults.exactMatch = searchHelper
            .findEntries(database: database, searchText: searchText)
        searchResults.partialMatch = []
        entryFinderVC.setSearchResults(searchResults)
    }

    private func showPasskeyRegistration(_ params: PasskeyRegistrationParams) {
        guard !databaseFile.status.contains(.readOnly) else {
            Diag.warning("Database is read-only, cancelling")
            return
        }
        let creatorVC = PasskeyCreatorVC.make(with: params)
        creatorVC.modalPresentationStyle = .pageSheet
        creatorVC.delegate = self
        if let sheet = creatorVC.sheetPresentationController {
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.prefersGrabberVisible = true
            sheet.detents = creatorVC.detents()
        }
        router.present(creatorVC, animated: true, completion: nil)
    }
}

extension EntryFinderCoordinator {
    private func updateAnnouncements() {
        announcements.removeAll()
        if databaseFile.status.contains(.localFallback) {
            announcements.append(makeFallbackDatabaseAnnouncement(for: entryFinderVC))
        }
        if databaseFile.status.contains(.readOnly) {
            announcements.append(makeReadOnlyDatabaseAnnouncement(for: entryFinderVC))
        }

        if announcements.isEmpty,
           let qafAnnouncment = maybeMakeQuickAutoFillAnnouncment(for: entryFinderVC)
        {
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

    private func makeReadOnlyDatabaseAnnouncement(
        for viewController: EntryFinderVC
    ) -> AnnouncementItem {
        return AnnouncementItem(
            title: nil,
            body: LString.databaseIsReadOnly,
            actionTitle: nil,
            image: nil
        )
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
        if isSelectingPasskeyCreationTarget {
            guard let passkeyRegistrationParams else {
                assertionFailure()
                return
            }
            delegate?.didPressCreatePasskey(
                with: passkeyRegistrationParams,
                target: entry,
                presenter: viewController,
                in: self
            )
        } else {
            delegate?.didSelectEntry(entry, in: self)
        }
    }

    func didPressLockDatabase(in viewController: EntryFinderVC) {
        lockDatabase()
    }

    @available(iOS 18.0, *)
    func didSelectField(_ field: EntryField, from entry: Entry, in viewController: EntryFinderVC) {
        var value = field.resolvedValue
        if field.name == EntryField.otp {
            value = getUpdatedOTPValue(field, entry: entry)
        }
        delegate?.didSelectText(value, in: self)
    }
}

extension EntryFinderCoordinator: PasskeyCreatorDelegate {
    func didPressCreatePasskey(with params: PasskeyRegistrationParams, in viewController: PasskeyCreatorVC) {
        viewController.dismiss(animated: true) { [self] in
            delegate?.didPressCreatePasskey(with: params, target: nil, presenter: entryFinderVC, in: self)
        }
    }
    func didPressAddPasskeyToEntry(
        with params: PasskeyRegistrationParams,
        in viewController: PasskeyCreatorVC
    ) {
        viewController.dismiss(animated: true)
        isSelectingPasskeyCreationTarget = true
        entryFinderVC.setPasskeyTargetSelectionMode()
    }
}

@available(iOS 18.0, *)
extension EntryFinderCoordinator {
    private static let nonSelectableFieldNames = [
        EntryField.title,
        EntryField.otpConfig1,
        EntryField.otpConfig2Seed,
        EntryField.otpConfig2Settings,
        EntryField.timeOtpLength,
        EntryField.timeOtpPeriod,
        EntryField.timeOtpSecret,
        EntryField.timeOtpAlgorithm,
        EntryField.tags
    ]

    func getSelectableFields(for entry: Entry) -> [EntryField]? {
        guard autoFillMode == .text else {
            return nil
        }
        var allFields = entry.fields
        if let totpGenerator = TOTPGeneratorFactory.makeGenerator(for: entry) {
            let otpField = EntryField(name: LString.fieldOTP, value: totpGenerator.generate(), isProtected: false)
            allFields.append(otpField)
        }
        let category = ItemCategory.get(for: entry)
        let selectableFields = allFields
            .filter { !Self.nonSelectableFieldNames.contains($0.name) }
            .filter { $0.resolvedValue.isNotEmpty }
            .sorted(by: { category.compare($0.name, $1.name) })
        return selectableFields
    }

    private func getUpdatedOTPValue(_ field: EntryField, entry: Entry) -> String {
        assert(field.name == EntryField.otp)
        guard let totpGenerator = TOTPGeneratorFactory.makeGenerator(for: entry) else {
            Diag.warning("Failed to refresh OTP field value")
            assertionFailure("Should not really happen")
            return field.resolvedValue
        }
        return totpGenerator.generate()
    }
}

extension LString {
    public static let callToActionActivateQuickAutoFill = NSLocalizedString(
        "[QuickAutoFill/Activate/callToAction]",
        value: "Activate Quick AutoFill",
        comment: "Call to action, invites the user to enable the Quick AutoFill feature")
}
