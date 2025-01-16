//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import AuthenticationServices
import KeePassiumLib
import LocalAuthentication
import OSLog
import UIKit
#if INTUNE
import IntuneMAMSwift
import MSAL
#endif

class AutoFillCoordinator: NSObject, Coordinator {
    let log = Logger(subsystem: "com.keepassium.autofill", category: "AutoFillCoordinator")

    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler? 

    unowned var rootController: CredentialProviderViewController
    let extensionContext: ASCredentialProviderExtensionContext
    var router: NavigationRouter

    var autoFillMode: AutoFillMode? {
        didSet {
            Diag.debug("Mode: \(autoFillMode?.debugDescription ?? "nil")")
        }
    }

    private var hasUI = false
    private var isServicesInitialized = false
    private var isStarted = false
    private var isInDeviceAutoFillSettings = false

    private var databasePickerCoordinator: DatabasePickerCoordinator!
    private var entryFinderCoordinator: EntryFinderCoordinator?
    private var databaseUnlockerCoordinator: DatabaseUnlockerCoordinator?

    private var serviceIdentifiers = [ASCredentialServiceIdentifier]()
    private var passkeyRelyingParty: String?
    private var passkeyClientDataHash: Data?
    private var passkeyRegistrationParams: PasskeyRegistrationParams?

    private var quickTypeDatabaseLoader: DatabaseLoader?
    private var quickTypeRequiredRecord: QuickTypeAutoFillRecord?

    fileprivate var watchdog: Watchdog
    fileprivate var passcodeInputController: PasscodeInputVC?
    fileprivate var isBiometricAuthShown = false
    fileprivate var isPasscodeInputShown = false

    var fileExportHelper: FileExportHelper?
    var saveSuccessHandler: (() -> Void)?
    var databaseSaver: DatabaseSaver?

    #if INTUNE
    private var enrollmentDelegate: IntuneEnrollmentDelegateImpl?
    private var policyDelegate: IntunePolicyDelegateImpl?
    #endif

    private var memoryFootprintBeforeDatabaseMiB: Float?
    private var databaseMemoryFootprintMiB: Float?
    private let memoryPressureSource = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical])

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

        #if INTUNE
        BusinessModel.isIntuneEdition = true
        OneDriveManager.shared.setAuthProvider(MSALOneDriveAuthProvider())
        #else
        BusinessModel.isIntuneEdition = false
        #endif

        Swizzler.swizzle()
        SettingsMigrator.processAppLaunch(with: Settings.current)
        Diag.info(AppInfo.description)

        memoryPressureSource.setEventHandler { [weak self] in self?.handleMemoryWarning() }
        memoryPressureSource.activate()

        watchdog.delegate = self
    }

    deinit {
        log.trace("Coordinator is deinitializing")
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
        memoryPressureSource.cancel()
    }

    private func handleMemoryWarning() {
        if memoryPressureSource.isCancelled {
            return
        }

        let mibFootprint = MemoryMonitor.getMemoryFootprintMiB()
        let event = memoryPressureSource.data
        switch event {
        case .warning:
            Diag.error(String(format: "Received a memory warning, using %.1f MiB", mibFootprint))
        case.critical:
            Diag.error(String(format: "Received a CRITICAL memory warning, using %.1f MiB", mibFootprint))
            log.warning("Received a CRITICAL memory warning, will cancel loading")
            databaseUnlockerCoordinator?.cancelLoading(reason: .lowMemoryWarning)
        default:
            log.error("Received a memory warning of unrecognized type")
        }
    }

    func initServices() {
        assert(!isStarted, "initServices() must be called before start()")
        if isServicesInitialized {
            assertionFailure("Repeated call to initServices")
            return
        }

        log.trace("Coordinator is preparing")
        let premiumManager = PremiumManager.shared
        premiumManager.reloadReceipt()
        premiumManager.usageMonitor.startInterval()
        watchdog.didBecomeActive()
        isServicesInitialized = true
    }

    func start() {
        if isStarted {
            return
        } else {
            if !isServicesInitialized {
                initServices()
            }
            isStarted = true
        }

        log.trace("Coordinator is starting the UI")
        if isInDeviceAutoFillSettings {
            rootController.showChildViewController(router.navigationController)
            DispatchQueue.main.async { [weak self] in
                self?.showUncheckKeychainMessage()
            }
            return
        }

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

        #if INTUNE
        setupIntune()
        guard let currentUser = IntuneMAMEnrollmentManager.instance().enrolledAccount(),
              !currentUser.isEmpty
        else {
            Diag.debug("Intune account missing, starting enrollment")
            DispatchQueue.main.async {
                self.startIntuneEnrollment()
            }
            return
        }
        Diag.info("Intune account is enrolled")
        #endif

        runAfterStartTasks()
    }

    private func runAfterStartTasks() {
        #if INTUNE
        applyIntuneAppConfig()

        guard ManagedAppConfig.shared.hasProvisionalLicense() else {
            showOrgLicensePaywall()
            return
        }
        #endif

        guard Settings.current.isAutoFillFinishedOK else {
            showCrashReport()
            return
        }

        let isDefaultDatabaseReachable: Bool
        if Settings.current.startupDatabase?.location == .internalDocuments {
            let areInternalDatabasesLikelyMissing = FileKeeper.canPossiblyAccessAppSandbox
                    && !FileKeeper.shared.canActuallyAccessAppSandbox
            isDefaultDatabaseReachable = !areInternalDatabasesLikelyMissing
        } else {
            isDefaultDatabaseReachable = true
        }
        databasePickerCoordinator.shouldSelectDefaultDatabase = isDefaultDatabaseReachable
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
}

extension AutoFillCoordinator {
    private func isNeedsOnboarding() -> Bool {
        if FileKeeper.canPossiblyAccessAppSandbox {
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

    private func showUncheckKeychainMessage() {
        let setupMessageVC = AutoFillSetupMessageVC.instantiateFromStoryboard()
        setupMessageVC.completionHanlder = { [weak self] in
            self?.extensionContext.completeExtensionConfigurationRequest()
        }
        router.push(setupMessageVC, animated: true, onPop: nil)
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

    private func reinstateDatabase(_ fileRef: URLReference) {
        let presenter = router.navigationController
        switch fileRef.location {
        case .external:
            databasePickerCoordinator.addExternalDatabase(fileRef, presenter: presenter)
        case .remote:
            databasePickerCoordinator.addRemoteDatabase(fileRef, presenter: presenter)
        case .internalInbox, .internalBackup, .internalDocuments:
            assertionFailure("Should not be here. Can reinstate only external or remote files.")
            return
        }
    }

    private func showDatabaseViewer(
        _ fileRef: URLReference,
        databaseFile: DatabaseFile,
        warnings: DatabaseLoadingWarnings
    ) {
        log.trace("Displaying database viewer")
        let entryFinderCoordinator = EntryFinderCoordinator(
            router: router,
            originalRef: fileRef,
            databaseFile: databaseFile,
            loadingWarnings: warnings,
            serviceIdentifiers: serviceIdentifiers,
            passkeyRelyingParty: passkeyRelyingParty,
            passkeyRegistrationParams: passkeyRegistrationParams,
            autoFillMode: autoFillMode
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

    func maybeWarnAboutExcessiveMemory(presenter: UIViewController, _ completion: @escaping () -> Void) {
        guard let databaseMemoryFootprintMiB,
              let kdfPeak = entryFinderCoordinator?.databaseFile.database.peakKDFMemoryFootprint
        else {
            assertionFailure()
            completion()
            return
        }

        let kdfPeakMiB = MemoryMonitor.bytesToMiB(kdfPeak)
        let memoryRequiredForSavingMiB = kdfPeakMiB
                + 2 * databaseMemoryFootprintMiB
                + MemoryMonitor.autoFillMemoryWarningThresholdMiB
        let memoryAvailableMiB = MemoryMonitor.estimateAutoFillMemoryRemainingMiB()
        Diag.debug(String(
            format: "%.1f MiB necessary, %.1f MiB available",
            memoryRequiredForSavingMiB,
            memoryAvailableMiB
        ))
        log.debug("\(memoryRequiredForSavingMiB, format: .fixed(precision: 1), privacy: .public) MiB necessary, \(memoryAvailableMiB, format: .fixed(precision: 1), privacy: .public) MiB available")

        if memoryAvailableMiB > memoryRequiredForSavingMiB {
            completion()
        } else {
            let alert = UIAlertController.make(
                title: LString.titleWarning,
                message: LString.messageAutoFillCannotModify,
                dismissButtonTitle: LString.actionCancel)
            alert.addAction(title: LString.actionContinue, style: .default, preferred: true) { _ in
                completion()
            }
            presenter.present(alert, animated: true, completion: nil)
        }
    }

    private func startPasskeyRegistration(
        with params: PasskeyRegistrationParams,
        target entry: Entry?,
        in databaseFile: DatabaseFile,
        presenter: UIViewController
    ) {
        let presenter = router.navigationController
        guard let db2 = databaseFile.database as? Database2,
              let rootGroup = db2.root as? Group2
        else {
            Diag.error("Tried to register passkey in non-KDBX database, cancelling")
            presenter.showErrorAlert(LString.titleDatabaseFormatDoesNotSupportPasskeys)
            return
        }

        let passkey: NewPasskey
        do {
            passkey = try NewPasskey.make(with: params)
        } catch {
            log.error("Failed to create passkey. Reason: \(error.localizedDescription, privacy: .public)")
            presenter.showErrorAlert(error.localizedDescription)
            return
        }

        guard let targetEntry = entry as? Entry2 else {
            Diag.debug("Creating a new passkey entry")
            _ = rootGroup.createPasskeyEntry(with: passkey)
            finishPasskeyRegistration(passkey, in: databaseFile, presenter: presenter)
            return
        }
        guard let _ = Passkey.make(from: targetEntry) else {
            Diag.debug("Adding passkey to existing entry")
            db2.setPasskey(passkey, for: targetEntry)
            finishPasskeyRegistration(passkey, in: databaseFile, presenter: presenter)
            return
        }

        let overwriteConfirmationAlert = UIAlertController.make(
            title: LString.fieldPasskey,
            message: LString.titleConfirmReplacingExistingPasskey,
            dismissButtonTitle: LString.actionCancel)
        overwriteConfirmationAlert.addAction(
            title: LString.actionReplace,
            style: .destructive,
            preferred: false,
            handler: { [weak self, weak databaseFile, weak presenter] _ in
                guard let self, let databaseFile, let presenter else { return }
                Diag.debug("Replacing passkey in existing entry")
                db2.setPasskey(passkey, for: targetEntry)
                finishPasskeyRegistration(passkey, in: databaseFile, presenter: presenter)
            }
        )
        presenter.present(overwriteConfirmationAlert, animated: true)
    }

    private func finishPasskeyRegistration(
        _ passkey: NewPasskey,
        in databaseFile: DatabaseFile,
        presenter: UIViewController
    ) {
        maybeWarnAboutExcessiveMemory(presenter: presenter) { [weak self] in
            guard let self else { return }

            Settings.current.isAutoFillFinishedOK = false
            saveDatabase(databaseFile, onSuccess: { [weak self, passkey] in
                self?.returnPasskeyRegistration(passkey: passkey)
            })
        }
    }
}

extension AutoFillCoordinator: DatabaseLoaderDelegate {
    public func startConfigurationUI() {
        log.trace("Starting configuration UI")
        isInDeviceAutoFillSettings = true
        start()
    }

    public func startUI(forServices serviceIdentifiers: [ASCredentialServiceIdentifier], mode: AutoFillMode) {
        self.serviceIdentifiers = serviceIdentifiers
        self.autoFillMode = mode
        self.passkeyRelyingParty = nil
        self.passkeyClientDataHash = nil
        start()
    }

    public func startPasskeyRegistrationUI(_ request: ASPasskeyCredentialRequest) {
        log.trace("Starting passkey registration UI")
        self.autoFillMode = .passkeyRegistration
        let identity = request.credentialIdentity as! ASPasskeyCredentialIdentity
        self.passkeyRelyingParty = identity.relyingPartyIdentifier
        self.passkeyClientDataHash = request.clientDataHash
        self.passkeyRegistrationParams = PasskeyRegistrationParams(
            identity: identity,
            userVerificationPreference: request.userVerificationPreference,
            clientDataHash: request.clientDataHash,
            supportedAlgorithms: request.supportedAlgorithms)
        start()
    }

    public func startPasskeyAssertionUI(
        allowPasswords: Bool,
        clientDataHash: Data,
        relyingParty: String,
        forServices serviceIdentifiers: [ASCredentialServiceIdentifier]
    ) {
        log.trace("Starting passkey assertion UI")
        self.serviceIdentifiers = serviceIdentifiers
        self.autoFillMode = .passkeyAssertion(allowPasswords)
        self.passkeyClientDataHash = clientDataHash
        self.passkeyRelyingParty = relyingParty
        start()
    }

    public func startUI(forIdentity credentialIdentity: ASCredentialIdentity, mode: AutoFillMode) {
        log.trace("Starting UI to return \(mode.debugDescription, privacy: .public)")
        self.serviceIdentifiers = [credentialIdentity.serviceIdentifier]
        if let recordIdentifier = credentialIdentity.recordIdentifier,
           let record = QuickTypeAutoFillRecord.parse(recordIdentifier)
        {
            quickTypeRequiredRecord = record
        }
        self.passkeyRelyingParty = (credentialIdentity as? ASPasskeyCredentialIdentity)?.relyingPartyIdentifier
        self.autoFillMode = mode
        start()
    }

    public func providePasskeyWithoutUI(
        forIdentity credentialIdentity: ASPasskeyCredentialIdentity,
        clientDataHash: Data
    ) {
        self.passkeyClientDataHash = clientDataHash
        self.passkeyRelyingParty = credentialIdentity.relyingPartyIdentifier
        provideWithoutUI(forIdentity: credentialIdentity, mode: .passkeyAssertion(false))
    }

    func provideWithoutUI(forIdentity credentialIdentity: ASCredentialIdentity, mode: AutoFillMode) {
        initServices()
        log.trace("Will provide \(mode.debugDescription, privacy: .public) without UI")
        assert(!hasUI, "This should run in pre-UI mode only")
        Diag.debug("Identity: \(credentialIdentity.description)")

        guard let recordIdentifier = credentialIdentity.recordIdentifier,
              let record = QuickTypeAutoFillRecord.parse(recordIdentifier)
        else {
            log.warning("Failed to parse credential store record, switching to UI")
            cancelRequest(.userInteractionRequired)
            return
        }
        quickTypeRequiredRecord = record
        self.autoFillMode = mode

        var dbStatus = DatabaseFile.Status([.readOnly, .useStreams])
        guard let dbRef = findDatabase(for: record) else {
            log.warning("Failed to find the record, switching to UI")
            QuickTypeAutoFillStorage.removeAll()
            cancelRequest(.userInteractionRequired)
            return
        }

        var fallbackDBRef: URLReference?
        if !(dbRef.location.isInternal || dbRef.fileProvider == .localStorage) {
            fallbackDBRef = DatabaseManager.getFallbackFile(for: dbRef)
        }
        if fallbackDBRef != nil {
            log.info("Found fallback file, using it")
            dbStatus.insert(.localFallback)
        }

        let databaseSettingsManager = DatabaseSettingsManager.shared
        guard let dbSettings = databaseSettingsManager.getSettings(for: dbRef),
              let masterKey = dbSettings.masterKey
        else {
            log.warning("Failed to auto-open the DB, switching to UI")
            cancelRequest(.userInteractionRequired)
            return
        }
        log.debug("Got stored master key for \(dbRef.visibleFileName, privacy: .private)")

        let timeoutDuration = databaseSettingsManager.getFallbackTimeout(dbRef, forAutoFill: true)

        assert(self.quickTypeDatabaseLoader == nil)
        quickTypeDatabaseLoader = DatabaseLoader(
            dbRef: fallbackDBRef ?? dbRef,
            compositeKey: masterKey,
            status: dbStatus,
            timeout: Timeout(duration: timeoutDuration),
            delegate: self
        )
        log.trace("Will load database")
        quickTypeDatabaseLoader!.load()
    }
}

extension AutoFillCoordinator {
    internal func cancelRequest(_ code: ASExtensionError.Code) {
        log.info("Cancelling the request with code \(code)")
        extensionContext.cancelRequest(
            withError: NSError(
                domain: ASExtensionErrorDomain,
                code: code.rawValue
            )
        )
        cleanup()
    }

    private func getOTPForClipboard(for entry: Entry) -> String? {
        guard Settings.current.isCopyTOTPOnAutoFill,
              let generator = TOTPGeneratorFactory.makeGenerator(for: entry)
        else {
            return nil
        }
        return generator.generate()
    }

    private func returnEntry(_ entry: Entry) {
        switch autoFillMode {
        case .credentials:
            returnCredentials(from: entry)
        case .oneTimeCode:
            if #available(iOS 18, *) {
                returnOneTimeCode(from: entry)
            } else {
                log.error("Tried to return .oneTimeCode before iOS 18, cancelling")
                assertionFailure()
                cancelRequest(.failed)
            }
        case .passkeyAssertion(let allowPasswords):
            let passkeyReturned = maybeReturnPasskeyAssertion(from: entry)
            guard passkeyReturned || allowPasswords else {
                cancelRequest(.credentialIdentityNotFound)
                return
            }
            returnCredentials(from: entry)
        default:
            let mode = autoFillMode?.debugDescription ?? "nil"
            log.error("Unexpected AutoFillMode value `\(mode, privacy: .public)`, cancelling")
            assertionFailure()
            cancelRequest(.failed)
        }
    }

    private func returnCredentials(from entry: Entry) {
        log.trace("Will return credentials")
        watchdog.restart()

        if let otpValue = getOTPForClipboard(for: entry) {
            guard hasUI else {
                log.info("Quick entry has OTP, switching to UI to copy it to clipboard")
                cancelRequest(.userInteractionRequired)
                return
            }
            Clipboard.general.copyWithTimeout(otpValue)
        }

        let passwordCredential = ASPasswordCredential(
            user: entry.resolvedUserName,
            password: entry.resolvedPassword)
        extensionContext.completeRequest(
            withSelectedCredential: passwordCredential,
            completionHandler: { [self] expired in
                log.info("Did return credentials (exp: \(expired))")
            }
        )
        if hasUI {
            HapticFeedback.play(.credentialsPasted)
        }
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }

    @available(iOS 18.0, *)
    private func returnOneTimeCode(from entry: Entry) {
        log.trace("Will return one time code")
        watchdog.restart()

        guard let totpGenerator = TOTPGeneratorFactory.makeGenerator(for: entry) else {
            log.error("Tried to return one time code from entry with no TOTP, cancelling")
            cancelRequest(.credentialIdentityNotFound)
            return
        }

        let otp = ASOneTimeCodeCredential(code: totpGenerator.generate())
        extensionContext.completeOneTimeCodeRequest(using: otp)

        if hasUI {
            HapticFeedback.play(.credentialsPasted)
        }
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }

    @available(iOS 18, *)
    private func returnText(_ text: String) {
        log.trace("Will return text")
        watchdog.restart()
        #if targetEnvironment(macCatalyst)
            // swiftlint:disable:next line_length
            let alert = UIAlertController.make(title: nil, message: "This feature is broken in macOS Sequoia.\n\nInstead, use the 'key' button in the password field.")
            router.present(alert, animated: true, completion: nil)
        #else
            extensionContext.completeRequest(withTextToInsert: text)
            if hasUI {
                HapticFeedback.play(.credentialsPasted)
            }
        #endif
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }

    private func returnPasskeyRegistration(passkey: NewPasskey) {
        log.trace("Will return registered passkey")
        watchdog.restart()
        guard let passkeyClientDataHash else {
            log.error("Passkey request parameters unexpectedly missing, cancelling")
            assertionFailure()
            cancelRequest(.failed)
            return
        }

        let passkeyCredential = passkey.makeRegistrationCredential(clientDataHash: passkeyClientDataHash)
        extensionContext.completeRegistrationRequest(
            using: passkeyCredential,
            completionHandler: { [self] expired in
                log.info("Did return passkey (exp: \(expired))")
            }
        )

        if hasUI {
            HapticFeedback.play(.credentialsPasted)
        }
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }

    private func maybeReturnPasskeyAssertion(from entry: Entry) -> Bool {
        guard let passkeyClientDataHash else {
            log.error("Passkey request parameters missing")
            return false
        }
        guard let passkey = Passkey.make(from: entry) else {
            log.error("Selected entry does not have passkeys")
            return false
        }
        returnPasskeyAssertion(passkey: passkey, clientDataHash: passkeyClientDataHash)
        return true
    }

    private func returnPasskeyAssertion(passkey: Passkey, clientDataHash: Data) {
        log.trace("Will return passkey")
        watchdog.restart()

        guard let passkeyCredential =
                passkey.makeAssertionCredential(clientDataHash: clientDataHash)
        else {
            log.error("Failed to make passkey credential, cancelling")
            assertionFailure()
            cancelRequest(.failed)
            return
        }
        extensionContext.completeAssertionRequest(
            using: passkeyCredential,
            completionHandler: { [self] expired in
                log.info("Did return passkey (exp: \(expired))")
            }
        )

        if hasUI {
            HapticFeedback.play(.credentialsPasted)
        }
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }
}

extension AutoFillCoordinator {
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
        guard let foundEntry = findEntry(matching: record, in: databaseFile) else {
            cancelRequest(.credentialIdentityNotFound)
            return
        }
        log.trace("returnQuickTypeEntry")
        returnEntry(foundEntry)
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
            assertionFailure("This should not be possible")
            log.error("DB loading was cancelled without UI, cancelling request.")
            cancelRequest(.failed)
        case .invalidKey:
            log.error("DB loading failed: invalid key. Switching to UI")
            cancelRequest(.userInteractionRequired)
        default:
            log.error("DB loading failed: \(error.localizedDescription, privacy: .public). Switching to UI")
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
            log.error("quickTypeRequiredRecord is unexpectedly nil, switching to UI")
            assertionFailure()
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
        if isAppLockVisible || isInDeviceAutoFillSettings {
            return
        }
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
        if Settings.current.isLockDatabasesOnTimeout {
            entryFinderCoordinator?.lockDatabase()
        } else {
            entryFinderCoordinator?.stop(animated: animate, completion: nil)
        }
    }

    private func dismissPasscodeAndContinue() {
        if let passcodeInputVC = passcodeInputController {
            rootController.swapChildViewControllers(
                from: passcodeInputVC,
                to: router.navigationController,
                options: .transitionCrossDissolve,
                completion: { [weak self] _ in
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

    func passcodeInput(_ sender: PasscodeInputVC, shouldTryPasscode passcode: String) {
        let isMatch = try? Keychain.shared.isAppPasscodeMatch(passcode)
        if isMatch ?? false {
            passcodeInput(sender, didEnterPasscode: passcode)
        }
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

    func didPressAddExistingDatabase(in firstSetup: FirstSetupVC) {
        watchdog.restart()
        firstSetup.dismiss(animated: true, completion: nil)
        databasePickerCoordinator.addExternalDatabase(presenter: router.navigationController)
    }

    func didPressAddRemoteDatabase(in firstSetup: FirstSetupVC) {
        watchdog.restart()
        firstSetup.dismiss(animated: true, completion: nil)
        databasePickerCoordinator.maybeAddRemoteDatabase(
            bypassPaywall: false,
            presenter: router.navigationController
        )
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
        assert(memoryFootprintBeforeDatabaseMiB == nil)
        memoryFootprintBeforeDatabaseMiB = MemoryMonitor.getMemoryFootprintMiB()
        Diag.debug(String(format: "Memory use before loading: %.1f MiB", memoryFootprintBeforeDatabaseMiB!))

        Settings.current.isAutoFillFinishedOK = false
    }

    func didNotUnlockDatabase(
        _ fileRef: URLReference,
        with message: String?,
        reason: String?,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        Settings.current.isAutoFillFinishedOK = true
        memoryFootprintBeforeDatabaseMiB = nil
    }

    func shouldChooseFallbackStrategy(
        for fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> UnreachableFileFallbackStrategy {
        return DatabaseSettingsManager.shared.getFallbackStrategy(fileRef, forAutoFill: true)
    }

    func didUnlockDatabase(
        databaseFile: DatabaseFile,
        at fileRef: URLReference,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        if let memoryFootprintBeforeDatabaseMiB {
            let currentFootprintMiB = MemoryMonitor.getMemoryFootprintMiB()
            Diag.debug(String(format: "Memory use after loading: %.1f MiB", currentFootprintMiB))
            databaseMemoryFootprintMiB = max(currentFootprintMiB - memoryFootprintBeforeDatabaseMiB, 0)
            let kdfMemoryFootprintMiB = MemoryMonitor.bytesToMiB(databaseFile.database.peakKDFMemoryFootprint)
            Diag.debug(String(
                format: "DB memory footprint: %.1f MiB KDF + %.1f MiB data",
                kdfMemoryFootprintMiB,
                databaseMemoryFootprintMiB!
            ))
        } else {
            assertionFailure("memoryAvailableBeforeDatabaseLoad is unexpectedly nil")
        }
        memoryFootprintBeforeDatabaseMiB = nil

        Settings.current.isAutoFillFinishedOK = true
        if let targetRecord = quickTypeRequiredRecord,
           let desiredEntry = findEntry(matching: targetRecord, in: databaseFile),
           autoFillMode != .passkeyRegistration
        {
            log.trace("Unlocked and found a match")
            returnEntry(desiredEntry)
        } else {
            showDatabaseViewer(fileRef, databaseFile: databaseFile, warnings: warnings)
        }
    }

    func didPressReinstateDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        router.pop(animated: true, completion: { [weak self] in
            self?.reinstateDatabase(fileRef)
        })
    }

    func didPressAddRemoteDatabase(in coordinator: DatabaseUnlockerCoordinator) {
        router.pop(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            self.databasePickerCoordinator.maybeAddRemoteDatabase(
                bypassPaywall: true,
                presenter: self.router.navigationController
            )
        })
    }
}

extension AutoFillCoordinator: EntryFinderCoordinatorDelegate {
    func didLeaveDatabase(in coordinator: EntryFinderCoordinator) {
    }

    func didSelectEntry(_ entry: Entry, in coordinator: EntryFinderCoordinator) {
        log.trace("didSelectEntry")
        returnEntry(entry)
    }

    @available(iOS 18.0, *)
    func didSelectText(_ text: String, in coordinator: EntryFinderCoordinator) {
        returnText(text)
    }

    func didPressReinstateDatabase(_ fileRef: URLReference, in coordinator: EntryFinderCoordinator) {
        coordinator.stop(animated: true) { [weak self] in
            self?.reinstateDatabase(fileRef)
        }
    }

    func didPressCreatePasskey(
        with params: PasskeyRegistrationParams,
        target entry: Entry?,
        presenter: UIViewController,
        in coordinator: EntryFinderCoordinator
    ) {
        startPasskeyRegistration(
            with: params,
            target: entry,
            in: coordinator.databaseFile,
            presenter: presenter
        )
    }
}

extension AutoFillCoordinator: DatabaseSaving {
    var savingProgressHost: ProgressViewHost? {
        return router
    }

    func didRelocate(databaseFile: KeePassiumLib.DatabaseFile, to newURL: URL) {
    }

    func getDatabaseSavingErrorParent() -> UIViewController {
        return router.navigationController
    }
}

#if INTUNE
extension AutoFillCoordinator {

    private func getPresenterForModals() -> UIViewController {
        return router.navigationController
    }

    private func setupIntune() {
        assert(policyDelegate == nil && enrollmentDelegate == nil, "Repeated call to Intune setup")

        policyDelegate = IntunePolicyDelegateImpl()
        IntuneMAMPolicyManager.instance().delegate = policyDelegate

        enrollmentDelegate = IntuneEnrollmentDelegateImpl(
            onEnrollment: { [weak self] enrollmentResult in
                guard let self = self else { return }
                switch enrollmentResult {
                case .success:
                    self.runAfterStartTasks()
                case .cancelledByUser:
                    let message = [
                            LString.Intune.orgNeedsToManage,
                            LString.Intune.personalVersionInAppStore,
                        ].joined(separator: "\n\n")
                    // swiftlint:disable:previous literal_expression_end_indentation
                    self.showIntuneMessageAndRestartEnrollment(message)
                case .failure(let errorMessage):
                    self.showIntuneMessageAndRestartEnrollment(errorMessage)
                }
            },
            onUnenrollment: { [weak self] wasSuccessful in
                self?.startIntuneEnrollment()
            }
        )
        IntuneMAMEnrollmentManager.instance().delegate = enrollmentDelegate

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyIntuneAppConfig),
            name: NSNotification.Name.IntuneMAMAppConfigDidChange,
            object: IntuneMAMAppConfigManager.instance()
        )
    }

    private func startIntuneEnrollment() {
        let enrollmentManager = IntuneMAMEnrollmentManager.instance()
        enrollmentManager.delegate = enrollmentDelegate
        enrollmentManager.loginAndEnrollAccount(enrollmentManager.enrolledAccount())
    }

    private func showIntuneMessageAndRestartEnrollment(_ message: String) {
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(title: LString.actionOK, style: .default) { [weak self] _ in
            self?.startIntuneEnrollment()
        }
        getPresenterForModals().present(alert, animated: true)
    }

    @objc private func applyIntuneAppConfig() {
        guard let enrolledUser = IntuneMAMEnrollmentManager.instance().enrolledAccount() else {
            assertionFailure("There must be an enrolled account by now")
            Diag.warning("No enrolled account found")
            return
        }
        let config = IntuneMAMAppConfigManager.instance().appConfig(forIdentity: enrolledUser)
        ManagedAppConfig.shared.setIntuneAppConfig(config.fullData)
    }

    private func showOrgLicensePaywall() {
        let message = [
                LString.Intune.orgLicenseMissing,
                LString.Intune.hintContactYourAdmin,
            ].joined(separator: "\n\n")
        // swiftlint:disable:previous literal_expression_end_indentation
        let alert = UIAlertController(
            title: AppInfo.name,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(title: LString.actionRetry, style: .default) { [weak self] _ in
            self?.runAfterStartTasks()
        }
        DispatchQueue.main.async {
            self.getPresenterForModals().present(alert, animated: true)
        }
    }
}
#endif
