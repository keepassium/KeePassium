//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication
#if INTUNE
import IntuneMAMSwift
import MSAL
#endif

final class MainCoordinator: Coordinator {
    enum Action {
        case showAboutScreen
        case showAppSettings
        case createDatabase
        case openDatabase

        case lockDatabase
        case createEntry
        case createGroup
    }

    var childCoordinators = [Coordinator]()

    var dismissHandler: CoordinatorDismissHandler? {
        didSet {
            fatalError("Don't set dismiss handler in MainCoordinator, it is never called.")
        }
    }

    private let rootSplitVC: RootSplitVC
    private let primaryRouter: NavigationRouter
    private let placeholderRouter: NavigationRouter
    private var databaseUnlockerRouter: NavigationRouter?

    private var databasePickerCoordinator: DatabasePickerCoordinator!
    private var databaseViewerCoordinator: DatabaseViewerCoordinator?

    private let watchdog: Watchdog
    private let localNotifications = LocalNotifications()
    private let mainWindow: UIWindow
    fileprivate var appCoverWindow: UIWindow?
    fileprivate var appLockWindow: UIWindow?
    fileprivate var biometricsBackgroundWindow: UIWindow?
    fileprivate var isBiometricAuthShown = false
    private var isInitialAppLock = true

    fileprivate let biometricAuthReuseDuration = TimeInterval(3.0)
    fileprivate var lastSuccessfulBiometricAuthTime: Date = .distantPast

    #if INTUNE
    private var enrollmentDelegate: IntuneEnrollmentDelegateImpl?
    private var policyDelegate: IntunePolicyDelegateImpl?
    #endif

    private var selectedDatabaseRef: URLReference?

    private var isInitialDatabase = true

    private var isReloadingDatabase = false

    init(window: UIWindow) {
        self.mainWindow = window
        self.rootSplitVC = RootSplitVC()

        let primaryNavVC = RouterNavigationController()
        primaryRouter = NavigationRouter(primaryNavVC)

        let placeholderVC = PlaceholderVC.instantiateFromStoryboard()
        let placeholderNavVC = RouterNavigationController(rootViewController: placeholderVC)
        placeholderRouter = NavigationRouter(placeholderNavVC)

        rootSplitVC.viewControllers = [primaryNavVC, placeholderNavVC]

        UNUserNotificationCenter.current().delegate = localNotifications

        watchdog = Watchdog.shared
        watchdog.delegate = self

        rootSplitVC.delegate = self
        rootSplitVC.maximumPrimaryColumnWidth = 700
        window.rootViewController = rootSplitVC

        #if targetEnvironment(macCatalyst)
        if #available(macCatalyst 16.0, *) { 
            let titlebar = UIApplication.shared.currentScene?.titlebar
            titlebar?.titleVisibility = .hidden
        }
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start(hasIncomingURL: Bool) {
        Diag.info(AppInfo.description)
        PremiumManager.shared.startObservingTransactions()

        FileKeeper.shared.delegate = self

        watchdog.didBecomeActive()
        StoreReviewSuggester.registerEvent(.sessionStart)

        assert(databasePickerCoordinator == nil)
        databasePickerCoordinator = DatabasePickerCoordinator(router: primaryRouter, mode: .full)
        databasePickerCoordinator.delegate = self
        databasePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databasePickerCoordinator.start()
        addChildCoordinator(databasePickerCoordinator)

        showPlaceholder()

        guard !hasIncomingURL else {
            databasePickerCoordinator.shouldSelectDefaultDatabase = false
            return
        }

        #if INTUNE
        setupIntune()
        guard let currentUser = IntuneMAMEnrollmentManager.instance().enrolledAccount(),
              !currentUser.isEmpty
        else {
            Diag.debug("Intune account missing, starting enrollment")
            startIntuneEnrollment()
            return
        }
        Diag.info("Intune account is enrolled")
        #endif

        runAfterStartTasks()
    }

    private func runAfterStartTasks() {
        #if INTUNE
        applyIntuneAppConfig()

        guard LicenseManager.shared.hasActiveBusinessLicense() else {
            showOrgLicensePaywall()
            return
        }
        #endif
        DispatchQueue.main.async { [weak self] in
            self?.maybeShowOnboarding()
        }

        let isAutoUnlockStartupDatabase = Settings.current.isAutoUnlockStartupDatabase
        databasePickerCoordinator.shouldSelectDefaultDatabase = isAutoUnlockStartupDatabase
    }

    private func getPresenterForModals() -> UIViewController {
        return rootSplitVC.presentedViewController ?? rootSplitVC
    }
}

#if INTUNE
extension MainCoordinator {
    private func setupIntune() {
        assert(policyDelegate == nil && enrollmentDelegate == nil, "Repeated call to Intune setup")

        policyDelegate = IntunePolicyDelegateImpl()
        IntuneMAMPolicyManager.instance().delegate = policyDelegate

        enrollmentDelegate = IntuneEnrollmentDelegateImpl(
            onEnrollment: { [weak self] enrollmentResult in
                guard let self = self else { return }
                switch enrollmentResult {
                case .success:
                    Diag.info("Intune enrollment successful")
                    self.runAfterStartTasks()
                case .cancelledByUser:
                    let message = [
                            LString.Intune.orgNeedsToManage,
                            LString.Intune.personalVersionInAppStore
                        ].joined(separator: "\n\n")
                    // swiftlint:disable:previous literal_expression_end_indentation
                    Diag.error("Intune enrollment cancelled")
                    self.showIntuneMessageAndRestartEnrollment(message)
                case .failure(let errorMessage):
                    Diag.error("Intune enrollment failed [message: \(errorMessage)]")
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
        Diag.debug("Starting Intune enrollment")
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
        Diag.error(message)
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(title: LString.actionRetry, style: .default) { [weak self] _ in
            self?.runAfterStartTasks()
        }
        alert.addAction(title: LString.titleDiagnosticLog, style: .default) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.showDiagnostics(onDismiss: { [weak self] in
                    self?.runAfterStartTasks()
                })
            }
        }
        DispatchQueue.main.async {
            self.getPresenterForModals().present(alert, animated: true)
        }
    }
}
#endif

extension MainCoordinator {
    public func processIncomingURL(_ url: URL, sourceApp: String?, openInPlace: Bool?) -> Bool {
        #if INTUNE
        if url.absoluteString.hasPrefix(MSALOneDriveAuthProvider.redirectURI) {
            let isHandled = MSALPublicClientApplication.handleMSALResponse(
                url,
                sourceApplication: sourceApp)
            Diag.info("Processed MSAL auth callback [isHandled: \(isHandled)]")
            return isHandled
        }
        #endif
        Diag.info("Will process incoming URL [inPlace: \(openInPlace), URL: \(url.redacted)]")
        guard let databaseViewerCoordinator = databaseViewerCoordinator else {
            handleIncomingURL(url, openInPlace: openInPlace ?? true)
            return true
        }
        databaseViewerCoordinator.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: false,
            completion: { [weak self] in
                self?.handleIncomingURL(url, openInPlace: openInPlace ?? true)
            }
        )
        return true
    }

    private func handleIncomingURL(_ url: URL, openInPlace: Bool) {
        guard url.scheme != AppGroup.appURLScheme else {
            processDeepLink(url)
            return
        }

        FileKeeper.shared.addFile(
            url: url,
            fileType: nil, 
            mode: openInPlace ? .openInPlace : .import,
            completion: { [weak self] result in
                switch result {
                case .success:
                    break
                case .failure(let fileKeeperError):
                    Diag.error(fileKeeperError.localizedDescription)
                    self?.getPresenterForModals().showErrorAlert(fileKeeperError)
                }
            }
        )
    }

    private func processDeepLink(_ url: URL) {
        assert(url.scheme == AppGroup.appURLScheme)
        switch url {
        case AppGroup.upgradeToPremiumURL:
            showPremiumUpgrade(in: rootSplitVC)
        case AppGroup.donateURL:
            showDonationScreen(in: rootSplitVC)
        default:
            Diag.warning("Unrecognized URL, ignoring [url: \(url.absoluteString)]")
        }
    }
}

extension MainCoordinator {
    func canPerform(action: Action) -> Bool {
        if isAppLockVisible {
            return false
        }
        switch action {
        case .showAboutScreen:
            return true
        case .showAppSettings:
            return true
        case .createDatabase:
            return true
        case .openDatabase:
            return true
        case .lockDatabase:
            return databaseViewerCoordinator?.canPerform(action: .lockDatabase) ?? false
        case .createEntry:
            return databaseViewerCoordinator?.canPerform(action: .createEntry) ?? false
        case .createGroup:
            return databaseViewerCoordinator?.canPerform(action: .createGroup) ?? false
        }
    }

    func perform(action: Action) {
        switch action {
        case .showAboutScreen:
            showAboutScreen()
        case .showAppSettings:
            showSettingsScreen()
        case .createDatabase:
            createDatabase()
        case .openDatabase:
            openDatabase()
        case .lockDatabase:
            databaseViewerCoordinator?.perform(action: .lockDatabase)
        case .createEntry:
            databaseViewerCoordinator?.perform(action: .createEntry)
        case .createGroup:
            databaseViewerCoordinator?.perform(action: .createGroup)
        }
    }
}

extension MainCoordinator {

    private func setDatabase(
        _ databaseRef: URLReference?,
        autoOpenWith context: DatabaseReloadContext? = nil
    ) {
        self.selectedDatabaseRef = databaseRef
        guard let databaseRef = databaseRef else {
            showPlaceholder()
            return
        }

        let dbUnlocker = showDatabaseUnlocker(databaseRef)
        dbUnlocker.reloadingContext = context
        dbUnlocker.setDatabase(databaseRef)
    }

    private func maybeShowOnboarding() {
        let files = FileKeeper.shared.getAllReferences(fileType: .database, includeBackup: true)
        guard files.isEmpty else {
            return 
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let onboardingCoordinator = OnboardingCoordinator(router: modalRouter)
        onboardingCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        onboardingCoordinator.delegate = self
        onboardingCoordinator.start()
        addChildCoordinator(onboardingCoordinator)

        rootSplitVC.present(modalRouter, animated: true, completion: nil)
    }

    private func showPlaceholder() {
        if !rootSplitVC.isCollapsed {
            rootSplitVC.setDetailRouter(placeholderRouter)
        }
        deallocateDatabaseUnlocker()
    }

    private func showDatabaseUnlocker(_ databaseRef: URLReference) -> DatabaseUnlockerCoordinator {
        if let databaseUnlockerRouter = databaseUnlockerRouter {
            rootSplitVC.setDetailRouter(databaseUnlockerRouter)
            if let existingDBUnlocker = childCoordinators.first(where: { $0 is DatabaseUnlockerCoordinator }) {
                return existingDBUnlocker as! DatabaseUnlockerCoordinator
            } else {
                Diag.warning("Internal inconsistency: router without coordinator")
                assertionFailure()
            }
        }

        databaseUnlockerRouter = NavigationRouter(RouterNavigationController())
        let router = databaseUnlockerRouter! 

        let newDBUnlockerCoordinator = DatabaseUnlockerCoordinator(
            router: router,
            databaseRef: databaseRef
        )
        newDBUnlockerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.databaseUnlockerRouter = nil
        }
        newDBUnlockerCoordinator.delegate = self
        newDBUnlockerCoordinator.start()
        addChildCoordinator(newDBUnlockerCoordinator)

        rootSplitVC.setDetailRouter(router)

        return newDBUnlockerCoordinator
    }

    private func showDatabaseViewer(
        _ fileRef: URLReference,
        databaseFile: DatabaseFile,
        context: DatabaseReloadContext?,
        warnings: DatabaseLoadingWarnings
    ) {
        let databaseViewerCoordinator = DatabaseViewerCoordinator(
            splitViewController: rootSplitVC,
            primaryRouter: primaryRouter,
            originalRef: fileRef, 
            databaseFile: databaseFile, 
            context: context,
            loadingWarnings: warnings
        )
        databaseViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            self?.databaseViewerCoordinator = nil
        }
        databaseViewerCoordinator.delegate = self
        databaseViewerCoordinator.start()
        addChildCoordinator(databaseViewerCoordinator)
        self.databaseViewerCoordinator = databaseViewerCoordinator

        deallocateDatabaseUnlocker()
    }

    private func deallocateDatabaseUnlocker() {
        databaseUnlockerRouter = nil
        childCoordinators.removeAll(where: { $0 is DatabaseUnlockerCoordinator })
    }

    private func showDonationScreen(in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let tipBoxCoordinator = TipBoxCoordinator(router: modalRouter)
        tipBoxCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        tipBoxCoordinator.start()
        addChildCoordinator(tipBoxCoordinator)

        viewController.present(modalRouter, animated: true, completion: nil)
    }

    func showAboutScreen() {
        let popoverAnchor = PopoverAnchor(sourceView: mainWindow, sourceRect: mainWindow.bounds)
        self.databasePickerCoordinator.showAboutScreen(at: popoverAnchor, in: self.rootSplitVC)
    }

    func showSettingsScreen() {
        let popoverAnchor = PopoverAnchor(sourceView: mainWindow, sourceRect: mainWindow.bounds)
        self.databasePickerCoordinator.showAppSettings(at: popoverAnchor, in: self.rootSplitVC)
    }

    func showDiagnostics(onDismiss: (() -> Void)? = nil) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
            onDismiss?()
        }
        diagnosticsViewerCoordinator.start()

        getPresenterForModals().present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator)
    }

    func createDatabase() {
        guard let dbViewer = databaseViewerCoordinator else {
            databasePickerCoordinator.maybeCreateDatabase(presenter: rootSplitVC)
            return
        }
        dbViewer.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: true,
            completion: { [weak self] in
                guard let self = self else { return }
                self.databasePickerCoordinator.maybeCreateDatabase(presenter: self.rootSplitVC)
            }
        )
    }

    func openDatabase() {
        guard let dbViewer = databaseViewerCoordinator else {
            databasePickerCoordinator.maybeAddExternalDatabase(presenter: rootSplitVC)
            return
        }
        dbViewer.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: true,
            completion: { [weak self] in
                guard let self = self else { return }
                self.databasePickerCoordinator.maybeAddExternalDatabase(presenter: self.rootSplitVC)
            }
        )
    }

    func lockDatabase() {
        assert(databaseViewerCoordinator != nil, "Tried to lock database, but there is none opened")
        databaseViewerCoordinator?.closeDatabase(
            shouldLock: true,
            reason: .userRequest,
            animated: true,
            completion: nil
        )
    }

    private func reinstateDatabase(_ fileRef: URLReference) {
        switch fileRef.location {
        case .external:
            databasePickerCoordinator.addExternalDatabase(fileRef, presenter: getPresenterForModals())
        case .remote:
            databasePickerCoordinator.addRemoteDatabase(fileRef, presenter: getPresenterForModals())
        case .internalBackup, .internalDocuments, .internalInbox:
            assertionFailure("Should not be here. Can reinstate only external or remote files.")
            return
        }
    }

    private func reloadDatabase(
        _ databaseFile: DatabaseFile,
        from databaseViewerCoordinator: DatabaseViewerCoordinator
    ) {
        let context = DatabaseReloadContext(for: databaseFile.database)
        context.groupUUID = databaseViewerCoordinator.currentGroupUUID

        isReloadingDatabase = true
        databaseViewerCoordinator.closeDatabase(
            shouldLock: false,
            reason: .userRequest,
            animated: true
        ) { [weak self] in
            guard let self else { return }
            guard let dbRef = databaseFile.fileReference else {
                Diag.debug("Database file reference is nil, cancelling")
                assertionFailure()
                return
            }
            setDatabase(dbRef, autoOpenWith: context)
        }
    }
}

extension MainCoordinator: UISplitViewControllerDelegate {
    func splitViewController(
        _ splitViewController: UISplitViewController,
        collapseSecondary secondaryViewController: UIViewController,
        onto primaryViewController: UIViewController
    ) -> Bool {
        if secondaryViewController is PlaceholderVC {
            return true 
        }
        if let secondaryNavVC = secondaryViewController as? UINavigationController,
           let topSecondary = secondaryNavVC.topViewController,
           topSecondary is PlaceholderVC
        {
            return true 
        }

        return false
    }

    func splitViewController(
        _ splitViewController: UISplitViewController,
        separateSecondaryFrom primaryViewController: UIViewController
    ) -> UIViewController? {
        if databaseUnlockerRouter != nil {
            return databaseUnlockerRouter?.navigationController
        }
        return placeholderRouter.navigationController
    }

    func primaryViewController(forExpanding splitViewController: UISplitViewController) -> UIViewController? {
        return primaryRouter.navigationController
    }
    func primaryViewController(forCollapsing splitViewController: UISplitViewController) -> UIViewController? {
        return primaryRouter.navigationController
    }
}

extension MainCoordinator: WatchdogDelegate {
    var isAppCoverVisible: Bool {
        return appCoverWindow != nil
    }
    var isAppLockVisible: Bool {
        return appLockWindow != nil || isBiometricAuthShown
    }
    func showAppCover(_ sender: Watchdog) {
        showAppCoverScreen()
    }
    func hideAppCover(_ sender: Watchdog) {
        hideAppCoverScreen()
    }
    func showAppLock(_ sender: Watchdog) {
        showAppLockScreen()
    }
    func hideAppLock(_ sender: Watchdog) {
        hideAppLockScreen()
    }

    private func showAppCoverScreen() {
        guard appCoverWindow == nil else { return }

        let currentScreen = mainWindow.screen
        let _appCoverWindow = UIWindow(frame: currentScreen.bounds)
        _appCoverWindow.setScreen(currentScreen)
        _appCoverWindow.windowLevel = UIWindow.Level.alert
        self.appCoverWindow = _appCoverWindow

        let coverVC = AppCoverVC.make()
        DispatchQueue.main.async { [_appCoverWindow, coverVC] in
            UIView.performWithoutAnimation {
                _appCoverWindow.rootViewController = coverVC
                _appCoverWindow.makeKeyAndVisible()
            }
            print("App cover shown")
            coverVC.view.accessibilityViewIsModal = true
            coverVC.view.snapshotView(afterScreenUpdates: true)
        }
    }

    private func hideAppCoverScreen() {
        guard let appCoverWindow = appCoverWindow else { return }
        appCoverWindow.isHidden = true
        self.appCoverWindow = nil
        print("App cover hidden")
    }

    private func canUseBiometrics() -> Bool {
        return Settings.current.isBiometricAppLockEnabled
            && LAContext.isBiometricsAvailable()
            && Keychain.shared.isBiometricAuthPrepared()
    }

    private func showAppLockScreen() {
        guard !isAppLockVisible else { return }
        let isRepeatedLockOnMac = ProcessInfo.isRunningOnMac && !isInitialAppLock
        isInitialAppLock = false
        if canUseBiometrics() && !isRepeatedLockOnMac {
            performBiometricUnlock()
        } else {
            showPasscodeRequest()
        }
    }

    private func hideAppLockScreen() {
        guard isAppLockVisible else { return }

        let window = UIApplication.shared.delegate!.window!
        window?.makeKeyAndVisible()
        appLockWindow?.resignKey()
        appLockWindow?.isHidden = true
        appLockWindow = nil
        print("appLockWindow hidden")
    }

    private func showPasscodeRequest() {
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .verification
        passcodeInputVC.isCancelAllowed = false 
        passcodeInputVC.isBiometricsAllowed = canUseBiometrics()

        let currentScreen = mainWindow.screen
        let _appLockWindow = UIWindow(frame: currentScreen.bounds)
        _appLockWindow.setScreen(currentScreen)
        _appLockWindow.windowLevel = UIWindow.Level.alert
        UIView.performWithoutAnimation {
            _appLockWindow.rootViewController = passcodeInputVC
            _appLockWindow.makeKeyAndVisible()
            let window = UIApplication.shared.delegate!.window!
            window?.isHidden = true
        }
        passcodeInputVC.view.accessibilityViewIsModal = true
        passcodeInputVC.view.snapshotView(afterScreenUpdates: true)

        self.appLockWindow = _appLockWindow
        print("passcode request shown")
    }

    private func performBiometricUnlock() {
        guard !isBiometricAuthShown,
              canUseBiometrics()
        else {
            return
        }

        let timeSinceLastSuccess = abs(Date.now.timeIntervalSince(lastSuccessfulBiometricAuthTime))
        if timeSinceLastSuccess < biometricAuthReuseDuration {
            print("Skipping repeated biometric prompt")
            watchdog.unlockApp()
            return
        }

        print("Showing biometrics request")
        showBiometricsBackground()
        lastSuccessfulBiometricAuthTime = .distantPast
        Keychain.shared.performBiometricAuth { [weak self] success in
            guard let self = self else { return }
            if success {
                Diag.warning("Biometric auth successful")
                self.lastSuccessfulBiometricAuthTime = Date.now
                self.watchdog.unlockApp()
            } else {
                Diag.warning("Biometric auth failed")
                self.lastSuccessfulBiometricAuthTime = .distantPast
                self.showPasscodeRequest()
            }
            self.hideBiometricsBackground()
            self.isBiometricAuthShown = false
        }
        isBiometricAuthShown = true
    }

    private func showBiometricsBackground() {
        guard biometricsBackgroundWindow == nil else { return }

        let currentScreen = mainWindow.screen
        let window = UIWindow(frame: currentScreen.bounds)
        window.setScreen(currentScreen)
        window.windowLevel = UIWindow.Level.alert + 1 
        let coverVC = AppCoverVC.make()

        UIView.performWithoutAnimation {
            window.rootViewController = coverVC
            window.makeKeyAndVisible()
        }
        print("Biometrics background shown")
        self.biometricsBackgroundWindow = window

        coverVC.view.snapshotView(afterScreenUpdates: true)
    }

    private func hideBiometricsBackground() {
        guard let window = biometricsBackgroundWindow else { return }
        window.isHidden = true
        self.biometricsBackgroundWindow = nil
        print("Biometrics background hidden")
    }

    func mustCloseDatabase(_ sender: Watchdog, animate: Bool) {
        databaseViewerCoordinator?.closeDatabase(
            shouldLock: Settings.current.premiumIsLockDatabasesOnTimeout,
            reason: .databaseTimeout,
            animated: animate,
            completion: nil
        )
    }
}

extension MainCoordinator: PasscodeInputDelegate {
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
                watchdog.unlockApp()
                Keychain.shared.prepareBiometricAuth(true)
            } else {
                HapticFeedback.play(.wrongPassword)
                sender.animateWrongPassccode()
                StoreReviewSuggester.registerEvent(.trouble)
                if Settings.current.isLockAllDatabasesOnFailedPasscode {
                    DatabaseSettingsManager.shared.eraseAllMasterKeys()
                    databaseViewerCoordinator?.closeDatabase(
                        shouldLock: true,
                        reason: .databaseTimeout,
                        animated: false,
                        completion: nil
                    )
                }
            }
        } catch {
            let alert = UIAlertController.make(
                title: LString.titleKeychainError,
                message: error.localizedDescription)
            sender.present(alert, animated: true, completion: nil)
        }
    }

    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {
        assert(canUseBiometrics())
        performBiometricUnlock()
    }
}

extension MainCoordinator: OnboardingCoordinatorDelegate {
    func didPressCreateDatabase(in coordinator: OnboardingCoordinator) {
        coordinator.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.databasePickerCoordinator.createDatabase(
                presenter: self.rootSplitVC
            )
        })
    }

    func didPressAddExistingDatabase(in coordinator: OnboardingCoordinator) {
        coordinator.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.databasePickerCoordinator.addExternalDatabase(
                presenter: self.rootSplitVC
            )
        })
    }

    func didPressConnectToServer(in coordinator: OnboardingCoordinator) {
        Diag.info("Network access permission implied by user action")
        Settings.current.isNetworkAccessAllowed = true
        coordinator.dismiss(completion: { [weak self] in
            guard let self = self else { return }
            self.databasePickerCoordinator.addRemoteDatabase(
                presenter: self.rootSplitVC
            )
        })
    }
}

extension MainCoordinator: FileKeeperDelegate {
    func shouldResolveImportConflict(
        target: URL,
        handler: @escaping (FileKeeper.ConflictResolution) -> Void
    ) {
        assert(Thread.isMainThread, "FileKeeper called its delegate on background queue, that's illegal")
        let fileName = target.lastPathComponent
        let choiceAlert = UIAlertController(
            title: fileName,
            message: LString.fileAlreadyExists,
            preferredStyle: .alert)
        let actionOverwrite = UIAlertAction(title: LString.actionOverwrite, style: .destructive) { _ in
            handler(.overwrite)
        }
        let actionRename = UIAlertAction(title: LString.actionRename, style: .default) { _ in
            handler(.rename)
        }
        let actionAbort = UIAlertAction(title: LString.actionCancel, style: .cancel) { _ in
            handler(.abort)
        }
        choiceAlert.addAction(actionOverwrite)
        choiceAlert.addAction(actionRename)
        choiceAlert.addAction(actionAbort)

        getPresenterForModals().present(choiceAlert, animated: true)
    }
}

extension MainCoordinator: DatabasePickerCoordinatorDelegate {
    func shouldAcceptDatabaseSelection(
        _ fileRef: URLReference,
        in coordinator: DatabasePickerCoordinator
    ) -> Bool {
        return true
    }

    func didSelectDatabase(_ fileRef: URLReference?, in coordinator: DatabasePickerCoordinator) {
        setDatabase(fileRef)
    }

    func shouldKeepSelection(in coordinator: DatabasePickerCoordinator) -> Bool {
        return !rootSplitVC.isCollapsed
    }
}

extension MainCoordinator: DatabaseUnlockerCoordinatorDelegate {
    func shouldDismissFromKeyboard(_ coordinator: DatabaseUnlockerCoordinator) -> Bool {
        if rootSplitVC.isCollapsed {
            return true
        } else {
            return false
        }
    }

    func shouldAutoUnlockDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> Bool {
        if isReloadingDatabase {
            return true
        }
        if isInitialDatabase && Settings.current.isAutoUnlockStartupDatabase {
            return true
        }
        return rootSplitVC.isCollapsed
    }

    func willUnlockDatabase(_ fileRef: URLReference, in coordinator: DatabaseUnlockerCoordinator) {
        databasePickerCoordinator.setEnabled(false)
        isInitialDatabase = false
        isReloadingDatabase = false 
    }

    func didNotUnlockDatabase(
        _ fileRef: URLReference,
        with message: String?,
        reason: String?,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        databasePickerCoordinator.setEnabled(true)
    }

    func shouldChooseFallbackStrategy(
        for fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> UnreachableFileFallbackStrategy {
        return DatabaseSettingsManager.shared.getFallbackStrategy(fileRef, forAutoFill: false)
    }

    func didUnlockDatabase(
        databaseFile: DatabaseFile,
        at fileRef: URLReference,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        databasePickerCoordinator.setEnabled(true)

        showDatabaseViewer(
            fileRef,
            databaseFile: databaseFile,
            context: coordinator.reloadingContext,
            warnings: warnings
        )
    }

    func didPressReinstateDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        if rootSplitVC.isCollapsed {
            primaryRouter.pop(animated: true, completion: { [weak self] in
                self?.reinstateDatabase(fileRef)
            })
        } else {
            reinstateDatabase(fileRef)
        }
    }

    func didPressAddRemoteDatabase(in coordinator: DatabaseUnlockerCoordinator) {
        if rootSplitVC.isCollapsed {
            primaryRouter.pop(animated: true, completion: { [weak self] in
                guard let self = self else { return }
                self.databasePickerCoordinator.maybeAddRemoteDatabase(
                    bypassPaywall: true,
                    presenter: self.rootSplitVC
                )
            })
        } else {
            databasePickerCoordinator.maybeAddRemoteDatabase(
                bypassPaywall: true,
                presenter: rootSplitVC
            )
        }
    }
}

extension MainCoordinator: DatabaseViewerCoordinatorDelegate {
    func didRelocateDatabase(_ databaseFile: DatabaseFile, to url: URL) {
        Diag.debug("Will account relocated database")
        let fileKeeper = FileKeeper.shared

        if let oldReference = databaseFile.fileReference,
           fileKeeper.removeExternalReference(oldReference, fileType: .database)
        {
            Diag.debug("Did remove old reference")
        } else {
            Diag.debug("No old reference found")
        }

        databaseFile.fileURL = url
        fileKeeper.addFile(url: url, fileType: .database, mode: .openInPlace) { result in
            switch result {
            case .success(let fileRef):
                Diag.info("Relocated database reference added OK")
                databaseFile.fileReference = fileRef
            case .failure(let fileKeeperError):
                Diag.error("Failed to add relocated database [message: \(fileKeeperError.localizedDescription)")
            }
        }
    }

    func didLeaveDatabase(in coordinator: DatabaseViewerCoordinator) {
        Diag.debug("Did leave database")

        if !self.rootSplitVC.isCollapsed {
            self.databasePickerCoordinator.selectDatabase(self.selectedDatabaseRef, animated: false)
        }
    }

    func didPressReinstateDatabase(_ fileRef: URLReference, in coordinator: DatabaseViewerCoordinator) {
        databaseViewerCoordinator?.closeDatabase(
            shouldLock: false,
            reason: .userRequest,
            animated: true
        ) { [weak self] in
            self?.reinstateDatabase(fileRef)
        }
    }

    func didPressReloadDatabase(_ databaseFile: DatabaseFile, in coordinator: DatabaseViewerCoordinator) {
        reloadDatabase(databaseFile, from: coordinator)
    }
}
