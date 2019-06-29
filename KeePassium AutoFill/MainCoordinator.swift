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
    fileprivate var databaseManagerNotifications: DatabaseManagerNotifications?
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
        navigationController = UINavigationController()
        navigationController.view.backgroundColor = .clear
        watchdog = Watchdog.shared 
        super.init()

        SettingsMigrator.processAppLaunch(with: Settings.current)

        navigationController.delegate = self
        watchdog.delegate = self
    }
    
    func start() {
        DatabaseManager.shared.closeDatabase(clearStoredKey: false)
        
        databaseManagerNotifications = DatabaseManagerNotifications(observer: self)
        databaseManagerNotifications?.startObserving()
        watchdog.didBecomeActive()
        if !isAppLockVisible {
            pageController.setViewControllers(
                [navigationController],
                direction: .forward,
                animated: true,
                completion: nil)
        }
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
        databaseManagerNotifications?.stopObserving()
        DatabaseManager.shared.closeDatabase(clearStoredKey: false)
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
    
    private func tryToUnlockDatabase(
        database: URLReference,
        password: String,
        keyFile: URLReference?)
    {
        Settings.current.isAutoFillFinishedOK = false
        
        isLoadingUsingStoredDatabaseKey = false
        DatabaseManager.shared.startLoadingDatabase(
            database: database,
            password: password,
            keyFile: keyFile)
    }
    
    private func tryToUnlockDatabase(
        database: URLReference,
        compositeKey: SecureByteArray)
    {
        Settings.current.isAutoFillFinishedOK = false
        
        isLoadingUsingStoredDatabaseKey = true
        DatabaseManager.shared.startLoadingDatabase(
            database: database,
            compositeKey: compositeKey)
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
            let firstSetupVC = FirstSetupVC.make(coordinator: self)
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
    
    func addDatabase() {
        let picker = UIDocumentPickerViewController(
            documentTypes: FileType.databaseUTIs,
            in: .open)
        picker.delegate = self
        navigationController.topViewController?.present(picker, animated: true, completion: nil)
        
        addDatabasePicker = picker
    }
    
    func removeDatabase(_ urlRef: URLReference) {
        FileKeeper.shared.removeExternalReference(urlRef, fileType: .database)
        try? Keychain.shared.removeDatabaseKey(databaseRef: urlRef)
        refreshFileList()
    }
    
    func deleteDatabase(_ urlRef: URLReference) {
        try? Keychain.shared.removeDatabaseKey(databaseRef: urlRef)
        do {
            try FileKeeper.shared.deleteFile(urlRef, fileType: .database, ignoreErrors: false)
        } catch {
            Diag.error("Failed to delete database file [message: \(error.localizedDescription)]")
            let alert = UIAlertController.make(
                title: NSLocalizedString("Failed to delete database file", comment: "Error message"),
                message: error.localizedDescription,
                cancelButtonTitle: LString.actionDismiss)
            navigationController.present(alert, animated: true, completion: nil)
        }
        refreshFileList()
    }

    func showDatabaseFileInfo(fileRef: URLReference) {
        let databaseInfoVC = FileInfoVC.make(urlRef: fileRef, popoverSource: nil)
        navigationController.pushViewController(databaseInfoVC, animated: true)
    }

    func showDatabaseUnlocker(database: URLReference, animated: Bool, completion: (()->Void)?) {
        let storedDatabaseKey: SecureByteArray?
        do {
            storedDatabaseKey = try Keychain.shared.getDatabaseKey(databaseRef: database)
        } catch {
            storedDatabaseKey = nil
            Diag.warning("Keychain error [message: \(error.localizedDescription)]")
        }
        
        let vc = DatabaseUnlockerVC.instantiateFromStoryboard()
        vc.delegate = self
        vc.coordinator = self
        vc.databaseRef = database
        vc.shouldAutofocus = (storedDatabaseKey == nil)
        navigationController.pushViewController(vc, animated: animated)
        completion?()
        if let storedDatabaseKey = storedDatabaseKey {
            tryToUnlockDatabase(database: database, compositeKey: storedDatabaseKey)
        }
    }
    
    func addKeyFile() {
        let picker = UIDocumentPickerViewController(documentTypes: FileType.keyFileUTIs, in: .open)
        picker.delegate = self
        navigationController.topViewController?.present(picker, animated: true, completion: nil)
        
        addKeyFilePicker = picker
    }
    
    func removeKeyFile(_ urlRef: URLReference) {
        FileKeeper.shared.removeExternalReference(urlRef, fileType: .keyFile)
        refreshFileList()
    }
    
    func selectKeyFile() {
        let vc = KeyFileChooserVC.instantiateFromStoryboard()
        vc.coordinator = self
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
}

extension MainCoordinator: DatabaseChooserDelegate {
    func databaseChooserShouldCancel(_ sender: DatabaseChooserVC) {
        watchdog.restart()
        dismissAndQuit()
    }
    
    func databaseChooserShouldAddDatabase(_ sender: DatabaseChooserVC) {
        watchdog.restart()
        addDatabase()
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
        keyFile: URLReference?)
    {
        watchdog.restart()
        tryToUnlockDatabase(database: database, password: password, keyFile: keyFile)
    }
}

extension MainCoordinator: KeyFileChooserDelegate {
    
    func keyFileChooser(_ sender: KeyFileChooserVC, didSelectFile urlRef: URLReference?) {
        watchdog.restart()
        navigationController.popViewController(animated: true) 
        if let databaseUnlockerVC = navigationController.topViewController as? DatabaseUnlockerVC {
            databaseUnlockerVC.setKeyFile(urlRef: urlRef)
        } else {
            assertionFailure()
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
        do {
            try Keychain.shared.removeDatabaseKey(databaseRef: urlRef) 
        } catch {
            Diag.warning("Failed to remove database key [message: \(error.localizedDescription)]")
        }
        Settings.current.isAutoFillFinishedOK = true
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

        let errorText = (reason != nil) ? (message + "\n" + reason!) : message
        databaseUnlockerVC.showErrorMessage(text: errorText)
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
                message: NSLocalizedString(
                    "Selected file \"\(fileName)\" does not look like a database.",
                    comment: "Warning when trying to add a file"),
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

extension MainCoordinator: UINavigationControllerDelegate {
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool)
    {
        guard let fromVC = navigationController.transitionCoordinator?.viewController(forKey: .from),
            !navigationController.viewControllers.contains(fromVC) else { return }
        
        if fromVC is EntryFinderVC {
            DatabaseManager.shared.closeDatabase(clearStoredKey: false)
        }
    }
}

extension MainCoordinator: EntryFinderDelegate {
    func entryFinder(_ sender: EntryFinderVC, didSelectEntry entry: Entry) {
        returnCredentials(entry: entry)
    }
    
    func entryFinderShouldLockDatabase(_ sender: EntryFinderVC) {
        DatabaseManager.shared.closeDatabase(clearStoredKey: true)
        navigationController.popToRootViewController(animated: true)
    }
}

extension MainCoordinator: DiagnosticsViewerDelegate {
    func diagnosticsViewer(_ sender: DiagnosticsViewerVC, didCopyContents text: String) {
        let infoAlert = UIAlertController.make(
            title: nil,
            message: NSLocalizedString(
                "Diagnostic log has been copied to clipboard.",
                comment: "[Diagnostics] notification/confirmation message"),
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
        guard Settings.current.isBiometricAppLockEnabled else { return false }
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
        
        Diag.debug("Biometric auth: showing request")
        context.evaluatePolicy(policy, localizedReason: LString.titleTouchID) {
            [weak self](authSuccessful, authError) in
            self?.isBiometricAuthShown = false
            if authSuccessful {
                Diag.info("Biometric auth successful")
                DispatchQueue.main.async {
                    [weak self] in
                    self?.watchdog.unlockApp(fromAnotherWindow: true)
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
                watchdog.unlockApp(fromAnotherWindow: false)
            } else {
                sender.animateWrongPassccode()
                if Settings.current.isLockAllDatabasesOnFailedPasscode {
                    try? Keychain.shared.removeAllDatabaseKeys() 
                    DatabaseManager.shared.closeDatabase(clearStoredKey: true)
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
