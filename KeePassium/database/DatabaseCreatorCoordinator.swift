//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol DatabaseCreatorCoordinatorDelegate: class {
    func didCreateDatabase(
        in databaseCreatorCoordinator: DatabaseCreatorCoordinator,
        database urlRef: URLReference)
}

class DatabaseCreatorCoordinator: NSObject, Coordinator {
    var childCoordinators = [Coordinator]()
    var dismissHandler: CoordinatorDismissHandler?

    weak var delegate: DatabaseCreatorCoordinatorDelegate?

    private let router: NavigationRouter
    private let databaseCreatorVC: DatabaseCreatorVC
    private var isPasswordResetWarningShown = false
    
    init(router: NavigationRouter) {
        self.router = router
        databaseCreatorVC = DatabaseCreatorVC.create()
        super.init()

        databaseCreatorVC.delegate = self
    }
    
    deinit {
        assert(childCoordinators.isEmpty)
        removeAllChildCoordinators()
    }
    
    func start() {
        if router.navigationController.topViewController == nil {
            let leftButton = UIBarButtonItem(
                barButtonSystemItem: .cancel,
                target: self,
                action: #selector(didPressDismissButton))
            databaseCreatorVC.navigationItem.leftBarButtonItem = leftButton
        }
        router.push(databaseCreatorVC, animated: true, onPop: {
            [weak self] (viewController) in
            guard let self = self else { return }
            self.removeAllChildCoordinators()
            self.dismissHandler?(self)
        })
    }
    
    @objc private func didPressDismissButton() {
        router.dismiss(animated: true)
    }
    

    private func createEmptyLocalFile(fileName: String) throws -> URL {
        let fileManager = FileManager()
        let docDir = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let tmpDir = try fileManager.url(
            for: .itemReplacementDirectory,
            in: .userDomainMask,
            appropriateFor: docDir,
            create: true
        )
        let tmpFileURL = tmpDir
            .appendingPathComponent(fileName, isDirectory: false)
            .appendingPathExtension(FileType.DatabaseExtensions.kdbx)
        
        do {
            try? fileManager.removeItem(at: tmpFileURL)
            try Data().write(to: tmpFileURL, options: []) 
        } catch {
            Diag.error("Failed to create temporary file [message: \(error.localizedDescription)]")
            throw error
        }
        return tmpFileURL
    }
    
    
    private func instantiateDatabase(fileName: String) {
        let tmpFileURL: URL
        do {
            tmpFileURL = try createEmptyLocalFile(fileName: fileName)
        } catch {
            databaseCreatorVC.setError(message: error.localizedDescription, animated: true)
            return
        }
        
        let _challengeHandler = ChallengeResponseManager.makeHandler(for: databaseCreatorVC.yubiKey)
        DatabaseManager.shared.createDatabase(
            databaseURL: tmpFileURL,
            password: databaseCreatorVC.password,
            keyFile: databaseCreatorVC.keyFile,
            challengeHandler: _challengeHandler,
            template: { [weak self] (rootGroup2) in
                rootGroup2.name = fileName // override default "/" with a meaningful name
                self?.addTemplateItems(to: rootGroup2)
            },
            success: { [weak self] in
                self?.startSavingDatabase()
            },
            error: { [weak self] (message) in
                self?.databaseCreatorVC.setError(message: message, animated: true)
            }
        )
    }
    
    private func addTemplateItems(to rootGroup: Group2) {
        let groupGeneral = rootGroup.createGroup()
        groupGeneral.iconID = .folder
        groupGeneral.name = NSLocalizedString(
            "[Database/Create/TemplateGroup/title] General",
            value: "General",
            comment: "Predefined group in a new database")
        
        let groupInternet = rootGroup.createGroup()
        groupInternet.iconID = .globe
        groupInternet.name = NSLocalizedString(
            "[Database/Create/TemplateGroup/title] Internet",
            value: "Internet",
            comment: "Predefined group in a new database")


        let groupEmail = rootGroup.createGroup()
        groupEmail.iconID = .envelopeOpen
        groupEmail.name = NSLocalizedString(
            "[Database/Create/TemplateGroup/title] Email",
            value: "Email",
            comment: "Predefined group in a new database")


        let groupHomebanking = rootGroup.createGroup()
        groupHomebanking.iconID = .currency
        groupHomebanking.name = NSLocalizedString(
            "[Database/Create/TemplateGroup/title] Finance",
            value: "Finance",
            comment: "Predefined group in a new database")

        
        let groupNetwork = rootGroup.createGroup()
        groupNetwork.iconID = .server
        groupNetwork.name = NSLocalizedString(
            "[Database/Create/TemplateGroup/title] Network",
            value: "Network",
            comment: "Predefined group in a new database")


        let groupLinux = rootGroup.createGroup()
        groupLinux.iconID = .apple
        groupLinux.name = NSLocalizedString(
            "[Database/Create/TemplateGroup/title] OS",
            value: "OS",
            comment: "Predefined `Operating system` group in a new database")
        
        let sampleEntry = rootGroup.createEntry()
        sampleEntry.iconID = .key
        sampleEntry.rawTitle = NSLocalizedString(
            "[Database/Create/TemplateEntry/title] Sample Entry",
            value: "Sample Entry",
            comment: "Title for a sample entry")
        sampleEntry.rawUserName = NSLocalizedString(
            "[Database/Create/TemplateEntry/userName] john.smith",
            value: "john.smith",
            comment: "User name for a sample entry. Set it to a typical person name for your language ( https://en.wikipedia.org/wiki/List_of_placeholder_names_by_language).")
        sampleEntry.rawPassword = NSLocalizedString(
            "[Database/Create/TemplateEntry/password] pa$$word",
            value: "pa$$word",
            comment: "Password for a sample entry. Translation is optional.")
        sampleEntry.rawURL = "https://keepassium.com" 
        sampleEntry.rawNotes = NSLocalizedString(
            "[Database/Create/TemplateEntry/notes] You can also store some notes, if you like.",
            value: "You can also store some notes, if you like.",
            comment: "Note for a sample entry")
    }
    
    private func startSavingDatabase() {
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
    
    private func pickTargetLocation(for tmpDatabaseRef: URLReference) {
        tmpDatabaseRef.resolveAsync { [weak self] (result) in
            guard let self = self else { return }
            switch result {
            case .success(let tmpURL):
                let picker = UIDocumentPickerViewController(url: tmpURL, in: .exportToService)
                picker.delegate = self
                picker.modalPresentationStyle = self.router.navigationController.modalPresentationStyle
                self.databaseCreatorVC.present(picker, animated: true, completion: nil)
            case .failure(let error):
                Diag.error("Failed to resolve temporary DB reference [message: \(error.localizedDescription)]")
                self.databaseCreatorVC.setError(message: error.localizedDescription, animated: true)
            }
        }
    }
    
    private func addCreatedDatabase(at finalURL: URL) {
        let fileKeeper = FileKeeper.shared
        fileKeeper.addFile(
            url: finalURL,
            fileType: .database,
            mode: .openInPlace,
            success: { [weak self] (addedRef) in
                guard let self = self else { return }
                self.router.pop(viewController: self.databaseCreatorVC, animated: true)
                self.delegate?.didCreateDatabase(in: self, database: addedRef)
            },
            error: { [weak self] (fileKeeperError) in
                Diag.error("Failed to add created file [mesasge: \(fileKeeperError.localizedDescription)]")
                self?.databaseCreatorVC.setError(
                    message: fileKeeperError.localizedDescription,
                    animated: true
                )
            }
        )
    }
    
    private func showDiagnostics() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: router)
        diagnosticsViewerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        addChildCoordinator(diagnosticsViewerCoordinator)
        diagnosticsViewerCoordinator.start()
    }
    
    
    private func showSavingProgress() {
        databaseCreatorVC.continueButton.isEnabled = false
        router.showProgressView(
            title: LString.databaseStatusSaving,
            allowCancelling: true)
    }
    
    private func hideProgress() {
        databaseCreatorVC.continueButton.isEnabled = true
        router.hideProgressView()
    }
}

extension DatabaseCreatorCoordinator: DatabaseCreatorDelegate {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC) {
        router.pop(viewController: databaseCreatorVC, animated: true)
    }
    
    func didPressContinue(in databaseCreatorVC: DatabaseCreatorVC) {
        if isPasswordResetWarningShown {
            instantiateDatabase(fileName: databaseCreatorVC.databaseFileName)
        } else {
            isPasswordResetWarningShown = true
            let alert = UIAlertController(
                title: LString.titleRememberYourPassword,
                message: LString.warningRememberYourPassword,
                preferredStyle: .alert)
                .addAction(title: LString.actionCancel, style: .cancel, handler: nil)
                .addAction(title: LString.actionContinue, style: .default) {
                    [weak self] action in
                    self?.didPressContinue(in: databaseCreatorVC)
                }
            databaseCreatorVC.present(alert, animated: true, completion: nil)
            return
        }
    }
    
    func didPressErrorDetails(in databaseCreatorVC: DatabaseCreatorVC) {
        showDiagnostics()
    }
    
    func didPressPickKeyFile(in databaseCreatorVC: DatabaseCreatorVC, at popoverAnchor: PopoverAnchor) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let keyFilePickerCoordinator = KeyFilePickerCoordinator(
            router: modalRouter,
            addingMode: .import
        )
        addChildCoordinator(keyFilePickerCoordinator)
        keyFilePickerCoordinator.dismissHandler = { [weak self] coordinator in
            self?.removeChildCoordinator(coordinator)
        }
        keyFilePickerCoordinator.delegate = self
        keyFilePickerCoordinator.start()
        router.present(modalRouter, animated: true, completion: nil)
    }
    
    func didPressPickHardwareKey(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    {
        showHardwareKeyPicker(at: popoverAnchor)
    }
}

extension DatabaseCreatorCoordinator: KeyFilePickerCoordinatorDelegate {
    func didPickKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference?) {
        setKeyFile(keyFile)
    }
    
    func didRemoveOrDeleteKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference) {
        if databaseCreatorVC.keyFile == keyFile {
            setKeyFile(nil)
        }
    }

    func setKeyFile(_ fileRef: URLReference?) {
        databaseCreatorVC.keyFile = fileRef
        databaseCreatorVC.becomeFirstResponder()
    }
}

extension DatabaseCreatorCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        showSavingProgress()
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        router.updateProgressView(with: progress)
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        DatabaseManager.shared.closeDatabase(
            clearStoredKey: true,
            ignoreErrors: false,
            completion: { [weak self] (error) in
                guard let self = self else { return }
                if let error = error {
                    self.hideProgress()
                    self.databaseCreatorVC.showErrorAlert(error)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.pickTargetLocation(for: urlRef)
                    }
                }
            }
        )
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        DatabaseManager.shared.removeObserver(self)
        DatabaseManager.shared.abortDatabaseCreation()
        hideProgress()
    }
    
    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?)
    {
        DatabaseManager.shared.removeObserver(self)
        DatabaseManager.shared.abortDatabaseCreation()
        hideProgress()
        
        guard let localizedError = error as? LocalizedError else {
            databaseCreatorVC.setError(message: error.localizedDescription, animated: true)
            return
        }
        let errorMessageParts = [
            localizedError.localizedDescription,
            localizedError.failureReason,
            localizedError.recoverySuggestion
        ]
        let errorMessage = errorMessageParts.compactMap { $0 }.joined(separator: "\n")
        databaseCreatorVC.setError(message: errorMessage, animated: true)
    }
}

extension DatabaseCreatorCoordinator: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        hideProgress()
        
        router.pop(viewController: databaseCreatorVC, animated: true)
    }
    
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            [weak self] in
            guard let self = self else { return }
            self.hideProgress()
            self.addCreatedDatabase(at: url)
        }
    }
}

extension DatabaseCreatorCoordinator: HardwareKeyPickerDelegate {
    func showHardwareKeyPicker(at popoverAnchor: PopoverAnchor) {
        let hardwareKeyPicker = HardwareKeyPicker.create(delegate: self)
        hardwareKeyPicker.modalPresentationStyle = .popover
        if let popover = hardwareKeyPicker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
            popover.delegate = hardwareKeyPicker.dismissablePopoverDelegate
        }
        hardwareKeyPicker.key = databaseCreatorVC.yubiKey
        databaseCreatorVC.present(hardwareKeyPicker, animated: true, completion: nil)
    }

    func didDismiss(_ picker: HardwareKeyPicker) {
    }
    
    func didSelectKey(yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        setYubiKey(yubiKey)
        databaseCreatorVC.becomeFirstResponder()
        databaseCreatorVC.setError(message: nil, animated: false)
    }
    
    func setYubiKey(_ yubiKey: YubiKey?) {
        databaseCreatorVC.yubiKey = yubiKey
        if let _yubiKey = yubiKey {
            Diag.info("Hardware key selected [key: \(_yubiKey)]")
        } else {
            Diag.info("No hardware key selected")
        }
    }
}
