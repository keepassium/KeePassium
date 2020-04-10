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

    unowned var rootController: CredentialProviderViewController
    var pageController: UIPageViewController
    var navigationController: UINavigationController
    
    var serviceIdentifiers = [ASCredentialServiceIdentifier]()
    fileprivate var isLoadingUsingStoredDatabaseKey = false
    
    fileprivate weak var addDatabasePicker: UIDocumentPickerViewController?
    fileprivate weak var addKeyFilePicker: UIDocumentPickerViewController?
    
    fileprivate var watchdog: Watchdog
    fileprivate var passcodeInputController: PasscodeInputVC?
    fileprivate var isBiometricAuthShown = false
    fileprivate var isPasscodeInputShown = false
    
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

        PremiumManager.shared.usageMonitor.startInterval()

        rootController.present(pageController, animated: false, completion: nil)
        startMainFlow()
    }

    fileprivate func startMainFlow() {
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
        
        let passwordCredential = ASPasswordCredential(user: entry.userName, password: entry.password)
        rootController.extensionContext.completeRequest(
            withSelectedCredential: passwordCredential,
            completionHandler: nil)
        Settings.current.isAutoFillFinishedOK = true
        cleanup()
    }
    
    private func refreshFileList() {
        guard let topVC = navigationController.topViewController else { return }
        (topVC as? DatabaseChooserVC)?.refresh()
        (topVC as? KeyFileChooserVC)?.refresh()
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
        yubiKey: YubiKey?)
    {
        Settings.current.isAutoFillFinishedOK = false
        
        compositeKey.challengeHandler = (yubiKey != nil) ? challengeHandler : nil
        isLoadingUsingStoredDatabaseKey = true
        DatabaseManager.shared.startLoadingDatabase(
            database: database,
            compositeKey: compositeKey
        )
    }
    
    
    func showCrashReport() {
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
        DatabaseSettingsManager.shared.removeSettings(for: urlRef)
        refreshFileList()
    }
    
    func deleteDatabase(_ urlRef: URLReference) {
        DatabaseSettingsManager.shared.removeSettings(for: urlRef)
        do {
            try FileKeeper.shared.deleteFile(urlRef, fileType: .database, ignoreErrors: false)
        } catch {
            Diag.error("Failed to delete database file [message: \(error.localizedDescription)]")
            let alert = UIAlertController.make(
                title: NSLocalizedString(
                    "[Database/Delete] Failed to delete database file",
                    value: "Failed to delete database file",
                    comment: "Title of an error message"),
                message: error.localizedDescription,
                cancelButtonTitle: LString.actionDismiss)
            navigationController.present(alert, animated: true, completion: nil)
        }
        refreshFileList()
    }

    func showDatabaseFileInfo(fileRef: URLReference) {
        let databaseInfoVC = FileInfoVC.make(urlRef: fileRef, at: nil)
        navigationController.pushViewController(databaseInfoVC, animated: true)
    }

    func showDatabaseUnlocker(database: URLReference, animated: Bool, completion: (()->Void)?) {
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: database)
        let storedDatabaseKey = dbSettings?.masterKey
        
        let vc = DatabaseUnlockerVC.instantiateFromStoryboard()
        vc.delegate = self
        vc.coordinator = self
        vc.databaseRef = database
        vc.shouldAutofocus = (storedDatabaseKey == nil)
        navigationController.pushViewController(vc, animated: animated)
        completion?()
        if let storedDatabaseKey = storedDatabaseKey {
            tryToUnlockDatabase(
                database: database,
                compositeKey: storedDatabaseKey,
                yubiKey: dbSettings?.associatedYubiKey
            )
        }
    }
    
    func addKeyFile(popoverAnchor: PopoverAnchor) {
        let picker = UIDocumentPickerViewController(documentTypes: FileType.keyFileUTIs, in: .open)
        picker.delegate = self
        if let popover = picker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
        }
        navigationController.topViewController?.present(picker, animated: true, completion: nil)
        
        addKeyFilePicker = picker
    }
    
    func removeKeyFile(_ urlRef: URLReference) {
        FileKeeper.shared.removeExternalReference(urlRef, fileType: .keyFile)
        refreshFileList()
    }
    
    func selectKeyFile() {
        let vc = KeyFileChooserVC.instantiateFromStoryboard()
        vc.delegate = self
        navigationController.pushViewController(vc, animated: true)
    }
    
    func showDiagnostics() {
        let vc = DiagnosticsViewerVC.instantiateFromStoryboard()
        vc.delegate = self
        navigationController.pushViewController(vc, animated: true)
    }
    
    func showDatabaseContent(database: Database, databaseRef: URLReference) {
        let fileName = databaseRef.info.fileName
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
        guard openURL(AppGroup.upgradeToPremiumURL) else {
            Diag.warning("Failed to open main app")
            showManualUpgradeMessage()
            return
        }
    }

    @objc func openURL(_ url: URL) -> Bool {
        var responder: UIResponder? = rootController
        while responder != nil {
            guard let application = responder as? UIApplication else {
                responder = responder?.next
                continue
            }
            let result = application.perform(#selector(openURL(_:)), with: url)
            return result != nil
        }
        return false
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
            cancelButtonTitle: LString.actionOK)
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
        let nonBackupDatabaseRefs = sender.databaseRefs.filter { $0.location != .internalBackup }
        if nonBackupDatabaseRefs.count > 0 {
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
        showDatabaseFileInfo(fileRef: urlRef)
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
    
    func didPressSelectHardwareKey(in databaseUnlocker: DatabaseUnlockerVC, at popoverAnchor: PopoverAnchor) {
        let hardwareKeyPicker = HardwareKeyPicker.create(delegate: self)
        hardwareKeyPicker.modalPresentationStyle = .popover
        if let popover = hardwareKeyPicker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
            popover.delegate = hardwareKeyPicker.dismissablePopoverDelegate
        }
        hardwareKeyPicker.key = databaseUnlocker.yubiKey
        navigationController.present(hardwareKeyPicker, animated: true, completion: nil)
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

extension MainCoordinator: KeyFileChooserDelegate {
    
    func didSelectFile(in keyFileChooser: KeyFileChooserVC, urlRef: URLReference?) {
        watchdog.restart()
        navigationController.popViewController(animated: true) 
        if let databaseUnlockerVC = navigationController.topViewController as? DatabaseUnlockerVC {
            databaseUnlockerVC.setKeyFile(urlRef: urlRef)
        } else {
            assertionFailure()
        }
    }
    
    func didPressAddKeyFile(in keyFileChooser: KeyFileChooserVC, popoverAnchor: PopoverAnchor) {
        addKeyFile(popoverAnchor: popoverAnchor)
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
        databaseUnlockerVC.hideProgressOverlay()
        databaseUnlockerVC.showMasterKeyInvalid(message: message)
    }
    
    func databaseManager(database urlRef: URLReference, loadingError message: String, reason: String?) {
        guard let databaseUnlockerVC = navigationController.topViewController
            as? DatabaseUnlockerVC else { return }
        Settings.current.isAutoFillFinishedOK = true
        databaseUnlockerVC.hideProgressOverlay()
        
        if urlRef.info.hasPermissionError257 {
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
        } else if controller === addKeyFilePicker {
            addKeyFileURL(url)
        }
    }
    
    private func addDatabaseURL(_ url: URL) {
        guard FileType.isDatabaseFile(url: url) else {
            let fileName = url.lastPathComponent
            let errorAlert = UIAlertController.make(
                title: LString.titleWarning,
                message: String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Database/Add] Selected file \"%@\" does not look like a database.",
                        value: "Selected file \"%@\" does not look like a database.",
                        comment: "Warning when trying to add a random file as a database. [fileName: String]"),
                    fileName),
                cancelButtonTitle: LString.actionOK)
            navigationController.present(errorAlert, animated: true, completion: nil)
            return
        }
        
        FileKeeper.shared.prepareToAddFile(url: url, mode: .openInPlace)
        FileKeeper.shared.processPendingOperations(
            success: { (urlRef) in
                self.navigationController.popToRootViewController(animated: true)
                self.refreshFileList()
            },
            error: { (error) in
                let alert = UIAlertController.make(
                    title: LString.titleError,
                    message: error.localizedDescription)
                self.navigationController.present(alert, animated: true, completion: nil)
            }
        )
    }

    private func addKeyFileURL(_ url: URL) {
        if FileType.isDatabaseFile(url: url) {
            let errorAlert = UIAlertController.make(
                title: LString.titleWarning,
                message: LString.dontUseDatabaseAsKeyFile,
                cancelButtonTitle: LString.actionOK)
            navigationController.present(errorAlert, animated: true, completion: nil)
            return
        }

        FileKeeper.shared.prepareToAddFile(url: url, mode: .openInPlace)
        FileKeeper.shared.processPendingOperations(
            success: { [weak self] (urlRef) in
                self?.refreshFileList()
            },
            error: { [weak self] (error) in
                let alert = UIAlertController.make(
                    title: LString.titleError,
                    message: error.localizedDescription)
                self?.navigationController.present(alert, animated: true, completion: nil)
            }
        )
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
            || topVC is KeyFileChooserVC
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
            completion: { [weak self] (errorMessage) in
                if let errorMessage = errorMessage {
                    let errorAlert = UIAlertController.make(
                        title: LString.titleError,
                        message: errorMessage,
                        cancelButtonTitle: LString.actionDismiss)
                    self?.navigationController.present(errorAlert, animated: true, completion: nil)
                } else {
                    self?.navigationController.popToRootViewController(animated: true)
                }
            }
        )
    }
}

extension MainCoordinator: DiagnosticsViewerDelegate {
    func didPressCopy(in diagnosticsViewer: DiagnosticsViewerVC, text: String) {
        Clipboard.general.insert(text: text, timeout: nil)
        let infoAlert = UIAlertController.make(
            title: nil,
            message: NSLocalizedString(
                "[Diagnostics] Diagnostic log has been copied to clipboard.",
                value: "Diagnostic log has been copied to clipboard.",
                comment: "Notification/confirmation message"),
            cancelButtonTitle: LString.actionOK)
        navigationController.present(infoAlert, animated: true, completion: nil)
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
        passcodeInputVC.shouldActivateKeyboard = !shouldUseBiometrics
        
        pageController.setViewControllers(
            [passcodeInputVC],
            direction: .reverse,
            animated: true,
            completion: { [weak self] (finished) in
                self?.showBiometricAuth()
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
    
    private func showBiometricAuth() {
        guard isBiometricAuthAvailable() else {
            isBiometricAuthShown = false
            return
        }

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
                    self?.passcodeInputController?.becomeFirstResponder()
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
            let alert = UIAlertController.make(
                title: LString.titleKeychainError,
                message: error.localizedDescription)
            sender.present(alert, animated: true, completion: nil)
        }
    }
    
    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {
        showBiometricAuth()
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
}
