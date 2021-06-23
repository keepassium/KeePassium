//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication

final class MainCoordinator: Coordinator {
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

    private let watchdog: Watchdog
    fileprivate var appCoverWindow: UIWindow?
    fileprivate var appLockWindow: UIWindow?
    fileprivate var biometricsBackgroundWindow: UIWindow?
    fileprivate var isBiometricAuthShown = false
    
    fileprivate let biometricAuthReuseDuration = TimeInterval(1.5)
    fileprivate var lastSuccessfulBiometricAuthTime: Date = .distantPast
    
    private var selectedDatabaseRef: URLReference?
    
    init(window: UIWindow) {
        self.rootSplitVC = RootSplitVC()

        let primaryNavVC = UINavigationController()
        let secondaryNavVC = UINavigationController()
        rootSplitVC.viewControllers = [primaryNavVC, secondaryNavVC]
        primaryRouter = NavigationRouter(primaryNavVC)
        
        let placeholderVC = PlaceholderVC.instantiateFromStoryboard()
        let navController = UINavigationController(rootViewController: placeholderVC)
        placeholderRouter = NavigationRouter(navController)
        
        watchdog = Watchdog.shared
        watchdog.delegate = self
        
        rootSplitVC.delegate = self
        window.rootViewController = rootSplitVC
    }
    
    func start() {
        Diag.info(AppInfo.description)
        PremiumManager.shared.startObservingTransactions()
        
        FileKeeper.shared.delegate = self

        showAppCoverScreen()
        
        watchdog.didBecomeActive()
        StoreReviewSuggester.registerEvent(.sessionStart)

        let databasePickerCoordinator = DatabasePickerCoordinator(router: primaryRouter)
        databasePickerCoordinator.delegate = self
        databasePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databasePickerCoordinator.start()
        addChildCoordinator(databasePickerCoordinator)
        
        let startupDatabase = Settings.current.startupDatabase
        databasePickerCoordinator.selectDatabase(startupDatabase, animated: false)
    }
    
    public func processIncomingURL(_ url: URL, openInPlace: Bool) {
        Diag.info("Will process incoming URL [inPlace: \(openInPlace), URL: \(url.redacted)]")
        DatabaseManager.shared.closeDatabase(clearStoredKey: false, ignoreErrors: true) {
            (fileAccessError) in
            if url.scheme != AppGroup.appURLScheme {
                FileKeeper.shared.addFile(
                    url: url,
                    fileType: nil, 
                    mode: openInPlace ? .openInPlace : .import,
                    success: { _ in
                    },
                    error: { [weak self] fileKeeperError in
                        Diag.error(fileKeeperError.localizedDescription)
                        self?.rootSplitVC.showErrorAlert(fileKeeperError)
                    }
                )
            }
        }
    }
}

extension MainCoordinator {
    
    private func setDatabase(_ databaseRef: URLReference?) {
        self.selectedDatabaseRef = databaseRef
        guard let databaseRef = databaseRef else {
            showPlaceholder()
            return
        }
        
        let dbUnlocker = showDatabaseUnlocker(databaseRef)
        dbUnlocker.setDatabase(databaseRef)
    }
    
    private func showPlaceholder() {
        if !rootSplitVC.isCollapsed {
            rootSplitVC.showDetailViewController(placeholderRouter.navigationController, sender: self)
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
        
        databaseUnlockerRouter = NavigationRouter(UINavigationController())
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

        rootSplitVC.showDetailViewController(router.navigationController, sender: self)
        
        return newDBUnlockerCoordinator
    }
    
    
    private func showDatabaseViewer(
        _ fileRef: URLReference,
        database: Database,
        warnings: DatabaseLoadingWarnings
    ) {
        let databaseViewerCoordinator = DatabaseViewerCoordinator(
            splitViewController: rootSplitVC,
            primaryRouter: primaryRouter,
            database: database,
            databaseRef: fileRef,
            loadingWarnings: warnings
        )
        databaseViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        databaseViewerCoordinator.delegate = self
        databaseViewerCoordinator.start()
        addChildCoordinator(databaseViewerCoordinator)

        deallocateDatabaseUnlocker()
    }
    
    private func deallocateDatabaseUnlocker() {
        databaseUnlockerRouter = nil
        childCoordinators.removeAll(where: { $0 is DatabaseUnlockerCoordinator })
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
    
    private func showAppCoverScreen()  {
        guard appCoverWindow == nil else { return }
        
        let _appCoverWindow = UIWindow(frame: UIScreen.main.bounds)
        _appCoverWindow.setScreen(UIScreen.main)
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
    
    private var canUseBiometrics: Bool {
        return isBiometricsAvailable() && Settings.current.premiumIsBiometricAppLockEnabled
    }
    
    private func showAppLockScreen() {
        guard !isAppLockVisible else { return }
        if canUseBiometrics {
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
        passcodeInputVC.isBiometricsAllowed = canUseBiometrics
        
        let _appLockWindow = UIWindow(frame: UIScreen.main.bounds)
        _appLockWindow.setScreen(UIScreen.main)
        _appLockWindow.windowLevel = UIWindow.Level.alert
        UIView.performWithoutAnimation { [weak self] in
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
    
    private func isBiometricsAvailable() -> Bool {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        return context.canEvaluatePolicy(policy, error: nil)
    }
    
    private func performBiometricUnlock() {
        assert(isBiometricsAvailable())
        guard Settings.current.premiumIsBiometricAppLockEnabled else { return }
        guard !isBiometricAuthShown else { return }
        
        let timeSinceLastSuccess = abs(Date.now.timeIntervalSince(lastSuccessfulBiometricAuthTime))
        if timeSinceLastSuccess < biometricAuthReuseDuration {
            print("Skipping repeated biometric prompt")
            watchdog.unlockApp()
            return
        }
        
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.localizedFallbackTitle = "" // hide "Enter (System) Password" fallback; nil won't work
        context.localizedCancelTitle = LString.actionUsePasscode
        print("Showing biometrics request")
        
        showBiometricsBackground()
        lastSuccessfulBiometricAuthTime = .distantPast
        context.evaluatePolicy(policy, localizedReason: LString.titleTouchID) {
            [weak self] (authSuccessful, authError) in
            DispatchQueue.main.async { [weak self] in
                if authSuccessful {
                    self?.lastSuccessfulBiometricAuthTime = Date.now
                    self?.watchdog.unlockApp()
                } else {
                    Diag.warning("TouchID failed [message: \(authError?.localizedDescription ?? "nil")]")
                    self?.lastSuccessfulBiometricAuthTime = .distantPast
                    self?.showPasscodeRequest()
                }
                self?.hideBiometricsBackground()
                self?.isBiometricAuthShown = false
            }
        }
        isBiometricAuthShown = true
    }
    
    private func showBiometricsBackground()  {
        guard biometricsBackgroundWindow == nil else { return }
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.setScreen(UIScreen.main)
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
    
}

extension MainCoordinator: PasscodeInputDelegate {
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String) {
        do {
            if try Keychain.shared.isAppPasscodeMatch(passcode) { 
                HapticFeedback.play(.appUnlocked)
                watchdog.unlockApp()
            } else {
                HapticFeedback.play(.wrongPassword)
                sender.animateWrongPassccode()
                StoreReviewSuggester.registerEvent(.trouble)
                if Settings.current.isLockAllDatabasesOnFailedPasscode {
                    DatabaseSettingsManager.shared.eraseAllMasterKeys()
                    DatabaseManager.shared.closeDatabase(
                        clearStoredKey: true,
                        ignoreErrors: true,
                        completion: nil)
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
        assert(canUseBiometrics)
        performBiometricUnlock()
    }
}

extension MainCoordinator: FileKeeperDelegate {
    func shouldResolveImportConflict(
        target: URL,
        handler: @escaping (FileKeeper.ConflictResolution) -> Void
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let fileName = target.lastPathComponent
            let choiceAlert = UIAlertController(
                title: fileName,
                message: LString.fileAlreadyExists,
                preferredStyle: .alert)
            let actionOverwrite = UIAlertAction(title: LString.actionOverwrite, style: .destructive) {
                (action) in
                handler(.overwrite)
            }
            let actionRename = UIAlertAction(title: LString.actionRename, style: .default) { (action) in
                handler(.rename)
            }
            let actionAbort = UIAlertAction(title: LString.actionCancel, style: .cancel) { (action) in
                handler(.abort)
            }
            choiceAlert.addAction(actionOverwrite)
            choiceAlert.addAction(actionRename)
            choiceAlert.addAction(actionAbort)
            
            let topModalVC = self.rootSplitVC.presentedViewController ?? self.rootSplitVC
            topModalVC.present(choiceAlert, animated: true)
        }
    }
}

extension MainCoordinator: DatabasePickerCoordinatorDelegate {
    func didSelectDatabase(_ fileRef: URLReference?, in coordinator: DatabasePickerCoordinator) {
        setDatabase(fileRef)
    }
    
    func shouldKeepSelection(in coordinator: DatabasePickerCoordinator) -> Bool {
        return !rootSplitVC.isCollapsed
    }
}

extension MainCoordinator: DatabaseUnlockerCoordinatorDelegate {
    func shouldAutoUnlockDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) -> Bool {
        return rootSplitVC.isCollapsed
    }
    
    func willUnlockDatabase(_ fileRef: URLReference, in coordinator: DatabaseUnlockerCoordinator) {
    }
    
    func didNotUnlockDatabase(
        _ fileRef: URLReference,
        with message: String?,
        reason: String?,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
    }
    
    func didUnlockDatabase(
        _ fileRef: URLReference,
        database: Database,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        showDatabaseViewer(fileRef, database: database, warnings: warnings)
    }
}

extension MainCoordinator: DatabaseViewerCoordinatorDelegate {
    func didLeaveDatabase(in coordinator: DatabaseViewerCoordinator) {
        Diag.debug("Did leave database")
        DatabaseManager.shared.closeDatabase(clearStoredKey: false, ignoreErrors: true) {
            [weak self] error in
            guard let self = self else { return }
            if !self.rootSplitVC.isCollapsed {
                self.setDatabase(self.selectedDatabaseRef)
            }
            if let error = error {
                self.rootSplitVC.showErrorAlert(error)
            }
        }
    }
}
