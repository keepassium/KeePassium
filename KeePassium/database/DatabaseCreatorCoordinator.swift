//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol DatabaseCreatorCoordinatorDelegate: AnyObject {
    func didCreateDatabase(
        in databaseCreatorCoordinator: DatabaseCreatorCoordinator,
        database urlRef: URLReference)
}

class DatabaseCreatorCoordinator: BaseCoordinator {
    enum DestinationType {
        case files
        case remoteServer
    }

    weak var delegate: DatabaseCreatorCoordinatorDelegate?

    private let databaseCreatorVC: DatabaseCreatorVC
    private var isPasswordResetWarningShown = false
    private var destination: DestinationType = .files

    var databaseSaver: DatabaseSaver?

    override init(router: NavigationRouter) {
        databaseCreatorVC = DatabaseCreatorVC.create()
        super.init(router: router)
        databaseCreatorVC.delegate = self
    }

    override func start() {
        super.start()
        _pushInitialViewController(databaseCreatorVC, dismissButtonStyle: .cancel, animated: true)
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
            Diag.error("Failed to create temporary database [message: \(error.localizedDescription)]")
            databaseCreatorVC.showErrorMessage(error.localizedDescription, haptics: .error)
            return
        }

        let _challengeHandler = ChallengeResponseManager.makeHandler(
            for: databaseCreatorVC.hardwareKey,
            presenter: _router.navigationController.view
        )
        DatabaseManager.createDatabase(
            databaseURL: tmpFileURL,
            password: databaseCreatorVC.password,
            keyFile: databaseCreatorVC.keyFile,
            challengeHandler: _challengeHandler,
            template: { [weak self] rootGroup2 in
                rootGroup2.name = fileName // override default "/" with a meaningful name
                self?.addTemplateItems(to: rootGroup2)
            },
            completion: { [weak self] result in
                switch result {
                case .success(let databaseFile):
                    self?.saveDatabase(databaseFile)
                case .failure(let errorMessage):
                    Diag.error("Failed to create database [message: \(errorMessage)]")
                    self?.databaseCreatorVC.showErrorMessage(errorMessage, haptics: .error)
                }
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

    private func saveDatabase(_ databaseFile: DatabaseFile) {
        assert(databaseSaver == nil)
        databaseSaver = DatabaseSaver(
            databaseFile: databaseFile,
            skipTasks: [
                .backupOriginal,      
                .updateLatestBackup,  
                .updateQuickAutoFill, 
            ],
            timeoutDuration: FileDataProvider.defaultTimeoutDuration,
            delegate: self
        )
        databaseSaver!.save()
    }

    private func pickTargetLocation(for databaseFile: DatabaseFile) {

        switch destination {
        case .files:
            let tmpDatabaseURL = databaseFile.fileURL
            let picker = UIDocumentPickerViewController(forExporting: [tmpDatabaseURL], asCopy: true)
            picker.delegate = self
            picker.modalPresentationStyle = _router.navigationController.modalPresentationStyle
            databaseCreatorVC.present(picker, animated: true, completion: nil)
        case .remoteServer:
            let fileName = databaseFile.fileURL.lastPathComponent
            let exportCoordinator = RemoteFileExportCoordinator(
                data: databaseFile.data,
                fileName: fileName,
                router: _router
            )
            exportCoordinator.delegate = self
            exportCoordinator.start()
            addChildCoordinator(exportCoordinator, onDismiss: nil)
        }
    }

    private func addCreatedDatabase(at finalURL: URL) {
        let fileKeeper = FileKeeper.shared
        fileKeeper.addFile(url: finalURL, fileType: .database, mode: .openInPlace) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let addedRef):
                DatabaseSettingsManager.shared.removeSettings(for: addedRef, onlyIfUnused: false)

                dismiss()
                delegate?.didCreateDatabase(in: self, database: addedRef)
            case .failure(let fileKeeperError):
                Diag.error("Failed to add created file [mesasge: \(fileKeeperError.localizedDescription)]")
                self.databaseCreatorVC.showErrorMessage(fileKeeperError.localizedDescription, haptics: .error)
            }
        }
    }

    private func showDiagnostics() {
        let diagnosticsViewerCoordinator = DiagnosticsViewerCoordinator(router: _router)
        addChildCoordinator(diagnosticsViewerCoordinator, onDismiss: nil)
        diagnosticsViewerCoordinator.start()
    }


    private func hideProgress() {
        databaseCreatorVC.indicateState(isBusy: false)
        _router.hideProgressView()
    }
}

extension DatabaseCreatorCoordinator: DatabaseCreatorDelegate {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC) {
        dismiss()
    }

    func didPressSaveToFiles(in databaseCreatorVC: DatabaseCreatorVC) {
        createDatabase(
            fileName: databaseCreatorVC.databaseFileName,
            destination: .files,
            presenter: databaseCreatorVC
        )
    }

    func didPressSaveToServer(in databaseCreatorVC: DatabaseCreatorVC) {
        databaseCreatorVC.ensuringNetworkAccessPermitted { [weak self, weak databaseCreatorVC] in
            guard let self, let databaseCreatorVC else { return }
            createDatabase(
                fileName: databaseCreatorVC.databaseFileName,
                destination: .remoteServer,
                presenter: databaseCreatorVC
            )
        }
    }

    private func createDatabase(
        fileName: String,
        destination: DestinationType,
        presenter: UIViewController
    ) {
        self.destination = destination
        if isPasswordResetWarningShown {
            instantiateDatabase(fileName: fileName)
        } else {
            isPasswordResetWarningShown = true
            let alert = UIAlertController(
                title: LString.titleRememberYourPassword,
                message: LString.warningRememberYourPassword,
                preferredStyle: .alert)
            alert.addAction(title: LString.actionCancel, style: .cancel, handler: nil)
            alert.addAction(title: LString.actionContinue, style: .default, preferred: true) {
                [weak self] _ in
                self?.instantiateDatabase(fileName: fileName)
            }
            databaseCreatorVC.present(alert, animated: true, completion: nil)
            return
        }
    }

    func didPressPickKeyFile(in databaseCreatorVC: DatabaseCreatorVC, at popoverAnchor: PopoverAnchor) {
        _router.dismissModals(animated: false, completion: { [weak self] in
            self?.showKeyFilePicker(at: popoverAnchor)
        })
    }

    func didPressPickHardwareKey(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor
    ) {
        _router.dismissModals(animated: false, completion: { [weak self] in
            self?.showHardwareKeyPicker(at: popoverAnchor)
        })
    }

    func shouldDismissPopovers(in databaseCreatorVC: DatabaseCreatorVC) {
        _router.dismissModals(animated: false, completion: nil)
    }
}

extension DatabaseCreatorCoordinator: KeyFilePickerCoordinatorDelegate {
    private func showKeyFilePicker(at popoverAnchor: PopoverAnchor) {
        let isAlreadyShown = childCoordinators.contains(where: { $0 is KeyFilePickerCoordinator })
        guard !isAlreadyShown else {
            assertionFailure()
            Diag.warning("Key file picker is already shown")
            return
        }

        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let keyFilePickerCoordinator = KeyFilePickerCoordinator(router: modalRouter)
        keyFilePickerCoordinator.delegate = self
        keyFilePickerCoordinator.start()
        _router.present(modalRouter, animated: true, completion: nil)

        addChildCoordinator(keyFilePickerCoordinator, onDismiss: nil)
    }

    func didSelectKeyFile(
        _ fileRef: URLReference?,
        cause: FileActivationCause?,
        in coordinator: KeyFilePickerCoordinator
    ) {
        assert(cause != nil, "File selected but not activated?")
        setKeyFile(fileRef)
    }

    func didEliminateKeyFile(_ keyFile: URLReference, in coordinator: KeyFilePickerCoordinator) {
        if databaseCreatorVC.keyFile == keyFile {
            setKeyFile(nil)
        }
    }

    func setKeyFile(_ fileRef: URLReference?) {
        databaseCreatorVC.keyFile = fileRef
        databaseCreatorVC.becomeFirstResponder()
    }
}

extension DatabaseCreatorCoordinator: DatabaseSaverDelegate {
    func databaseSaver(_ databaseSaver: DatabaseSaver, willSave databaseFile: DatabaseFile) {
        databaseCreatorVC.indicateState(isBusy: true)
        _router.showProgressView(
            title: LString.databaseStatusSaving,
            allowCancelling: true,
            animated: true
        )
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didChangeProgress progress: ProgressEx,
        for databaseFile: DatabaseFile
    ) {
        _router.updateProgressView(with: progress)
    }

    func databaseSaverResolveConflict(
        _ databaseSaver: DatabaseSaver,
        local: DatabaseFile,
        remoteURL: URL,
        remoteData: ByteArray,
        completion: @escaping DatabaseSaver.ConflictResolutionHandler
    ) {
        Diag.warning("Sync conflict when creating a new database. Overwriting")
        assertionFailure()
        completion(.overwrite(local.data))
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didCancelSaving databaseFile: DatabaseFile
    ) {
        self.databaseSaver = nil
        _router.hideProgressView(animated: true)
        databaseCreatorVC.indicateState(isBusy: false)
    }

    func databaseSaver(_ databaseSaver: DatabaseSaver, didSave databaseFile: DatabaseFile) {
        self.databaseSaver = nil
        databaseCreatorVC.indicateState(isBusy: false)
        _router.hideProgressView(animated: true)

        pickTargetLocation(for: databaseFile)
    }

    func databaseSaver(
        _ databaseSaver: DatabaseSaver,
        didFailSaving databaseFile: DatabaseFile,
        with error: Error
    ) {
        self.databaseSaver = nil
        _router.hideProgressView(animated: true)
        databaseCreatorVC.indicateState(isBusy: false)

        guard let localizedError = error as? LocalizedError else {
            databaseCreatorVC.showErrorMessage(error.localizedDescription, haptics: .error)
            return
        }

        let errorMessageParts = [
            localizedError.localizedDescription,
            localizedError.failureReason,
            localizedError.recoverySuggestion
        ]
        let errorMessage = errorMessageParts.compactMap { $0 }.joined(separator: "\n")
        databaseCreatorVC.showErrorMessage(errorMessage, haptics: .error)
    }
}

extension DatabaseCreatorCoordinator: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        hideProgress()

        dismiss()
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let url = urls.first else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }
            self.hideProgress()
            self.addCreatedDatabase(at: url)
        }
    }
}

extension DatabaseCreatorCoordinator: RemoteFileExportCoordinatorDelegate {
    func didFinishExport(
        to remoteURL: URL,
        credential: NetworkCredential,
        in coordinator: RemoteFileExportCoordinator
    ) {
        self.hideProgress()
        CredentialManager.shared.store(credential: credential, for: remoteURL)
        self.addCreatedDatabase(at: remoteURL)
    }
}

extension DatabaseCreatorCoordinator: HardwareKeyPickerCoordinatorDelegate {
    func showHardwareKeyPicker(at popoverAnchor: PopoverAnchor) {
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        let hardwareKeyPickerCoordinator = HardwareKeyPickerCoordinator(router: modalRouter)
        hardwareKeyPickerCoordinator.delegate = self
        hardwareKeyPickerCoordinator.setSelectedKey(databaseCreatorVC.hardwareKey)
        hardwareKeyPickerCoordinator.start()
        databaseCreatorVC.present(modalRouter, animated: true, completion: nil)

        addChildCoordinator(hardwareKeyPickerCoordinator, onDismiss: nil)
    }

    func didSelectKey(_ hardwareKey: HardwareKey?, in coordinator: HardwareKeyPickerCoordinator) {
        setHardwareKey(hardwareKey)
        databaseCreatorVC.becomeFirstResponder()
        databaseCreatorVC.hideErrorMessage(animated: false)
    }

    func setHardwareKey(_ hardwareKey: HardwareKey?) {
        databaseCreatorVC.hardwareKey = hardwareKey
        if let hardwareKey {
            Diag.info("Hardware key selected [key: \(hardwareKey)]")
        } else {
            Diag.info("No hardware key selected")
        }
    }
}
