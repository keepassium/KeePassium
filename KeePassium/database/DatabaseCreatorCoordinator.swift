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
    func didPressCancel(in databaseCreatorCoordinator: DatabaseCreatorCoordinator)
}

class DatabaseCreatorCoordinator: NSObject {
    weak var delegate: DatabaseCreatorCoordinatorDelegate?
    
    private let navigationController: UINavigationController
    private weak var initialTopController: UIViewController?
    private let databaseCreatorVC: DatabaseCreatorVC
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.initialTopController = navigationController.topViewController
        
        databaseCreatorVC = DatabaseCreatorVC.create()
        super.init()

        databaseCreatorVC.delegate = self
    }
    
    func start() {
        navigationController.pushViewController(databaseCreatorVC, animated: true)
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
        sampleEntry.title = NSLocalizedString(
            "[Database/Create/TemplateEntry/title] Sample Entry",
            value: "Sample Entry",
            comment: "Title for a sample entry")
        sampleEntry.userName = NSLocalizedString(
            "[Database/Create/TemplateEntry/userName] john.smith",
            value: "john.smith",
            comment: "User name for a sample entry. Set it to a typical person name for your language ( https://en.wikipedia.org/wiki/List_of_placeholder_names_by_language).")
        sampleEntry.password = NSLocalizedString(
            "[Database/Create/TemplateEntry/password] pa$$word",
            value: "pa$$word",
            comment: "Password for a sample entry. Translation is optional.")
        sampleEntry.url = "https://keepassium.com" 
        sampleEntry.notes = NSLocalizedString(
            "[Database/Create/TemplateEntry/notes] You can also store some notes, if you like.",
            value: "You can also store some notes, if you like.",
            comment: "Note for a sample entry")
    }
    
    private func startSavingDatabase() {
        DatabaseManager.shared.addObserver(self)
        DatabaseManager.shared.startSavingDatabase()
    }
    
    private func pickTargetLocation(for tmpDatabaseRef: URLReference) {
        do{
            let tmpUrl = try tmpDatabaseRef.resolve() 
            let picker = UIDocumentPickerViewController(url: tmpUrl, in: .exportToService)
            picker.modalPresentationStyle = navigationController.modalPresentationStyle
            picker.delegate = self
            databaseCreatorVC.present(picker, animated: true, completion: nil)
        } catch {
            Diag.error("Failed to resolve temporary DB reference [message: \(error.localizedDescription)]")
            databaseCreatorVC.setError(message: error.localizedDescription, animated: true)
        }
    }
    
    private func addCreatedDatabase(at finalURL: URL) {
        let fileKeeper = FileKeeper.shared
        fileKeeper.addFile(
            url: finalURL,
            mode: .openInPlace,
            success: { [weak self] (addedRef) in
                guard let _self = self else { return }
                if let initialTopController = _self.initialTopController {
                    _self.navigationController.popToViewController(initialTopController, animated: true)
                }
                _self.delegate?.didCreateDatabase(in: _self, database: addedRef)
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
}

extension DatabaseCreatorCoordinator: DatabaseCreatorDelegate {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC) {
        if let initialTopController = self.initialTopController {
            navigationController.popToViewController(initialTopController, animated: true)
        }
        delegate?.didPressCancel(in: self)
    }
    
    func didPressContinue(in databaseCreatorVC: DatabaseCreatorVC) {
        instantiateDatabase(fileName: databaseCreatorVC.databaseFileName)
    }
    
    func didPressPickKeyFile(in databaseCreatorVC: DatabaseCreatorVC, popoverSource: UIView) {
        let keyFileChooser = ChooseKeyFileVC.make(popoverSourceView: popoverSource, delegate: self)
        navigationController.present(keyFileChooser, animated: true, completion: nil)
    }
    
    func didPressPickHardwareKey(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    {
        showHardwareKeyPicker(at: popoverAnchor)
    }
}

extension DatabaseCreatorCoordinator: KeyFileChooserDelegate {
    func onKeyFileSelected(urlRef: URLReference?) {
        databaseCreatorVC.keyFile = urlRef
        databaseCreatorVC.becomeFirstResponder()
    }
}

extension DatabaseCreatorCoordinator: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        databaseCreatorVC.showProgressView(
            title: LString.databaseStatusSaving,
            allowCancelling: true)
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        databaseCreatorVC.updateProgressView(with: progress)
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        DatabaseManager.shared.closeDatabase(
            clearStoredKey: true,
            ignoreErrors: false,
            completion: { [weak self] (errorMessage) in
                if let errorMessage = errorMessage {
                    self?.databaseCreatorVC.hideProgressView()
                    let errorAlert = UIAlertController.make(
                        title: LString.titleError,
                        message: errorMessage,
                        cancelButtonTitle: LString.actionDismiss)
                    self?.navigationController.present(errorAlert, animated: true, completion: nil)
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
        self.databaseCreatorVC.hideProgressView()
    }
    
    func databaseManager(database urlRef: URLReference, savingError message: String, reason: String?) {
        DatabaseManager.shared.removeObserver(self)
        DatabaseManager.shared.abortDatabaseCreation()
        databaseCreatorVC.hideProgressView()
        if let reason = reason {
            databaseCreatorVC.setError(message: "\(message)\n\(reason)", animated: true)
        } else {
            databaseCreatorVC.setError(message: message, animated: true)
        }
    }
}

extension DatabaseCreatorCoordinator: UIDocumentPickerDelegate {
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        databaseCreatorVC.hideProgressView()
        
        if let initialTopController = self.initialTopController {
            self.navigationController.popToViewController(initialTopController, animated: false)
        }
        self.delegate?.didPressCancel(in: self)
    }
    
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { 
            self.databaseCreatorVC.hideProgressView()
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
