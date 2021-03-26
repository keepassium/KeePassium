//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib
import AuthenticationServices
import LocalAuthentication

class MainCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler? 
    
    unowned var rootController: CredentialProviderViewController
    var pageController: UIPageViewController
    var navigationController: UINavigationController
    
    var serviceIdentifiers = [ASCredentialServiceIdentifier]()
    fileprivate var isLoadingUsingStoredDatabaseKey = false
    
    fileprivate weak var databaseUnlockerVC: DatabaseUnlockerVC?
    fileprivate weak var addDatabasePicker: UIDocumentPickerViewController?
    
    fileprivate var watchdog: Watchdog
    fileprivate var passcodeInputController: PasscodeInputVC?
    fileprivate var isBiometricAuthShown = false
    fileprivate var isPasscodeInputShown = false
    fileprivate var canUseFinalKey = true
    
    init(rootController: CredentialProviderViewController) {
        self.rootController = rootController
        pageController = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [:]
        )
        if #available(iOS 13, *) {
            pageController.modalPresentationStyle = .fullScreen
        }
        navigationController = LongPressAwareNavigationController()
        navigationController.view.backgroundColor = .clear
        watchdog = Watchdog.shared 
        super.init()

        #if PREPAID_VERSION
        BusinessModel.type = .prepaid
        #else
        BusinessModel.type = .freemium
        #endif
        SettingsMigrator.processAppLaunch(with: Settings.current)
        SystemIssueDetector.scanForIssues()
        Diag.info(AppInfo.description)

        navigationController.delegate = self
        watchdog.delegate = self
    }
    
    deinit {
        DatabaseManager.shared.removeObserver(self)
    }

    func start() {
        DatabaseManager.shared.closeDatabase(
            clearStoredKey: false,
            ignoreErrors: true,
            completion: nil)
        
        DatabaseManager.shared.addObserver(self)
        
        watchdog.didBecomeActive()
        if !isAppLockVisible {
            pageController.setViewControllers(
                [navigationController],
                direction: .forward,
                animated: true,
                completion: nil)
        }

        let premiumManager = PremiumManager.shared
        premiumManager.reloadReceipt()
        premiumManager.usageMonitor.startInterval()

        let pageView = pageController.view!
        rootController.view.addSubview(pageView)
        pageView.translatesAutoresizingMaskIntoConstraints = false
        rootController.view.addConstraints([
            pageView.leadingAnchor.constraint(equalTo: pageView.superview!.leadingAnchor),
            pageView.trailingAnchor.constraint(equalTo: pageView.superview!.trailingAnchor),
            pageView.topAnchor.constraint(equalTo: pageView.superview!.topAnchor),
            pageView.bottomAnchor.constraint(equalTo: pageView.superview!.bottomAnchor)
        ])
        rootController.addChild(pageController)
        pageController.didMove(toParent: rootController)

        startMainFlow()
    }

    fileprivate func startMainFlow() {
        StoreReviewSuggester.registerEvent(.sessionStart)
        
        let isPreviouslyCrashed = !Settings.current.isAutoFillFinishedOK
        if isPreviouslyCrashed {
            showCrashReport()
        } else {
            showDatabaseChooser(canPickDefaultDatabase: !isPreviouslyCrashed, completion: nil)
        }
    }
    
    public func didReceiveMemoryWarning() {
        Diag.error("Received a memory warning")
        DatabaseManager.shared.progress.cancel(reason: .lowMemoryWarning)
    }
    
    func cleanup() {
        PremiumManager.shared.usageMonitor.stopInterval()
        DatabaseManager.shared.removeObserver(self)
        DatabaseManager.shared.closeDatabase(
            clearStoredKey: false,
            ignoreErrors: true,
            completion: nil)
    }

    func dismissAndQuit() {
        rootController.dismiss()
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }

    func returnCredentials(entry: Entry) {
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
        rootController.extensionContext.completeRequest(withSelectedCredential: passwordCredential) {
            (expired) in
            HapticFeedback.play(.credentialsPasted)
        }
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }
    
    private func refreshFileList() {
        guard let topVC = navigationController.topViewController else { return }
        (topVC as? DatabaseChooserVC)?.refresh()
    }
    
    
    private func challengeHandler(
        challenge: SecureByteArray,
        responseHandler: @escaping ResponseHandler)
    {
        Diag.warning("YubiKey is not available in AutoFill")
        responseHandler(SecureByteArray(), .notAvailableInAutoFill)
    }
    
    private func tryToUnlockDatabase(
        database: URLReference,
        password: String,
        keyFile: URLReference?,
        yubiKey: YubiKey?)
    {
        Settings.current.isAutoFillFinishedOK = false
        
        let _challengeHandler = (yubiKey != nil) ? challengeHandler : nil
        isLoadingUsingStoredDatabaseKey = false
        canUseFinalKey = false 
        DatabaseManager.shared.startLoadingDatabase(
            database: database,
            password: password,
            keyFile: keyFile,
            challengeHandler: _challengeHandler
        )
    }
    
    private func tryToUnlockDatabase(
        database: URLReference,
        compositeKey: CompositeKey,
        yubiKey: YubiKey?,
        canUseFinalKey: Bool)
    {
        Settings.current.isAutoFillFinishedOK = false
        
        compositeKey.challengeHandler = (yubiKey != nil) ? challengeHandler : nil
        isLoadingUsingStoredDatabaseKey = true
        self.canUseFinalKey = canUseFinalKey
        DatabaseManager.shared.startLoadingDatabase(
            database: database,
            compositeKey: compositeKey,
            canUseFinalKey: canUseFinalKey
        )
    }
    
    
    func showCrashReport() {
        StoreReviewSuggester.registerEvent(.trouble)
        
        let vc = CrashReportVC.instantiateFromStoryboard()
        vc.delegate = self
        navigationController.pushViewController(vc, animated: false)
    }

    func showDatabaseChooser(canPickDefaultDatabase: Bool, completion: (()->Void)?) {
        let databaseChooserVC = DatabaseChooserVC.instantiateFromStoryboard()
        databaseChooserVC.delegate = self
        navigationController.pushViewController(databaseChooserVC, animated: false)
        
        let allRefs = FileKeeper.shared.getAllReferences(fileType: .database, includeBackup: false)
        if allRefs.isEmpty {
            let firstSetupVC = FirstSetupVC.make(delegate: self)
            firstSetupVC.navigationItem.hidesBackButton = true
            navigationController.pushViewController(firstSetupVC, animated: false)
            completion?()
        } else if allRefs.count == 1 && canPickDefaultDatabase {
            let defaultDatabaseRef = allRefs.first!
            showDatabaseUnlocker(
                database: defaultDatabaseRef,
                animated: false,
                completion: completion)
        } else {
            completion?()
        }
    }
    
    func addDatabase(popoverAnchor: PopoverAnchor) {
        let picker = UIDocumentPickerViewController(
            documentTypes: FileType.databaseUTIs,
            in: .open)
        picker.delegate = self
        if let popover = picker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
        }
        navigationController.topViewController?.present(picker, animated: true, completion: nil)
        
        addDatabasePicker = picker
    }
    
    func removeDatabase(_ urlRef: URLReference) {
        FileKeeper.shared.removeExternalReference(urlRef, fileType: .database)
        DatabaseSettingsManager.shared.removeSettings(for: urlRef, onlyIfUnused: true)
        refreshFileList()
    }
    
    func deleteDatabase(_ urlRef: URLReference) {
        do {
            try FileKeeper.shared.deleteFile(urlRef, fileType: .database, ignoreErrors: false)
        } catch {
            Diag.error("Failed to delete database file [message: \(error.localizedDescription)]")
            navigationController.showErrorAlert(
                error,
                title: NSLocalizedString(
                    "[Database/Delete] Failed to delete database file",
                    value: "Failed to delete database file",
                    comment: "Title of an error message"
                )
            )
        }
        DatabaseSettingsManager.shared.removeSettings(for: urlRef, onlyIfUnused: true)
        refreshFileList()
    }

    func showDatabaseFileInfo(in databaseChooser: DatabaseChooserVC, for fileRef: URLReference) {
        let databaseInfoVC = FileInfoVC.make(urlRef: fileRef, fileType: .database, at: nil)
        databaseInfoVC.canExport = true
        databaseInfoVC.didDeleteCallback = { [weak self, weak databaseChooser] in
            databaseChooser?.refresh()
            self?.navigationController.popViewController(animated: true) 
        }
        navigationController.pushViewController(databaseInfoVC, animated: true)
    }

    func showDatabaseUnlocker(database: URLReference, animated: Bool, completion: (()->Void)?) {
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: database)
        let storedDatabaseKey = dbSettings?.masterKey
        
        let vc = DatabaseUnlockerVC.instantiateFromStoryboard()
        vc.delegate = self
        vc.databaseRef = database
        vc.shouldAutofocus = (storedDatabaseKey == nil)
        navigationController.pushViewController(vc, animated: animated)
        databaseUnlockerVC = vc
        completion?()
        if let storedDatabaseKey = storedDatabaseKey {
            tryToUnlockDatabase(
                database: database,
                compositeKey: storedDatabaseKey,
                yubiKey: dbSettings?.associatedYubiKey,
                canUseFinalKey: PremiumManager.shared.isAvailable(feature: .canUseExpressUnlock)
            )
        }
    }
    
    func selectKeyFile(at popoverAnchor: PopoverAnchor) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let keyFilePickerCoordinator = KeyFilePickerCoordinator(
            router: modalRouter,
            addingMode: .openInPlace
        )
        addChildCoordinator(keyFilePickerCoordinator)
        keyFilePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        keyFilePickerCoordinator.delegate = self
        keyFilePickerCoordinator.start()
        navigationController.present(modalRouter, animated: true, completion: nil)
    }
    
    func showDiagnostics() {
        let router = NavigationRouter(navigationController)
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] (coordinator) in
            self?.removeChildCoordinator(coordinator)
        }
        addChildCoordinator(diagnosticsViewerCoordinator)
        diagnosticsViewerCoordinator.start()
    }
    
    func showDatabaseContent(database: Database, databaseRef: URLReference) {
        let fileName = databaseRef.visibleFileName
        let databaseName = URL(string: fileName)?.deletingPathExtension().absoluteString ?? fileName
        
        let entriesVC = EntryFinderVC.instantiateFromStoryboard()
        entriesVC.delegate = self
        entriesVC.database = database
        entriesVC.databaseName = databaseName
        entriesVC.serviceIdentifiers = serviceIdentifiers

        var vcs = navigationController.viewControllers
        vcs[vcs.count - 1] = entriesVC
        navigationController.setViewControllers(vcs, animated: true)
    }
    
    
    func offerPremiumUpgrade(from viewController: UIViewController, for feature: PremiumFeature) {
        let upgradeAlertVC = UIAlertController(
            title: feature.titleName,
            message: feature.upgradeNoticeText,
            preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        let upgradeAction = UIAlertAction( title: LString.actionUpgradeToPremium, style: .default) {
            [weak self] (action) in
            self?.showUpgradeOptions(from: viewController)
        }
        upgradeAlertVC.addAction(upgradeAction)
        upgradeAlertVC.addAction(cancelAction)
        viewController.present(upgradeAlertVC, animated: true, completion: nil)
    }
    
    func showUpgradeOptions(from viewController: UIViewController) {
        let urlOpener = URLOpener(rootController)
        urlOpener.open(url: AppGroup.upgradeToPremiumURL) {
            [self] (success) in
            if !success {
                Diag.warning("Failed to open main app")
                showManualUpgradeMessage()
            }
        }
    }

    func showManualUpgradeMessage() {
        let manualUpgradeAlert = UIAlertController.make(
            title: NSLocalizedString(
                "[AutoFill/Premium/Upgrade/Manual/title] Premium Upgrade",
                value: "Premium Upgrade",
                comment: "Title of a message related to upgrading to the premium version"),
            message: NSLocalizedString(
                "[AutoFill/Premium/Upgrade/Manual/text] To upgrade, please manually open KeePassium from your home screen.",
                value: "To upgrade, please manually open KeePassium from your home screen.",
                comment: "Message shown when AutoFill cannot automatically open the main app for upgrading to a premium version."),
            dismissButtonTitle: LString.actionOK)
        navigationController.present(manualUpgradeAlert, animated: true, completion: nil)
    }
}

extension MainCoordinator: DatabaseChooserDelegate {
    func databaseChooserShouldCancel(_ sender: DatabaseChooserVC) {
        watchdog.restart()
        dismissAndQuit()
    }
    
    func databaseChooserShouldAddDatabase(_ sender: DatabaseChooserVC, popoverAnchor: PopoverAnchor) {
        watchdog.restart()
        let existingNonBackupDatabaseRefs = sender.databaseRefs.filter {
            ($0.location != .internalBackup) && 
                !($0.hasPermissionError257 || $0.hasFileMissingError) 
        }
        if existingNonBackupDatabaseRefs.count > 0 {
            if PremiumManager.shared.isAvailable(feature: .canUseMultipleDatabases) {
                addDatabase(popoverAnchor: popoverAnchor)
            } else {
                offerPremiumUpgrade(from: sender, for: .canUseMultipleDatabases)
            }
        } else {
            addDatabase(popoverAnchor: popoverAnchor)
        }
    }
    
    func databaseChooser(_ sender: DatabaseChooserVC, didSelectDatabase urlRef: URLReference) {
        watchdog.restart()
        showDatabaseUnlocker(database: urlRef, animated: true, completion: nil)
    }
    
    func databaseChooser(_ sender: DatabaseChooserVC, shouldDeleteDatabase urlRef: URLReference) {
        watchdog.restart()
        deleteDatabase(urlRef)
    }
    
    func databaseChooser(_ sender: DatabaseChooserVC, shouldRemoveDatabase urlRef: URLReference) {
        watchdog.restart()
        removeDatabase(urlRef)
    }
    
    func databaseChooser(_ sender: DatabaseChooserVC, shouldShowInfoForDatabase urlRef: URLReference) {
        watchdog.restart()
        showDatabaseFileInfo(in: sender, for: urlRef)
    }
}

extension MainCoordinator: DatabaseUnlockerDelegate {
    func databaseUnlockerShouldUnlock(
        _ sender: DatabaseUnlockerVC,
        database: URLReference,
        password: String,
        keyFile: URLReference?,
        yubiKey: YubiKey?)
    {
        watchdog.restart()
        tryToUnlockDatabase(
            database: database,
            password: password,
            keyFile: keyFile,
            yubiKey: yubiKey)
    }
    
    func didPressSelectHardwareKey(
        in databaseUnlocker: DatabaseUnlockerVC,
        at popoverAnchor: PopoverAnchor)
    {
        let hardwareKeyPicker = HardwareKeyPicker.create(delegate: self)
        hardwareKeyPicker.modalPresentationStyle = .popover
        if let popover = hardwareKeyPicker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
            popover.delegate = hardwareKeyPicker.dismissablePopoverDelegate
        }
        hardwareKeyPicker.key = databaseUnlocker.yubiKey
        navigationController.present(hardwareKeyPicker, animated: true, completion: nil)
    }
    
    func didPressSelectKeyFile(
        in databaseUnlocker: DatabaseUnlockerVC,
        at popoverAnchor: PopoverAnchor)
    {
        selectKeyFile(at: popoverAnchor)
    }
    
    func didPressShowDiagnostics(
        in databaseUnlocker: DatabaseUnlockerVC,
        at popoverAnchor: PopoverAnchor)
    {
        showDiagnostics()
    }

    func didPressNewsItem(in databaseUnlocker: DatabaseUnlockerVC, newsItem: NewsItem) {
        newsItem.show(in: databaseUnlocker)
    }
}

extension MainCoordinator: HardwareKeyPickerDelegate {
    func didDismiss(_ picker: HardwareKeyPicker) {
    }
    func didSelectKey(yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        watchdog.restart()
        if let databaseUnlockerVC = navigationController.topViewController as? DatabaseUnlockerVC {
            databaseUnlockerVC.setYubiKey(yubiKey)
        } else {
            assertionFailure()
        }
    }
}

extension MainCoordinator: KeyFilePickerCoordinatorDelegate {
    func didPickKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference?) {
        watchdog.restart()
        guard let databaseUnlockerVC = databaseUnlockerVC else {
            assertionFailure()
            return
        }
        databaseUnlockerVC.setKeyFile(keyFile)
    }
    
    func didRemoveOrDeleteKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference) {
        watchdog.restart()
        guard let databaseUnlockerVC = databaseUnlockerVC else {
            assertionFailure()
            return
        }
        if databaseUnlockerVC.keyFileRef == keyFile {
            databaseUnlockerVC.setKeyFile(nil)
        }
    }
}

extension MainCoordinator: DatabaseManagerObserver {
    
    func databaseManager(willLoadDatabase urlRef: URLReference) {
        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }
        databaseUnlockerVC.showProgressOverlay(animated: !isLoadingUsingStoredDatabaseKey)
    }

    func databaseManager(progressDidChange progress: ProgressEx) {
        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }
        databaseUnlockerVC.updateProgress(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }
        
        DatabaseSettingsManager.shared.updateSettings(for: urlRef) { (dbSettings) in
            dbSettings.clearMasterKey()
        }
        Settings.current.isAutoFillFinishedOK = true
        databaseUnlockerVC.clearPasswordField()
        databaseUnlockerVC.hideProgressOverlay()
    }
    
    func databaseManager(database urlRef: URLReference, invalidMasterKey message: String) {
        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }

        Settings.current.isAutoFillFinishedOK = true
        if canUseFinalKey,
           let dbSettings = DatabaseSettingsManager.shared.getSettings(for: urlRef),
           let compositeKey = dbSettings.masterKey
        {
            Diag.info("Express unlock failed, retrying with key derivation")
            canUseFinalKey = false
            tryToUnlockDatabase(
                database: urlRef,
                compositeKey: compositeKey,
                yubiKey: dbSettings.associatedYubiKey,
                canUseFinalKey: false
            )
        } else {
            databaseUnlockerVC.hideProgressOverlay()
            databaseUnlockerVC.showMasterKeyInvalid(message: message)
        }
    }
    
    func databaseManager(database urlRef: URLReference, loadingError message: String, reason: String?) {
        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }
        Settings.current.isAutoFillFinishedOK = true
        databaseUnlockerVC.hideProgressOverlay()
        
        if urlRef.hasPermissionError257 || urlRef.hasFileMissingError {
            databaseUnlockerVC.showErrorMessage(
                message,
                reason: reason,
                suggestion: LString.tryToReAddFile)
        } else {
            databaseUnlockerVC.showErrorMessage(message, reason: reason)
        }
    }
    
    func databaseManager(didLoadDatabase urlRef: URLReference, warnings: DatabaseLoadingWarnings) {
        
        
        if Settings.current.isRememberDatabaseKey {
            do {
                try DatabaseManager.shared.rememberDatabaseKey() 
            } catch {
                Diag.warning("Failed to remember database key [message: \(error.localizedDescription)]")
            }
        }
        guard let database = DatabaseManager.shared.database else { fatalError() }

        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }
        databaseUnlockerVC.clearPasswordField()

        Settings.current.isAutoFillFinishedOK = true
        showDatabaseContent(database: database, databaseRef: urlRef)
    }
}

extension MainCoordinator: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        watchdog.restart()
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        watchdog.restart()
        guard let url = urls.first else { return }
        if controller === addDatabasePicker {
            addDatabaseURL(url)
        } else {
            assertionFailure()
        }
    }
    
    private func addDatabaseURL(_ url: URL) {
        FileAddingHelper.ensureDatabaseFile(url: url, parent: navigationController) {
            [weak self] (url) in
            FileKeeper.shared.prepareToAddFile(url: url, fileType: .database, mode: .openInPlace)
            FileKeeper.shared.processPendingOperations(
                success: { [weak self] (urlRef) in
                    guard let self = self else { return }
                    self.navigationController.popToRootViewController(animated: true)
                    self.refreshFileList()
                },
                error: { [weak self] (error) in
                    self?.navigationController.showErrorAlert(error)
                }
            )
        }
    }
}

extension MainCoordinator: LongPressAwareNavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool)
    {
        guard let fromVC = navigationController.transitionCoordinator?.viewController(forKey: .from),
            !navigationController.viewControllers.contains(fromVC) else { return }
        
        if fromVC is EntryFinderVC {
            DatabaseManager.shared.closeDatabase(
                clearStoredKey: false,
                ignoreErrors: true,
                completion: nil) 
        }
    }
    
    func didLongPressLeftSide(in navigationController: LongPressAwareNavigationController) {
        guard let topVC = navigationController.topViewController else { return }
        guard topVC is DatabaseChooserVC
            || topVC is DatabaseUnlockerVC
            || topVC is EntryFinderVC
            || topVC is FirstSetupVC else { return }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(
            title: NSLocalizedString(
                "[Diagnostics] Show Diagnostic Log",
                value: "Show Diagnostic Log",
                comment: "Action/button to show internal diagnostic log"),
            style: .default,
            handler: { [weak self] _ in
                self?.showDiagnostics()
            }
        ))
        actionSheet.addAction(
            UIAlertAction(title: LString.actionCancel, style: .cancel, handler: nil)
        )

        actionSheet.modalPresentationStyle = .popover
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = navigationController.navigationItem.leftBarButtonItem
        }
        topVC.present(actionSheet, animated: true)
    }
}

extension MainCoordinator: EntryFinderDelegate {
    func entryFinder(_ sender: EntryFinderVC, didSelectEntry entry: Entry) {
        entry.touch(.accessed)
        returnCredentials(entry: entry)
    }
    
    func entryFinderShouldLockDatabase(_ sender: EntryFinderVC) {
        DatabaseManager.shared.closeDatabase(
            clearStoredKey: true,
            ignoreErrors: false,
            completion: { [weak self] (error) in
                if let error = error {
                    self?.navigationController.showErrorAlert(error)
                } else {
                    self?.navigationController.popToRootViewController(animated: true)
                }
            }
        )
    }
}

extension MainCoordinator: WatchdogDelegate {
    var isAppLockVisible: Bool {
        return isBiometricAuthShown || isPasscodeInputShown
    }
    
    func showAppLock(_ sender: Watchdog) {
        guard !isAppLockVisible else { return }
        let shouldUseBiometrics = isBiometricAuthAvailable()
        
        let passcodeInputVC = PasscodeInputVC.instantiateFromStoryboard()
        passcodeInputVC.delegate = self
        passcodeInputVC.mode = .verification
        passcodeInputVC.isCancelAllowed = true
        passcodeInputVC.isBiometricsAllowed = shouldUseBiometrics
        passcodeInputVC.modalTransitionStyle = .crossDissolve
        if #available(iOS 14, *) {
            passcodeInputVC.shouldActivateKeyboard = true
        } else {
            passcodeInputVC.shouldActivateKeyboard = !shouldUseBiometrics
        }
        
        pageController.setViewControllers(
            [passcodeInputVC],
            direction: .reverse,
            animated: true,
            completion: { [weak self] (finished) in
                passcodeInputVC.shouldActivateKeyboard = false
                self?.maybeShowBiometricAuth()
            }
        )
        self.passcodeInputController = passcodeInputVC
        isPasscodeInputShown = true
    }
    
    func hideAppLock(_ sender: Watchdog) {
        dismissPasscodeAndContinue()
    }
    
    func watchdogDidCloseDatabase(_ sender: Watchdog) {
        navigationController.popToRootViewController(animated: true)
    }
    
    private func dismissPasscodeAndContinue() {
        pageController.setViewControllers(
            [navigationController],
            direction: .forward,
            animated: true,
            completion: { [weak self] (finished) in
                self?.passcodeInputController = nil
            }
        )
        isPasscodeInputShown = false
        watchdog.restart()
    }
    
    private func isBiometricAuthAvailable() -> Bool {
        guard Settings.current.premiumIsBiometricAppLockEnabled else { return false }
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        return context.canEvaluatePolicy(policy, error: nil)
    }
    
    private func maybeShowBiometricAuth() {
        guard isBiometricAuthAvailable() else {
            isBiometricAuthShown = false
            return
        }
        
        if #available(iOS 14, *) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.actuallyShowBiometrics()
            }
        } else {
            actuallyShowBiometrics()
        }
    }
    
    private func actuallyShowBiometrics() {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        context.localizedFallbackTitle = "" // hide "Enter Password" fallback; nil won't work
        context.localizedCancelTitle = LString.actionUsePasscode

        Diag.debug("Biometric auth: showing request")
        context.evaluatePolicy(policy, localizedReason: LString.titleTouchID) {
            [weak self](authSuccessful, authError) in
            self?.isBiometricAuthShown = false
            if authSuccessful {
                Diag.info("Biometric auth successful")
                DispatchQueue.main.async {
                    [weak self] in
                    self?.watchdog.unlockApp()
                }
            } else {
                Diag.warning("Biometric auth failed [message: \(authError?.localizedDescription ?? "nil")]")
                DispatchQueue.main.async {
                    [weak self] in
                    self?.passcodeInputController?.showKeyboard()
                }
            }
        }
        isBiometricAuthShown = true
    }
}

extension MainCoordinator: PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {
        dismissAndQuit()
    }
    
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
            Diag.error(error.localizedDescription)
            sender.showErrorAlert(error, title: LString.titleKeychainError)
        }
    }
    
    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {
        maybeShowBiometricAuth()
    }
}

extension MainCoordinator: CrashReportDelegate {
    func didPressDismiss(in crashReport: CrashReportVC) {
        Settings.current.isAutoFillFinishedOK = true
        
        navigationController.viewControllers.removeAll()
        showDatabaseChooser(canPickDefaultDatabase: false, completion: nil)
    }
}

extension MainCoordinator: FirstSetupDelegate {
    func didPressCancel(in firstSetup: FirstSetupVC) {
        dismissAndQuit()
    }
    
    func didPressAddDatabase(in firstSetup: FirstSetupVC, at popoverAnchor: PopoverAnchor) {
        addDatabase(popoverAnchor: popoverAnchor)
    }
    
    func didPressSkip(in firstSetup: FirstSetupVC) {
        watchdog.restart()
        navigationController.popToRootViewController(animated: true)
        refreshFileList()
    }
}
