//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib
import AuthenticationServices
import LocalAuthentication
import OSLog

class AutoFillCoordinator: NSObject, Coordinator {
    let log = Logger(subsystem: "com.keepassium.autofill", category: "AutoFillCoordinator")
    
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler? 
    
    unowned var rootController: CredentialProviderViewController
    let extensionContext: ASCredentialProviderExtensionContext
    var router: NavigationRouter
    
    private var hasUI = false
    private var isStarted = false

    private var databasePickerCoordinator: DatabasePickerCoordinator!
    private var entryFinderCoordinator: EntryFinderCoordinator?
    private var databaseUnlockerCoordinator: DatabaseUnlockerCoordinator?
    var serviceIdentifiers = [ASCredentialServiceIdentifier]()

    private var quickTypeDatabaseLoader: DatabaseLoader?
    private var quickTypeRequiredRecord: QuickTypeAutoFillRecord?

    fileprivate var watchdog: Watchdog
    fileprivate var passcodeInputController: PasscodeInputVC?
    fileprivate var isBiometricAuthShown = false
    fileprivate var isPasscodeInputShown = false
    
    
    init(
        rootController: CredentialProviderViewController,
        context: ASCredentialProviderExtensionContext
    ) {
        log.trace("Coordinator is initializing")
        self.rootController = rootController
        self.extensionContext = context
        
        let navigationController = RouterNavigationController()
        navigationController.view.backgroundColor = .clear
        router = NavigationRouter(navigationController)
        
        watchdog = Watchdog.shared 
        super.init()

        #if PREPAID_VERSION
        BusinessModel.type = .prepaid
        #else
        BusinessModel.type = .freemium
        #endif
        SettingsMigrator.processAppLaunch(with: Settings.current)
        Diag.info(AppInfo.description)

        watchdog.delegate = self
    }
    
    deinit {
        log.trace("Coordinator is deinitializing")
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    public func handleMemoryWarning() {
        log.warning("Received a memory warning, will cancel loading")
        Diag.error("Received a memory warning")
        databaseUnlockerCoordinator?.cancelLoading(reason: .lowMemoryWarning)
    }
    
    func prepare() {
        log.trace("Coordinator is preparing")
        let premiumManager = PremiumManager.shared
        premiumManager.reloadReceipt()
        premiumManager.usageMonitor.startInterval()
        watchdog.didBecomeActive()
    }
    
    func start() {
        guard !isStarted else {
            return
        }
        isStarted = true

        log.trace("Coordinator is starting the UI")
        if !isAppLockVisible {
            rootController.showChildViewController(router.navigationController)
            if isNeedsOnboarding() {
                DispatchQueue.main.async { [weak self] in
                    self?.presentOnboarding()
                }
            }
        }
        
        showDatabasePicker()
        hasUI = true
        StoreReviewSuggester.registerEvent(.sessionStart)
        if Settings.current.isAutoFillFinishedOK {
            databasePickerCoordinator.shouldSelectDefaultDatabase = true
        } else {
            showCrashReport()
        }
    }
    
    internal func cleanup() {
        PremiumManager.shared.usageMonitor.stopInterval()
        Watchdog.shared.willResignActive()
        router.popToRoot(animated: false)
        removeAllChildCoordinators()
    }
    
    private func dismissAndQuit() {
        log.trace("Coordinator will clean up and quit")
        cancelRequest(.userCanceled)
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }
    
    internal func cancelRequest(_ code: ASExtensionError.Code) {
        log.info("Cancelling the request with code \(code)")
        extensionContext.cancelRequest(
            withError: NSError(
                domain: ASExtensionErrorDomain,
                code: code.rawValue
            )
        )
    }
    
    private func returnCredentials(entry: Entry) {
        log.info("Will return credentials")
        watchdog.restart()
        
        let settings = Settings.current
        if settings.isCopyTOTPOnAutoFill,
            let totpGenerator = TOTPGeneratorFactory.makeGenerator(for: entry)
        {
            let totpString = totpGenerator.generate()
            Clipboard.general.insert(
                text: totpString,
                timeout: TimeInterval(settings.clipboardTimeout.seconds)
            )
        }
        
        let passwordCredential = ASPasswordCredential(
            user: entry.resolvedUserName,
            password: entry.resolvedPassword)
        extensionContext.completeRequest(
            withSelectedCredential: passwordCredential,
            completionHandler: nil
        )
        if hasUI {
            HapticFeedback.play(.credentialsPasted)
        }
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }
}

extension AutoFillCoordinator {
    private func isNeedsOnboarding() -> Bool {
        if FileKeeper.canAccessAppSandbox {
            return false
        }
        
        let validDatabases = FileKeeper.shared
            .getAllReferences(fileType: .database, includeBackup: false)
            .filter { !$0.hasError }
        return validDatabases.isEmpty
    }
    
    private func showDatabasePicker() {
        databasePickerCoordinator = DatabasePickerCoordinator(router: router, mode: .autoFill)
        databasePickerCoordinator.delegate = self
        databasePickerCoordinator.dismissHandler = {[weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.databasePickerCoordinator = nil
            self?.dismissAndQuit()
        }
        databasePickerCoordinator.start()
        addChildCoordinator(databasePickerCoordinator)
    }
    
    private func presentOnboarding() {
        let firstSetupVC = FirstSetupVC.make(delegate: self)
        firstSetupVC.navigationItem.hidesBackButton = true
        router.present(firstSetupVC, animated: false, completion: nil)
    }
    
    private func showCrashReport() {
        StoreReviewSuggester.registerEvent(.trouble)
        
        let crashReportVC = CrashReportVC.instantiateFromStoryboard()
        crashReportVC.delegate = self
        router.push(crashReportVC, animated: false, onPop: nil)
    }
    
    private func showDatabaseUnlocker(_ databaseRef: URLReference) {
        let databaseUnlockerCoordinator = DatabaseUnlockerCoordinator(
            router: router,
            databaseRef: databaseRef
        )
        databaseUnlockerCoordinator.dismissHandler = {[weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.databaseUnlockerCoordinator = nil
        }
        databaseUnlockerCoordinator.delegate = self
        databaseUnlockerCoordinator.setDatabase(databaseRef)

        databaseUnlockerCoordinator.start()
        addChildCoordinator(databaseUnlockerCoordinator)
        self.databaseUnlockerCoordinator = databaseUnlockerCoordinator
    }
    
    private func showDatabaseViewer(
        _ fileRef: URLReference,
        databaseFile: DatabaseFile,
        warnings: DatabaseLoadingWarnings
    ) {
        let entryFinderCoordinator = EntryFinderCoordinator(
            router: router,
            databaseFile: databaseFile,
            loadingWarnings: warnings,
            serviceIdentifiers: serviceIdentifiers
        )
        entryFinderCoordinator.dismissHandler = {[weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.entryFinderCoordinator = nil
        }
        entryFinderCoordinator.delegate = self
        
        entryFinderCoordinator.start()
        addChildCoordinator(entryFinderCoordinator)
        self.entryFinderCoordinator = entryFinderCoordinator
    }
}

extension AutoFillCoordinator: DatabaseLoaderDelegate {
    func prepareUI(for credentialIdentity: ASPasswordCredentialIdentity) {
        log.trace("Preparing UI to return credentials")
        Diag.debug("Preparing UI to return credentials")
        self.serviceIdentifiers = [credentialIdentity.serviceIdentifier]
        if let recordIdentifier = credentialIdentity.recordIdentifier,
           let record = QuickTypeAutoFillRecord.parse(recordIdentifier)
        {
            quickTypeRequiredRecord = record
        }
        if !ProcessInfo.isRunningOnMac {
            assert(!hasUI)
            start()
        }
    }
    
    func provideWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        log.trace("Will provide without user interaction")
        assert(!hasUI, "This should run in pre-UI mode only")
        Diag.info("Identity: \(credentialIdentity.debugDescription)")
        
        guard let recordIdentifier = credentialIdentity.recordIdentifier,
              let record = QuickTypeAutoFillRecord.parse(recordIdentifier)
        else {
            log.debug("Failed to parse credential store record, aborting")
            Diag.error("Failed to parse credential store record, aborting")
            cancelRequest(.failed)
            return
        }
        quickTypeRequiredRecord = record

        guard let dbRef = findDatabase(for: record) else {
            log.debug("Failed to find the record, aborting")
            Diag.warning("Failed to find record's database, aborting")
            QuickTypeAutoFillStorage.removeAll()
            cancelRequest(.userInteractionRequired)
            return
        }
        
        let databaseSettingsManager = DatabaseSettingsManager.shared
        guard let dbSettings = databaseSettingsManager.getSettings(for: dbRef),
              let masterKey = dbSettings.masterKey
        else {
            log.debug("Failed to auto-open the DB, will require user interaction")
            cancelRequest(.userInteractionRequired)
            return
        }
        log.debug("Got stored master key for \(dbRef.visibleFileName, privacy: .private)")
        
        let timeout = databaseSettingsManager.getFallbackTimeout(dbRef)
        
        assert(self.quickTypeDatabaseLoader == nil)
        quickTypeDatabaseLoader = DatabaseLoader(
            dbRef: dbRef,
            compositeKey: masterKey,
            status: [.readOnly],
            timeout: timeout,
            delegate: self
        )
        log.trace("Will load database")
        quickTypeDatabaseLoader!.load()
    }
    
    private func findDatabase(for record: QuickTypeAutoFillRecord) -> URLReference? {
        let dbRefs = FileKeeper.shared.getAllReferences(fileType: .database, includeBackup: false)
        let matchingDatabase = dbRefs.first {
            $0.fileProvider == record.fileProvider && $0.getDescriptor() == record.fileDescriptor
        }
        return matchingDatabase
    }
    
    private func findEntry(
        matching record: QuickTypeAutoFillRecord,
        in databaseFile: DatabaseFile
    ) -> Entry? {
        guard let entry = databaseFile.database.root?.findEntry(byUUID: record.itemID),
              !entry.isDeleted,
              !entry.isHiddenFromSearch,
              !entry.isExpired
        else {
            return nil
        }
        return entry
    }
    
    private func returnQuickTypeEntry(
        matching record: QuickTypeAutoFillRecord,
        in databaseFile: DatabaseFile
    ) {
        assert(!hasUI, "This should run only in pre-UI mode")
        if let foundEntry = findEntry(matching: record, in: databaseFile) {
            returnCredentials(entry: foundEntry)
        } else {
            cancelRequest(.credentialIdentityNotFound)
        }
    }
    
    func databaseLoader(_ databaseLoader: DatabaseLoader, willLoadDatabase dbRef: URLReference) {
        assert(!hasUI, "This should run only in pre-UI mode")
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didChangeProgress progress: ProgressEx,
        for dbRef: URLReference
    ) {
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didFailLoading dbRef: URLReference,
        with error: DatabaseLoader.Error
    ) {
        assert(!hasUI, "This should run only in pre-UI mode")
        quickTypeDatabaseLoader = nil
        switch error {
        case .cancelledByUser:
            log.fault("DB loading was cancelled without UI. This should not be possible.")
            cancelRequest(.failed)
        case .invalidKey(_):
            log.error("DB loading failed: invalid key. Will require user interaction.")
            Diag.info("Stored master key does not fit, starting the UI")
            cancelRequest(.userInteractionRequired)
        default:
            log.error("DB loading failed: \(error.localizedDescription). Will require user interaction.")
            Diag.info("Failed to load the database, starting the UI")
            cancelRequest(.userInteractionRequired)
        }
    }
    
    func databaseLoader(
        _ databaseLoader: DatabaseLoader,
        didLoadDatabase dbRef: URLReference,
        databaseFile: DatabaseFile,
        withWarnings warnings: DatabaseLoadingWarnings
    ) {
        assert(!hasUI, "This should run only in pre-UI mode")
        quickTypeDatabaseLoader = nil
        guard let record = quickTypeRequiredRecord else {
            log.fault("quickTypeRequiredRecord is unexpectedly nil")
            assertionFailure("quickTypeRequiredRecord is unexpectedly nil")
            cancelRequest(.userInteractionRequired)
            return
        }
        returnQuickTypeEntry(matching: record, in: databaseFile)
    }
}

extension AutoFillCoordinator: WatchdogDelegate {
    var isAppCoverVisible: Bool {
        return false
    }
    
    func showAppCover(_ sender: Watchdog) {
    }
    
    func hideAppCover(_ sender: Watchdog) {
    }
    
    var isAppLockVisible: Bool {
        return isBiometricAuthShown || isPasscodeInputShown
    }

    func showAppLock(_ sender: Watchdog) {
        guard !isAppLockVisible else { return }
        let shouldUseBiometrics = canUseBiometrics()

        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .verification
        passcodeInputVC.isCancelAllowed = true
        passcodeInputVC.isBiometricsAllowed = shouldUseBiometrics
        passcodeInputVC.modalTransitionStyle = .crossDissolve

        passcodeInputVC.shouldActivateKeyboard = !shouldUseBiometrics

        rootController.swapChildViewControllers(
            from: router.navigationController,
            to: passcodeInputVC,
            options: .transitionCrossDissolve)
        router.dismissModals(animated: false, completion: nil)
        passcodeInputVC.shouldActivateKeyboard = false
        maybeShowBiometricAuth()
        passcodeInputVC.shouldActivateKeyboard = !isBiometricAuthShown
        self.passcodeInputController = passcodeInputVC
        isPasscodeInputShown = true
    }

    func hideAppLock(_ sender: Watchdog) {
        dismissPasscodeAndContinue()
    }

    func mustCloseDatabase(_ sender: Watchdog, animate: Bool) {
        if Settings.current.premiumIsLockDatabasesOnTimeout {
            entryFinderCoordinator?.lockDatabase()
        }else {
            entryFinderCoordinator?.stop(animated: animate)
        }
    }

    private func dismissPasscodeAndContinue() {
        if let passcodeInputVC = passcodeInputController {
            rootController.swapChildViewControllers(
                from: passcodeInputVC,
                to: router.navigationController,
                options: .transitionCrossDissolve,
                completion: { [weak self] finished in
                    guard let self = self else { return }
                    if self.isNeedsOnboarding() {
                        self.presentOnboarding()
                    }
                }
            )
            passcodeInputController = nil
        } else {
            assertionFailure()
        }
        
        isPasscodeInputShown = false
        watchdog.restart()
    }

    private func canUseBiometrics() -> Bool {
        return hasUI 
            && Settings.current.isBiometricAppLockEnabled
            && LAContext.isBiometricsAvailable()
            && Keychain.shared.isBiometricAuthPrepared()
    }
    
    private func maybeShowBiometricAuth() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?._maybeShowBiometricAuth()
        }
    }
    
    private func _maybeShowBiometricAuth() {
        guard canUseBiometrics() else {
            isBiometricAuthShown = false
            return
        }
        
        Diag.debug("Biometric auth: showing request")
        Keychain.shared.performBiometricAuth { [weak self] success in
            guard let self = self else { return }
            BiometricsHelper.biometricPromptLastSeenTime = Date.now
            self.isBiometricAuthShown = false
            if success {
                Diag.info("Biometric auth successful")
                self.watchdog.unlockApp()
            } else {
                Diag.warning("Biometric auth failed")
                self.passcodeInputController?.showKeyboard()
            }
        }
        isBiometricAuthShown = true
    }
}

extension AutoFillCoordinator: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        dismissAndQuit()
    }
    
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        do {
            if try Keychain.shared.isAppPasscodeMatch(passcode) { 
                HapticFeedback.play(.appUnlocked)
                Keychain.shared.prepareBiometricAuth(true)
                watchdog.unlockApp()
            } else {
                HapticFeedback.play(.wrongPassword)
                sender.animateWrongPassccode()
                StoreReviewSuggester.registerEvent(.trouble)
                if Settings.current.isLockAllDatabasesOnFailedPasscode {
                    DatabaseSettingsManager.shared.eraseAllMasterKeys()
                    entryFinderCoordinator?.lockDatabase()
                }
            }
        } catch {
            Diag.error(error.localizedDescription)
            sender.showErrorAlert(error, title: LString.titleKeychainError)
        }
    }

    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {
        maybeShowBiometricAuth()
    }
}

extension AutoFillCoordinator: CrashReportDelegate {
    func didPressDismiss(in crashReport: CrashReportVC) {
        Settings.current.isAutoFillFinishedOK = true
        router.pop(animated: true)
    }
}

extension AutoFillCoordinator: FirstSetupDelegate {
    func didPressCancel(in firstSetup: FirstSetupVC) {
        dismissAndQuit()
    }
    
    func didPressAddDatabase(in firstSetup: FirstSetupVC, at popoverAnchor: PopoverAnchor) {
        watchdog.restart()
        firstSetup.dismiss(animated: true, completion: nil)
        databasePickerCoordinator.addExistingDatabase(presenter: router.navigationController)
    }
    
    func didPressSkip(in firstSetup: FirstSetupVC) {
        watchdog.restart()
        firstSetup.dismiss(animated: true, completion: nil)
    }
}

extension AutoFillCoordinator: DatabasePickerCoordinatorDelegate {
    func shouldAcceptDatabaseSelection(
        _ fileRef: URLReference,
        in coordinator: DatabasePickerCoordinator
    ) -> Bool {
        return true
    }
    
    func didSelectDatabase(_ fileRef: URLReference?, in coordinator: DatabasePickerCoordinator) {
        guard let fileRef = fileRef else {
            return
        }
        showDatabaseUnlocker(fileRef)
    }
    
    func shouldKeepSelection(in coordinator: DatabasePickerCoordinator) -> Bool {
        return false
    }
}

extension AutoFillCoordinator: DatabaseUnlockerCoordinatorDelegate {
    func shouldDismissFromKeyboard(_ coordinator: DatabaseUnlockerCoordinator) -> Bool {
        return true
    }
    
    func shouldAutoUnlockDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> Bool {
        return true
    }
    
    func willUnlockDatabase(_ fileRef: URLReference, in coordinator: DatabaseUnlockerCoordinator) {
        Settings.current.isAutoFillFinishedOK = false
    }
    
    func didNotUnlockDatabase(
        _ fileRef: URLReference,
        with message: String?,
        reason: String?,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        Settings.current.isAutoFillFinishedOK = true 
    }
    
    func shouldChooseFallbackStrategy(
        for fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> UnreachableFileFallbackStrategy {
        return DatabaseSettingsManager.shared.getFallbackStrategy(fileRef)
    }

    func didUnlockDatabase(
        databaseFile: DatabaseFile,
        at fileRef: URLReference,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        Settings.current.isAutoFillFinishedOK = true 
        if let targetRecord = quickTypeRequiredRecord,
           let desiredEntry = findEntry(matching: targetRecord, in: databaseFile)
        {
            returnCredentials(entry: desiredEntry)
        } else {
            showDatabaseViewer(fileRef, databaseFile: databaseFile, warnings: warnings)
        }
    }
    
    func didPressReinstateDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        router.pop(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            self.databasePickerCoordinator.addExistingDatabase(
                presenter: self.router.navigationController
            )
        })
    }
}

extension AutoFillCoordinator: EntryFinderCoordinatorDelegate {
    func didLeaveDatabase(in coordinator: EntryFinderCoordinator) {
    }
    
    func didSelectEntry(_ entry: Entry, in coordinator: EntryFinderCoordinator) {
        returnCredentials(entry: entry)
    }
}
