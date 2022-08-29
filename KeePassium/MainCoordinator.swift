//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication

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
    private let mainWindow: UIWindow
    fileprivate var appCoverWindow: UIWindow?
    fileprivate var appLockWindow: UIWindow?
    fileprivate var biometricsBackgroundWindow: UIWindow?
    fileprivate var isBiometricAuthShown = false
    
    fileprivate let biometricAuthReuseDuration = TimeInterval(2.0)
    fileprivate var lastSuccessfulBiometricAuthTime: Date = .distantPast
    
    private var selectedDatabaseRef: URLReference?
    
    private var isInitialDatabase = true
    
    init(window: UIWindow) {
        self.mainWindow = window
        self.rootSplitVC = RootSplitVC()

        let primaryNavVC = RouterNavigationController()
        primaryRouter = NavigationRouter(primaryNavVC)
        
        let placeholderVC = PlaceholderVC.instantiateFromStoryboard()
        let placeholderNavVC = RouterNavigationController(rootViewController: placeholderVC)
        placeholderRouter = NavigationRouter(placeholderNavVC)

        rootSplitVC.viewControllers = [primaryNavVC, placeholderNavVC]

        watchdog = Watchdog.shared
        watchdog.delegate = self
        
        rootSplitVC.delegate = self
        rootSplitVC.maximumPrimaryColumnWidth = 700
        window.rootViewController = rootSplitVC
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

extension MainCoordinator {
    public func processIncomingURL(_ url: URL, openInPlace: Bool) {
        Diag.info("Will process incoming URL [inPlace: \(openInPlace), URL: \(url.redacted)]")
        guard let databaseViewerCoordinator = databaseViewerCoordinator else {
            handleIncomingURL(url, openInPlace: openInPlace)
            return
        }
        databaseViewerCoordinator.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: false,
            completion: { [weak self] in
                self?.handleIncomingURL(url, openInPlace: openInPlace)
            }
        )
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
                case .success(_):
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
    
    private func setDatabase(_ databaseRef: URLReference?) {
        self.selectedDatabaseRef = databaseRef
        guard let databaseRef = databaseRef else {
            showPlaceholder()
            return
        }
        
        let dbUnlocker = showDatabaseUnlocker(databaseRef)
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
        warnings: DatabaseLoadingWarnings
    ) {
        let databaseViewerCoordinator = DatabaseViewerCoordinator(
            splitViewController: rootSplitVC,
            primaryRouter: primaryRouter,
            originalRef: fileRef, 
            databaseFile: databaseFile, 
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
            databasePickerCoordinator.maybeAddExistingDatabase(presenter: rootSplitVC)
            return
        }
        dbViewer.closeDatabase(
            shouldLock: false,
            reason: .appLevelOperation,
            animated: true,
            completion: { [weak self] in
                guard let self = self else { return }
                self.databasePickerCoordinator.maybeAddExistingDatabase(presenter: self.rootSplitVC)
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
        
        let currentScreen =  mainWindow.screen
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
        if canUseBiometrics() && !ProcessInfo.isRunningOnMac{
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
    
    private func showBiometricsBackground()  {
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
            self.databasePickerCoordinator.addExistingDatabase(
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
        if isInitialDatabase && Settings.current.isAutoUnlockStartupDatabase {
            return true
        }
        return rootSplitVC.isCollapsed
    }
    
    func willUnlockDatabase(_ fileRef: URLReference, in coordinator: DatabaseUnlockerCoordinator) {
        databasePickerCoordinator.setEnabled(false)
        isInitialDatabase = false
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
        return DatabaseSettingsManager.shared.getFallbackStrategy(fileRef)
    }
    
    func didUnlockDatabase(
        databaseFile: DatabaseFile,
        at fileRef: URLReference,
        warnings: DatabaseLoadingWarnings,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        databasePickerCoordinator.setEnabled(true)
        showDatabaseViewer(fileRef, databaseFile: databaseFile, warnings: warnings)
    }
    
    func didPressReinstateDatabase(
        _ fileRef: URLReference,
        in coordinator: DatabaseUnlockerCoordinator
    ) {
        if rootSplitVC.isCollapsed {
            primaryRouter.pop(animated: true, completion: { [weak self] in
                guard let self = self else { return }
                self.databasePickerCoordinator.addExistingDatabase(presenter: self.rootSplitVC)
            })
        } else {
            databasePickerCoordinator.addExistingDatabase(presenter: rootSplitVC)
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
}
