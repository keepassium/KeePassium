//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class ChangeMasterKeyVC: UIViewController, DatabaseSaving {
   
    @IBOutlet weak var keyboardAdjView: UIView!
    @IBOutlet weak var databaseNameLabel: UILabel!
    @IBOutlet weak var databaseIcon: UIImageView!
    @IBOutlet weak var passwordField: ValidatingTextField!
    @IBOutlet weak var repeatPasswordField: ValidatingTextField!
    @IBOutlet weak var keyFileField: KeyFileTextField!
    @IBOutlet weak var passwordMismatchImage: UIImageView!
    @IBOutlet weak var keyboardAdjConstraint: KeyboardLayoutConstraint!
    
    private var databaseRef: URLReference!
    private var keyFileRef: URLReference?
    private var yubiKey: YubiKey?
    
    internal var databaseExporterTemporaryURL: TemporaryFileURL?
    
    private var keyFilePickerCoordinator: KeyFilePickerCoordinator?
    
    static func make(dbRef: URLReference) -> UIViewController {
        let vc = ChangeMasterKeyVC.instantiateFromStoryboard()
        vc.databaseRef = dbRef
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .formSheet
        return navVC
    }
    
    deinit {
        assert(keyFilePickerCoordinator == nil)
        keyFilePickerCoordinator = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        databaseNameLabel.text = databaseRef.visibleFileName
        databaseIcon.image = databaseRef.getIcon(fileType: .database)
        
        passwordField.invalidBackgroundColor = nil
        repeatPasswordField.invalidBackgroundColor = nil
        keyFileField.invalidBackgroundColor = nil
        passwordField.delegate = self
        passwordField.validityDelegate = self
        repeatPasswordField.delegate = self
        repeatPasswordField.validityDelegate = self
        keyFileField.delegate = self
        keyFileField.validityDelegate = self
        setupHardwareKeyPicker()
        
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false
        
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateKeyboardLayoutConstraints()
        passwordField.becomeFirstResponder()
        refresh()
    }
    
    func refresh() {
        let allValid = passwordField.isValid && repeatPasswordField.isValid && keyFileField.isValid
        navigationItem.rightBarButtonItem?.isEnabled = allValid
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async { [weak self] in
            self?.updateKeyboardLayoutConstraints()
        }
    }
    
    private func updateKeyboardLayoutConstraints() {
        if let window = view.window {
            let viewTop = view.convert(view.frame.origin, to: window).y
            let viewHeight = view.frame.height
            let windowHeight = window.frame.height
            let viewBottomOffset = windowHeight - (viewTop + viewHeight)
            keyboardAdjConstraint.viewOffset = viewBottomOffset
        }
    }
    
    
    private func setupHardwareKeyPicker() {
        keyFileField.yubikeyHandler = {
            [weak self] (field) in
            guard let self = self else { return }
            let popoverAnchor = PopoverAnchor(
                sourceView: self.keyFileField,
                sourceRect: self.keyFileField.bounds)
            self.showYubiKeyPicker(at: popoverAnchor)
        }
    }
    
    private func showYubiKeyPicker(at popoverAnchor: PopoverAnchor) {
        let hardwareKeyPicker = HardwareKeyPicker.create(delegate: self)
        hardwareKeyPicker.modalPresentationStyle = .popover
        if let popover = hardwareKeyPicker.popoverPresentationController {
            popoverAnchor.apply(to: popover)
            popover.delegate = hardwareKeyPicker.dismissablePopoverDelegate
        }
        hardwareKeyPicker.key = yubiKey
        present(hardwareKeyPicker, animated: true, completion: nil)
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func didPressSaveChanges(_ sender: Any) {
        guard let db = DatabaseManager.shared.database else {
            assertionFailure()
            return
        }
        
        let _challengeHandler = ChallengeResponseManager.makeHandler(for: yubiKey)
        DatabaseManager.createCompositeKey(
            keyHelper: db.keyHelper,
            password: passwordField.text ?? "",
            keyFile: keyFileRef,
            challengeHandler: _challengeHandler,
            success: {
                [weak self] (_ newCompositeKey: CompositeKey) -> Void in
                guard let self = self else { return }
                let dbm = DatabaseManager.shared
                dbm.changeCompositeKey(to: newCompositeKey)
                DatabaseSettingsManager.shared.updateSettings(for: self.databaseRef) {
                    [weak self] (dbSettings) in
                    guard let self = self else { return }
                    dbSettings.maybeSetMasterKey(newCompositeKey)
                    dbSettings.maybeSetAssociatedKeyFile(self.keyFileRef)
                    dbSettings.maybeSetAssociatedYubiKey(self.yubiKey)
                }
                dbm.addObserver(self)
                dbm.startSavingDatabase()
            },
            error: {
                [weak self] (_ errorMessage: String) -> Void in
                Diag.error("Failed to create new composite key [message: \(errorMessage)]")
                self?.showErrorAlert(errorMessage, title: LString.titleError)
            }
        )
    }
    
    func showKeyFilePicker(at popoverAnchor: PopoverAnchor) {
        guard keyFilePickerCoordinator == nil else {
            assertionFailure()
            Diag.warning("Key file picker is already shown")
            return
        }
        
        let modalRouter = NavigationRouter.createModal(style: .popover, at: popoverAnchor)
        keyFilePickerCoordinator = KeyFilePickerCoordinator(router: modalRouter, addingMode: .import)
        keyFilePickerCoordinator!.dismissHandler = { [weak self] coordinator in
            self?.keyFilePickerCoordinator = nil
        }
        keyFilePickerCoordinator!.delegate = self
        keyFilePickerCoordinator!.start()
        present(modalRouter, animated: true, completion: nil)
    }
    
    
    private var progressOverlay: ProgressOverlay?
    fileprivate func showProgressOverlay() {
        progressOverlay = ProgressOverlay.addTo(
            view, title: LString.databaseStatusSaving, animated: true)
        progressOverlay?.isCancellable = true
        
        if #available(iOS 13, *) {
            isModalInPresentation = true
        }
        navigationItem.leftBarButtonItem?.isEnabled = false
        navigationItem.rightBarButtonItem?.isEnabled = false
        navigationItem.hidesBackButton = true
    }
    
    fileprivate func hideProgressOverlay() {
        progressOverlay?.dismiss(animated: true) {
            [weak self] finished in
            guard let self = self else { return }
            self.progressOverlay?.removeFromSuperview()
            self.progressOverlay = nil
        }
        if #available(iOS 13, *) {
            isModalInPresentation = false
        }
        navigationItem.leftBarButtonItem?.isEnabled = true
        navigationItem.rightBarButtonItem?.isEnabled = true
        navigationItem.hidesBackButton = false
    }
}

extension ChangeMasterKeyVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case passwordField:
            repeatPasswordField.becomeFirstResponder()
        case repeatPasswordField:
            if repeatPasswordField.isValid {
                didPressSaveChanges(self)
            } else {
                repeatPasswordField.shake()
                passwordMismatchImage.shake()
            }
        default:
            break
        }
        return true
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField === keyFileField {
            passwordField.becomeFirstResponder()
            let popoverAnchor = PopoverAnchor(sourceView: keyFileField, sourceRect: keyFileField.bounds)
            showKeyFilePicker(at: popoverAnchor)
            return false 
        }
        return true
    }
}

extension ChangeMasterKeyVC: ValidatingTextFieldDelegate {
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        switch sender {
        case passwordField, keyFileField:
            let gotPassword = passwordField.text?.isNotEmpty ?? false
            let gotKeyFile = keyFileRef != nil
            let gotYubiKey = yubiKey != nil
            return gotPassword || gotKeyFile || gotYubiKey
        case repeatPasswordField:
            let isPasswordsMatch = (passwordField.text == repeatPasswordField.text)
            UIView.animate(withDuration: 0.5) {
                self.passwordMismatchImage.alpha = isPasswordsMatch ? 0.0 : 1.0
            }
            return isPasswordsMatch
        default:
            return true
        }
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        if sender === passwordField {
            repeatPasswordField.validate()
        }
    }
    
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        refresh()
    }
}



extension ChangeMasterKeyVC: KeyFilePickerCoordinatorDelegate {
    func didPickKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference?) {
        setKeyFile(keyFile)
    }
    
    func didRemoveOrDeleteKeyFile(in coordinator: KeyFilePickerCoordinator, keyFile: URLReference) {
        if self.keyFileRef == keyFile {
            setKeyFile(nil)
        }
    }

    func setKeyFile(_ urlRef: URLReference?) {
        self.keyFileRef = urlRef
        
        guard let keyFileRef = urlRef else {
            keyFileField.text = ""
            return
        }
        
        if let error = keyFileRef.error {
            keyFileField.text = ""
            showErrorAlert(error)
        } else {
            keyFileField.text = keyFileRef.visibleFileName
        }
        refresh()
    }
}

extension ChangeMasterKeyVC: HardwareKeyPickerDelegate {
    func didDismiss(_ picker: HardwareKeyPicker) {
    }
    func didSelectKey(yubiKey: YubiKey?, in picker: HardwareKeyPicker) {
        setYubiKey(yubiKey)
    }
    
    func setYubiKey(_ yubiKey: YubiKey?) {
        self.yubiKey = yubiKey
        keyFileField.isYubiKeyActive = (yubiKey != nil)

        if let _yubiKey = yubiKey {
            Diag.info("Hardware key selected [key: \(_yubiKey)]")
        } else {
            Diag.info("No hardware key selected")
        }
        refresh()
    }
}

extension ChangeMasterKeyVC: DatabaseManagerObserver {
    func databaseManager(willSaveDatabase urlRef: URLReference) {
        showProgressOverlay()
    }
    
    func databaseManager(didSaveDatabase urlRef: URLReference) {
        DatabaseManager.shared.removeObserver(self)
        hideProgressOverlay()
        let parentVC = presentingViewController
        dismiss(animated: true, completion: {
            let alert = UIAlertController.make(
                title: LString.databaseStatusSavingDone,
                message: LString.masterKeySuccessfullyChanged,
                dismissButtonTitle: LString.actionOK)
            parentVC?.present(alert, animated: true, completion: nil)
        })
    }
    
    func databaseManager(progressDidChange progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }
    
    func databaseManager(database urlRef: URLReference, isCancelled: Bool) {
        Diag.info("Master key change cancelled")
        DatabaseManager.shared.removeObserver(self)
        hideProgressOverlay()
    }
    
    func databaseManager(
        database urlRef: URLReference,
        savingError error: Error,
        data: ByteArray?)
    {
        showDatabaseSavingError(
            error,
            fileName: urlRef.visibleFileName,
            diagnosticsHandler: nil,
            exportableData: data,
            parent: self)
        DatabaseManager.shared.removeObserver(self)
        hideProgressOverlay()
    }
    
}
