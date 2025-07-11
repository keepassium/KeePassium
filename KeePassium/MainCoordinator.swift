//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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

final class MainCoordinator: UIResponder, Coordinator {
    var childCoordinators = [Coordinator]()

    var _dismissHandler: CoordinatorDismissHandler? {
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

    private var toolbarDelegate: ToolbarDelegate?

    private let autoTypeHelper: AutoTypeHelper?

    init(window: UIWindow, autoTypeHelper: AutoTypeHelper?) {
        self.mainWindow = window
        self.autoTypeHelper = autoTypeHelper
        self.rootSplitVC = RootSplitVC()

        let primaryNavVC = RouterNavigationController()
        primaryRouter = NavigationRouter(primaryNavVC)

        let placeholderVC = PlaceholderVC.instantiateFromStoryboard()
        let placeholderNavVC = RouterNavigationController(rootViewController: placeholderVC)
        placeholderRouter = NavigationRouter(placeholderNavVC)

        rootSplitVC.viewControllers = [primaryNavVC, placeholderNavVC]

        watchdog = Watchdog.shared
        super.init()

        watchdog.delegate = self

        rootSplitVC.delegate = self
        rootSplitVC.maximumPrimaryColumnWidth = 700
        window.rootViewController = rootSplitVC

        #if targetEnvironment(macCatalyst)
        setupMacToolbar()
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShakeGesture),
            name: UIDevice.deviceDidShakeNotification,
            object: nil)
    }

#if targetEnvironment(macCatalyst)
    private func setupMacToolbar() {
        guard let scene = UIApplication.shared.currentScene else {
            assertionFailure()
            return
        }
        let toolbar = NSToolbar(identifier: "main")
        toolbarDelegate = ToolbarDelegate(mainCoordinator: self)
        toolbar.delegate = toolbarDelegate
        if #available(macCatalyst 18.0, *) {
            toolbar.autosavesConfiguration = toolbar.allowsDisplayModeCustomization
        } else {
            toolbar.displayMode = .iconOnly
        }

        let titlebar = scene.titlebar
        titlebar?.toolbar = toolbar
        titlebar?.toolbarStyle = .automatic
        titlebar?.titleVisibility = .visible
        scene.sizeRestrictions?.minimumSize = CGSize(width: 400, height: 600)
    }

    private func removeMacToolbar() {
        let titlebar = UIApplication.shared.currentScene?.titlebar
        titlebar?.titleVisibility = .hidden
        titlebar?.toolbar = nil
    }
#endif

    deinit {
        NotificationCenter.default.removeObserver(self)
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }

    func start(hasIncomingURL: Bool, proposeReset: Bool) {
        Diag.info(AppInfo.description)
        guard !proposeReset else {
            showAppResetPrompt()
            return
        }
        PremiumManager.shared.startObservingTransactions()

        FileKeeper.shared.delegate = self

        watchdog.didBecomeActive()
        StoreReviewSuggester.registerEvent(.sessionStart)

        assert(databasePickerCoordinator == nil)
        databasePickerCoordinator = DatabasePickerCoordinator(router: primaryRouter, mode: .full)
        databasePickerCoordinator.delegate = self
        databasePickerCoordinator.start()
        addChildCoordinator(databasePickerCoordinator, onDismiss: nil)

        showPlaceholder()

        #if INTUNE
        setupIntune(hasIncomingURL: hasIncomingURL)
        guard let currentUser = IntuneMAMEnrollmentManager.instance().enrolledAccountId(),
              !currentUser.isEmpty
        else {
            Diag.debug("Intune account missing, starting enrollment")
            startIntuneEnrollment()
            return
        }
        Diag.info("Intune account is enrolled")
        #endif

        runAfterStartTasks(hasIncomingURL: hasIncomingURL)
    }

    private func showAppResetPrompt() {
        Diag.info("Proposing app reset")
        let alert = UIAlertController(
            title: AppInfo.name,
            message: LString.confirmAppReset,
            preferredStyle: .alert
        )
        alert.addAction(title: LString.actionResetApp, style: .destructive, preferred: false) {
            [unowned self] _ in
            AppEraser.resetApp { [unowned self] in
                start(hasIncomingURL: false, proposeReset: false)
            }
        }
        alert.addAction(title: LString.actionCancel, style: .cancel) { [weak self] _ in
            self?.start(hasIncomingURL: false, proposeReset: false)
        }
        getPresenterForModals().present(alert, animated: true)
    }

    private func runAfterStartTasks(hasIncomingURL: Bool) {
        #if INTUNE
        applyIntuneAppConfig()

        guard LicenseManager.shared.hasActiveBusinessLicense() else {
            showOrgLicensePaywall()
            return
        }
        #endif

        if Settings.current.isFirstLaunch {
            ensureAppDocumentsVisible()
        }

        if hasIncomingURL {
            Diag.info("Skipping other tasks for incoming URL")
            return
        }

        DispatchQueue.main.async { [self] in
            if !maybeOpenInitialDatabase() {
                maybeShowOnboarding()
            }
        }
    }

    private func maybeOpenInitialDatabase() -> Bool {
        if Settings.current.isAutoUnlockStartupDatabase,
           let startDatabaseRef = Settings.current.startupDatabase,
           databasePickerCoordinator.isKnownDatabase(startDatabaseRef)
        {
            if startDatabaseRef.hasError || startDatabaseRef.needsReinstatement {
                setDatabase(startDatabaseRef, andThen: .doNothing)
            } else {
                setDatabase(startDatabaseRef, andThen: .unlock)
            }
            return true
        }
        if rootSplitVC.isCollapsed {
            return false
        }
        let defaultDB = databasePickerCoordinator.getFirstListedDatabase()
        setDatabase(defaultDB, andThen: .focus)
        return false
    }

    private func getPresenterForModals() -> UIViewController {
        return rootSplitVC.presentedViewController ?? rootSplitVC
    }
}

#if INTUNE
extension MainCoordinator {
    private func setupIntune(hasIncomingURL: Bool) {
        assert(policyDelegate == nil && enrollmentDelegate == nil, "Repeated call to Intune setup")

        policyDelegate = IntunePolicyDelegateImpl()
        IntuneMAMPolicyManager.instance().delegate = policyDelegate

        enrollmentDelegate = IntuneEnrollmentDelegateImpl(
            onEnrollment: { [weak self] enrollmentResult in
                guard let self else { return }
                switch enrollmentResult {
                case .success:
                    Diag.info("Intune enrollment successful")
                    self.runAfterStartTasks(hasIncomingURL: hasIncomingURL)
                case .cancelledByUser:
                    let message = [
                            LString.Intune.orgNeedsToManage,
                            LString.Intune.personalVersionInAppStore
                    ].joined(separator: "\n\n")
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
        enrollmentManager.loginAndEnrollAccount(enrollmentManager.enrolledAccountId())
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
        guard let enrolledUserId = IntuneMAMEnrollmentManager.instance().enrolledAccountId() else {
            assertionFailure("There must be an enrolled account by now")
            Diag.warning("No enrolled account found")
            return
        }
        let config = IntuneMAMAppConfigManager.instance().appConfig(forAccountId: enrolledUserId)
        ManagedAppConfig.shared.setIntuneAppConfig(config.fullData)
    }

    private func showOrgLicensePaywall() {
        let message = [
                LString.Intune.orgLicenseMissing,
                LString.Intune.hintContactYourAdmin,
        ].joined(separator: "\n\n")
        Diag.error(message)
        let alert = UIAlertController(
            title: "",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(title: LString.actionRetry, style: .default) { [weak self] _ in
            self?.runAfterStartTasks(hasIncomingURL: false)
        }
        alert.addAction(title: LString.titleDiagnosticLog, style: .default) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.showDiagnostics(in: self.getPresenterForModals(), onDismiss: { [weak self] in
                    self?.runAfterStartTasks(hasIncomingURL: false)
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
        Diag.info("Will process incoming URL [inPlace: \(String(describing: openInPlace)), URL: \(url.redacted)]")
        guard let databaseViewerCoordinator else {
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

        if rootSplitVC.isCollapsed {
            rootSplitVC.ensurePrimaryVisible()
            primaryRouter.dismissModals(animated: false, completion: { [weak databasePickerCoordinator] in
                databasePickerCoordinator?.addDatabaseURL(url)
            })
        } else {
            databasePickerCoordinator.addDatabaseURL(url)
        }
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
    private func ensureAppDocumentsVisible() {
        if ProcessInfo.isRunningOnMac { return }
        guard FileProvider.localStorage.isAllowed else { return }

        do {
            try FileKeeper.shared.createPlaceholderInDocumentsDir()
            Diag.info("Made app folder visible in Files app (via placeholder file)")
        } catch {
            Diag.warning("Failed to create placeholder file in app folder: \(error)")
        }
    }

    private func setDatabase(
        _ databaseRef: URLReference?,
        autoOpenWith context: DatabaseReloadContext? = nil,
        andThen activation: DatabaseUnlockerActivationType = .doNothing
    ) {
        self.selectedDatabaseRef = databaseRef
        databasePickerCoordinator.selectDatabase(databaseRef, animated: false)
        guard let databaseRef else {
            showPlaceholder()
            return
        }

        let dbUnlocker = showDatabaseUnlocker(databaseRef, context: context)
        dbUnlocker.setDatabase(databaseRef, andThen: activation)
    }

    private func maybeShowOnboarding() {
        let files = FileKeeper.shared.getAllReferences(fileType: .database, includeBackup: true)
        guard files.isEmpty else {
            maybeStartAppPasscodeSetup()
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let onboardingCoordinator = OnboardingCoordinator(router: modalRouter)
        onboardingCoordinator.delegate = self
        onboardingCoordinator.start()
        addChildCoordinator(onboardingCoordinator, onDismiss: nil)

        rootSplitVC.present(modalRouter, animated: true, completion: nil)
    }

    private func showPlaceholder() {
        if !rootSplitVC.isCollapsed {
            rootSplitVC.setDetailRouter(placeholderRouter)
        }
        deallocateDatabaseUnlocker()
    }

    private func showDatabaseUnlocker(
        _ databaseRef: URLReference,
        context: DatabaseReloadContext?
    ) -> DatabaseUnlockerCoordinator {
        if let databaseUnlockerRouter {
            rootSplitVC.setDetailRouter(databaseUnlockerRouter)
            if let existingDBUnlocker = childCoordinators.first(where: { $0 is DatabaseUnlockerCoordinator }) {
                let dbUnlocker = existingDBUnlocker as! DatabaseUnlockerCoordinator
                dbUnlocker.reloadingContext = context
                return dbUnlocker
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
        newDBUnlockerCoordinator.delegate = self
        newDBUnlockerCoordinator.reloadingContext = context
        newDBUnlockerCoordinator.start()
        addChildCoordinator(newDBUnlockerCoordinator, onDismiss: { [weak self] _ in
            self?.databaseUnlockerRouter = nil
        })

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
            loadingWarnings: warnings,
            autoTypeHelper: autoTypeHelper
        )
        databaseViewerCoordinator.delegate = self
        databaseViewerCoordinator.start()
        addChildCoordinator(databaseViewerCoordinator, onDismiss: { [weak self] _ in
            self?.databaseViewerCoordinator = nil
            UIMenu.rebuildMainMenu()
        })
        self.databaseViewerCoordinator = databaseViewerCoordinator

        deallocateDatabaseUnlocker()
        UIMenu.rebuildMainMenu()
    }

    private func deallocateDatabaseUnlocker() {
        databaseUnlockerRouter = nil
        childCoordinators.removeAll(where: { $0 is DatabaseUnlockerCoordinator })
    }

    private func maybeStartAppPasscodeSetup() {
        let isPasscodeSet = (try? Keychain.shared.isAppPasscodeSet()) ?? false
        guard ManagedAppConfig.shared.isRequireAppPasscodeSet,
              !isPasscodeSet
        else {
            return
        }
        showAppPasscodeSetup()
    }

    private func showAppPasscodeSetup() {
        let passcodeVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeVC.mode = .setup
        passcodeVC.isCancelAllowed = false
        passcodeVC.delegate = self
        getPresenterForModals().present(passcodeVC, animated: true)
    }

    private func showDonationScreen(in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let tipBoxCoordinator = TipBoxCoordinator(router: modalRouter)
        tipBoxCoordinator.start()
        addChildCoordinator(tipBoxCoordinator, onDismiss: nil)

        viewController.present(modalRouter, animated: true, completion: nil)
    }

    func showAboutScreen(
        at popoverAnchor: PopoverAnchor?,
        in viewController: UIViewController
    ) {
        let popoverAnchor = popoverAnchor ?? mainWindow.asPopoverAnchor
        let modalRouter = NavigationRouter.createModal(
            style: ProcessInfo.isRunningOnMac ? .formSheet : .popover,
            at: popoverAnchor)
        let aboutCoordinator = AboutCoordinator(router: modalRouter)
        aboutCoordinator.start()
        addChildCoordinator(aboutCoordinator, onDismiss: nil)
        viewController.present(modalRouter, animated: true, completion: nil)
    }

    func showSettingsScreen(in viewController: UIViewController) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let settingsCoordinator = MainSettingsCoordinator(router: modalRouter)
        settingsCoordinator.start()
        addChildCoordinator(settingsCoordinator, onDismiss: nil)
        viewController.present(modalRouter, animated: true, completion: nil)
    }

    func showDiagnostics(in viewController: UIViewController, onDismiss: (() -> Void)? = nil) {
        let modalRouter = NavigationRouter.createModal(style: .formSheet)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: modalRouter)
        diagnosticsViewerCoordinator.start()

        viewController.present(modalRouter, animated: true, completion: nil)
        addChildCoordinator(diagnosticsViewerCoordinator, onDismiss: { [onDismiss] _ in
            onDismiss?()
        })
    }

    func createDatabase() {
        guard let dbViewer = databaseViewerCoordinator else {
            databasePickerCoordinator.paywalledStartDatabaseCreator(presenter: rootSplitVC)
            return
        }
        dbViewer.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: true,
            completion: { [weak self] in
                guard let self else { return }
                databasePickerCoordinator.paywalledStartDatabaseCreator(presenter: rootSplitVC)
            }
        )
    }

    func openDatabase() {
        guard let dbViewer = databaseViewerCoordinator else {
            databasePickerCoordinator.paywalledStartExternalDatabasePicker(presenter: rootSplitVC)
            return
        }
        dbViewer.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: true,
            completion: { [weak self] in
                guard let self else { return }
                databasePickerCoordinator.paywalledStartExternalDatabasePicker(presenter: rootSplitVC)
            }
        )
    }

    func connectToServer() {
        guard let dbViewer = databaseViewerCoordinator else {
            databasePickerCoordinator.paywalledStartRemoteDatabasePicker(
                bypassPaywall: true,
                presenter: rootSplitVC)
            return
        }
        dbViewer.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: true,
            completion: { [weak self] in
                guard let self else { return }
                databasePickerCoordinator.paywalledStartRemoteDatabasePicker(
                    bypassPaywall: true,
                    presenter: rootSplitVC
                )
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
            databasePickerCoordinator.startExternalDatabasePicker(fileRef, presenter: getPresenterForModals())
        case .remote:
            databasePickerCoordinator.startRemoteDatabasePicker(fileRef, presenter: getPresenterForModals())
        case .internalBackup, .internalDocuments, .internalInbox:
            assertionFailure("Should not be here. Can reinstate only external or remote files.")
            return
        }
    }

    private func reloadDatabase(
        _ databaseFile: DatabaseFile,
        targetRef: URLReference,
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
            setDatabase(targetRef, autoOpenWith: context, andThen: .unlock)
        }
    }

    private func switchToDatabase(
        _ fileRef: URLReference,
        key: CompositeKey,
        in databaseViewerCoordinator: DatabaseViewerCoordinator
    ) {
        let context = DatabaseReloadContext(key: key)

        isReloadingDatabase = true
        databaseViewerCoordinator.closeDatabase(
            shouldLock: false,
            reason: .userRequest,
            animated: true
        ) { [weak self] in
            guard let self else { return }
            setDatabase(fileRef, autoOpenWith: context, andThen: .unlock)
        }
    }
}

extension MainCoordinator {
    @objc private func handleShakeGesture() {
        Diag.debug("Device shaken")
        HapticFeedback.play(.deviceShaken)

        let action = Settings.current.shakeGestureAction
        switch action {
        case .nothing:
            break
        case .lockAllDatabases:
            maybeConfirmShakeAction(action) { [weak self] in
                DatabaseSettingsManager.shared.eraseAllMasterKeys()
                self?.lockDatabase()
            }
        case .lockApp:
            guard Settings.current.isAppLockEnabled else {
                Diag.debug("Nothing to lock, ignoring")
                return
            }
            maybeConfirmShakeAction(action) { [weak self] in
                self?.showAppLockScreen()
            }
        case .quitApp:
            maybeConfirmShakeAction(action) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    exit(-1)
                }
            }
        }
    }

    private func maybeConfirmShakeAction(
        _ action: Settings.ShakeGestureAction,
        confirmed: @escaping () -> Void
    ) {
        guard Settings.current.isConfirmShakeGestureAction && !isAppLockVisible else {
            confirmed()
            return
        }

        let alert = UIAlertController
            .make(title: action.shortTitle, message: nil, dismissButtonTitle: LString.actionCancel)
            .addAction(title: LString.actionContinue, style: .default) { _ in
                confirmed()
            }
        Diag.debug("Presenting shake gesture confirmation")
        getPresenterForModals().present(alert, animated: true)
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
        if ProcessInfo.isRunningOnMac { return false }
        return appCoverWindow != nil
    }
    var isAppLockVisible: Bool {
        return appLockWindow != nil || isBiometricAuthShown
    }
    func showAppCover(_ sender: Watchdog) {
        if ProcessInfo.isRunningOnMac { return }
        showAppCoverScreen()
    }
    func hideAppCover(_ sender: Watchdog) {
        if ProcessInfo.isRunningOnMac { return }
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
        guard let appCoverWindow else { return }
        appCoverWindow.isHidden = true
        self.appCoverWindow = nil
        print("App cover hidden")

        mainWindow.makeKeyAndVisible()
        if isAppLockVisible {
            appLockWindow?.makeKeyAndVisible()
        }
    }

    private func canUseBiometrics() -> Bool {
        return Settings.current.isBiometricAppLockEnabled
            && LAContext.isBiometricsAvailable()
            && Keychain.shared.isBiometricAuthPrepared()
    }

    private func showAppLockScreen() {
        guard !isAppLockVisible else { return }
        #if targetEnvironment(macCatalyst)
        removeMacToolbar()
        rootSplitVC.dismiss(animated: false)
        #endif

        let isRepeatedLockOnMac = ProcessInfo.isRunningOnMac && !isInitialAppLock
        isInitialAppLock = false
        if canUseBiometrics() && !isRepeatedLockOnMac {
            performBiometricUnlock()
        } else {
            showPasscodeRequest()
        }
        UIMenu.rebuildMainMenu()
    }

    private func hideAppLockScreen() {
        guard isAppLockVisible else { return }
        #if targetEnvironment(macCatalyst)
        setupMacToolbar()
        #endif

        let window = UIApplication.shared.delegate!.window!
        window?.makeKeyAndVisible()
        appLockWindow?.resignKey()
        appLockWindow?.isHidden = true
        appLockWindow = nil
        UIMenu.rebuildMainMenu()
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
            guard let self else { return }
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
            shouldLock: Settings.current.isLockDatabasesOnTimeout,
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
        switch sender.mode {
        case .verification:
            verifyPasscode(passcode, viewController: sender)
        case .setup, .change:
            setupPasscode(passcode, viewController: sender)
        }
    }

    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {
        assert(canUseBiometrics())
        performBiometricUnlock()
    }

    private func setupPasscode(_ passcode: String, viewController: PasscodeInputVC) {
        Diag.info("Passcode setup successful")
        do {
            try Keychain.shared.setAppPasscode(passcode)
            viewController.dismiss(animated: true)
        } catch {
            Diag.error("Keychain error [message: \(error.localizedDescription)]")
            viewController.showErrorAlert(error, title: LString.titleKeychainError)
        }
    }

    private func verifyPasscode(_ passcode: String, viewController: PasscodeInputVC) {
        do {
            if try Keychain.shared.isAppPasscodeMatch(passcode) { 
                HapticFeedback.play(.appUnlocked)
                watchdog.unlockApp()
                Keychain.shared.prepareBiometricAuth(true)
            } else {
                HapticFeedback.play(.wrongPassword)
                viewController.animateWrongPassccode()
                StoreReviewSuggester.registerEvent(.trouble)
                handleFailedPasscode()
            }
        } catch {
            let alert = UIAlertController.make(
                title: LString.titleKeychainError,
                message: error.localizedDescription)
            viewController.present(alert, animated: true, completion: nil)
        }
    }

    private func handleFailedPasscode() {
        // swiftlint:disable:next trailing_closure
        let isResetting = AppEraser.registerFailedAppPasscodeAttempt(afterReset: {
            exit(0)
        })
        if isResetting {
            return
        }

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
}

extension MainCoordinator: OnboardingCoordinatorDelegate {
    func didPressCreateDatabase(in coordinator: OnboardingCoordinator) {
        coordinator.dismiss { [weak self] in
            guard let self else { return }
            databasePickerCoordinator.startDatabaseCreator(presenter: rootSplitVC)
        }
    }

    func didPressAddExistingDatabase(in coordinator: OnboardingCoordinator) {
        coordinator.dismiss { [weak self] in
            guard let self else { return }
            databasePickerCoordinator.startExternalDatabasePicker(presenter: rootSplitVC)
        }
    }

    func didPressConnectToServer(in coordinator: OnboardingCoordinator) {
        Diag.info("Network access permission implied by user action")
        Settings.current.isNetworkAccessAllowed = true
        coordinator.dismiss { [weak self] in
            guard let self else { return }
            databasePickerCoordinator.startRemoteDatabasePicker(presenter: rootSplitVC)
        }
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
    func didSelectDatabase(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in coordinator: DatabasePickerCoordinator
    ) {
        switch cause {
        case .keyPress:
            setDatabase(fileRef, andThen: .unlock)
        case .touch:
            if rootSplitVC.isCollapsed {
                setDatabase(fileRef, andThen: .unlock)
            } else {
                setDatabase(fileRef, andThen: .doNothing)
            }
        case .app:
            setDatabase(fileRef, andThen: .unlock)
        case nil:
            setDatabase(fileRef, andThen: .doNothing)
        }
    }

    func didPressShowRandomGenerator(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController) {
        showPasswordGenerator(at: popoverAnchor, in: viewController)
    }

    func didPressShowAppSettings(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController) {
        showSettingsScreen(in: viewController)
    }

    func didPressShowDiagnostics(at popoverAnchor: PopoverAnchor?, in viewController: UIViewController) {
        showDiagnostics(in: viewController)
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
            primaryRouter.pop(animated: true) { [weak self] in
                guard let self else { return }
                databasePickerCoordinator.paywalledStartRemoteDatabasePicker(
                    bypassPaywall: true,
                    presenter: self.rootSplitVC
                )
            }
        } else {
            databasePickerCoordinator.paywalledStartRemoteDatabasePicker(
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

        if !rootSplitVC.isCollapsed {
            setDatabase(selectedDatabaseRef, andThen: .doNothing)
            databasePickerCoordinator.becomeFirstResponder()
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

    func didPressReloadDatabase(
        _ databaseFile: DatabaseFile,
        originalRef: URLReference,
        in coordinator: DatabaseViewerCoordinator
    ) {
        reloadDatabase(databaseFile, targetRef: originalRef, from: coordinator)
    }

    func didPressSwitchTo(
        databaseRef: URLReference,
        compositeKey: CompositeKey,
        in coordinator: DatabaseViewerCoordinator
    ) {
        switchToDatabase(databaseRef, key: compositeKey, in: coordinator)
    }
}

extension MainCoordinator {
    private var databaseViewerActionsManager: DatabaseViewerActionsManager {
        databaseViewerCoordinator?.actionsManager ?? DatabaseViewerActionsManager()
    }

    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == UIMenuSystem.main,
              ProcessInfo.isRunningOnMac
        else {
            return
        }

        builder.remove(menu: .file)
        builder.remove(menu: .help)
        builder.remove(menu: .format)
        builder.remove(menu: .openRecent)
        builder.remove(menu: .spelling)
        builder.remove(menu: .spellingOptions)
        builder.remove(menu: .spellingPanel)
        builder.remove(menu: .substitutions)
        builder.remove(menu: .substitutionOptions)
        builder.remove(menu: .transformations)
        builder.remove(menu: .speech)
        builder.remove(menu: .toolbar)
        builder.remove(menu: .sidebar)
        builder.replaceChildren(ofMenu: .edit) { _ -> [UIMenuElement] in
            return []
        }
        if isAppLockVisible {
            builder.remove(menu: .edit)
            builder.remove(menu: .view)
            builder.remove(menu: .window)
            return
        }

        insertDatabaseMenu(to: builder)
        insertAboutAppCommand(to: builder)
        insertPreferencesCommand(to: builder)

        insertToolsMenu(to: builder)
        insertPasswordGeneratorCommand(to: builder)

        databasePickerCoordinator?.buildMenu(with: builder, isDatabaseShown: databaseViewerCoordinator != nil)
        databaseViewerActionsManager.buildMenu(with: builder)
    }

    override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if isAppLockVisible {
            return self
        }

        for coo in childCoordinators {
            if let cooResponder = coo as? UIResponder,
               cooResponder.canPerformAction(action, withSender: sender)
            {
                return cooResponder
            }
        }
        if databaseViewerActionsManager.canPerformAction(action, withSender: sender) {
            return databaseViewerActionsManager
        }

        if canPerformAction(action, withSender: sender) {
            return self
        }
        return nil
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if isAppLockVisible {
            return false
        }
        switch action {
        case #selector(kpmShowAboutScreen),
             #selector(kpmShowSettingsScreen),
             #selector(kpmShowRandomGenerator):
            return true
        case #selector(kpmCreateDatabase),
             #selector(kpmOpenDatabase),
             #selector(kpmConnectToServer):
            return true
        default:
            return false
        }
    }

    private func insertDatabaseMenu(to builder: UIMenuBuilder) {
        var children = [UIMenuElement]()
        children.append(UIKeyCommand(
            title: LString.titleNewDatabase,
            action: #selector(kpmCreateDatabase),
            hotkey: .createDatabase))
        children.append(UIKeyCommand(
            title: LString.actionOpenDatabase,
            action: #selector(kpmOpenDatabase),
            hotkey: .openDatabase))
        children.append(UIKeyCommand(
            title: LString.actionConnectToServer,
            action: #selector(kpmConnectToServer),
            hotkey: .connectToServer))
        let dbFileMenu = UIMenu(
            title: LString.titleDatabases,
            identifier: .databaseFile,
            children: children)
        builder.insertSibling(dbFileMenu, afterMenu: .application)
    }

    private func insertAboutAppCommand(to builder: UIMenuBuilder) {
        let title = builder.menu(for: .about)?.children.first?.title
            ?? String.localizedStringWithFormat(LString.aboutKeePassiumTitle, AppInfo.name)
        let actionAbout = UICommand(title: title, action: #selector(MainCoordinator.kpmShowAboutScreen))
        let menuAbout = UIMenu(identifier: .about, options: .displayInline, children: [actionAbout])

        builder.replace(menu: .about, with: menuAbout)
    }

    private func insertPreferencesCommand(to builder: UIMenuBuilder) {
        let preferencesCommand = UIKeyCommand(
            title: builder.menu(for: .preferences)?.children.first?.title ?? LString.menuSettingsMacOS,
            action: #selector(kpmShowSettingsScreen),
            hotkey: .appPreferences)
        let preferencesMenu = UIMenu(
            identifier: .preferences,
            options: .displayInline,
            children: [preferencesCommand]
        )
        builder.replace(menu: .preferences, with: preferencesMenu)
    }

    private func insertPasswordGeneratorCommand(to builder: UIMenuBuilder) {
        let passwordGeneratorAction = UIKeyCommand(
            title: LString.PasswordGenerator.titleRandomGenerator,
            action: #selector(kpmShowRandomGenerator),
            hotkey: .passwordGenerator)
        let passGenMenu = UIMenu(
            identifier: .passwordGenerator,
            options: .displayInline,
            children: [passwordGeneratorAction])
        builder.insertChild(passGenMenu, atStartOfMenu: .tools)
    }

    private func insertToolsMenu(to builder: UIMenuBuilder) {
        let toolsMenu = UIMenu(
            title: LString.titleTools,
            identifier: .tools,
            children: []
        )
        builder.insertSibling(toolsMenu, afterMenu: .view)
    }

    @objc func kpmShowAboutScreen() {
        showAboutScreen(at: nil, in: getPresenterForModals())
    }
    @objc func kpmShowSettingsScreen() {
        showSettingsScreen(in: getPresenterForModals())
    }
    @objc func kpmShowRandomGenerator() {
        showPasswordGenerator(at: nil, in: getPresenterForModals())
    }

    @objc func kpmCreateDatabase() {
        createDatabase()
    }
    @objc func kpmOpenDatabase() {
        openDatabase()
    }
    @objc func kpmConnectToServer() {
        connectToServer()
    }
}
