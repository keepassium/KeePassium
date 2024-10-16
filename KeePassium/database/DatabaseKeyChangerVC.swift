//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseKeyChangerDelegate: AnyObject {
    func didPressSelectKeyFile(at popoverAnchor: PopoverAnchor, in viewController: DatabaseKeyChangerVC)
    func didPressSelectHardwareKey(at popoverAnchor: PopoverAnchor, in viewController: DatabaseKeyChangerVC)
    func didPressSaveChanges(in viewController: DatabaseKeyChangerVC)
    func shouldDismissPopovers(in viewController: DatabaseKeyChangerVC)
}

final class DatabaseKeyChangerVC: UIViewController {

    @IBOutlet private weak var databaseNameLabel: UILabel!
    @IBOutlet private weak var databaseIcon: UIImageView!
    @IBOutlet private weak var inputPanel: UIView!
    @IBOutlet private weak var passwordField: ProtectedTextField!
    @IBOutlet private weak var repeatPasswordField: ProtectedTextField!
    @IBOutlet private weak var keyFileField: ValidatingTextField!
    @IBOutlet private weak var hardwareKeyField: ValidatingTextField!
    @IBOutlet private weak var passwordMismatchImage: UIImageView!

    weak var delegate: DatabaseKeyChangerDelegate?

    internal var password: String { return passwordField.text ?? ""}
    internal private(set) var keyFileRef: URLReference?
    internal private(set) var yubiKey: YubiKey?
    private var databaseFile: DatabaseFile!

    static func make(for databaseFile: DatabaseFile) -> DatabaseKeyChangerVC {
        let vc = DatabaseKeyChangerVC.instantiateFromStoryboard()
        vc.databaseFile = databaseFile
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.titleMasterKey
        databaseNameLabel.text = databaseFile.visibleFileName
        databaseIcon.image = .symbol(databaseFile.getIconSymbol())

        passwordField.invalidBackgroundColor = nil
        repeatPasswordField.invalidBackgroundColor = nil
        keyFileField.invalidBackgroundColor = nil
        hardwareKeyField.invalidBackgroundColor = nil
        passwordField.delegate = self
        passwordField.validityDelegate = self
        repeatPasswordField.delegate = self
        repeatPasswordField.validityDelegate = self
        keyFileField.delegate = self
        keyFileField.validityDelegate = self
        hardwareKeyField.delegate = self
        hardwareKeyField.validityDelegate = self

        hardwareKeyField.placeholder = LString.noHardwareKey

        passwordField.accessibilityLabel = LString.fieldPassword
        repeatPasswordField.accessibilityLabel = LString.fieldRepeatPassword
        keyFileField.accessibilityLabel = LString.fieldKeyFile
        hardwareKeyField.accessibilityLabel = LString.fieldHardwareKey

        passwordField.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        repeatPasswordField.maskedCorners = []
        keyFileField.maskedCorners = []
        hardwareKeyField.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        #if targetEnvironment(macCatalyst)
        keyFileField.cursor = .arrow
        hardwareKeyField.cursor = .arrow
        #endif

        view.backgroundColor = ImageAsset.backgroundPattern.asColor()
        view.layer.isOpaque = false

        navigationItem.rightBarButtonItem?.isEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        passwordField.becomeFirstResponder()
        refresh()
    }

    func refresh() {
        navigationItem.rightBarButtonItem?.isEnabled = areAllFieldsValid()
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

    func setYubiKey(_ yubiKey: YubiKey?) {
        self.yubiKey = yubiKey

        if let yubiKey = yubiKey {
            hardwareKeyField.text = YubiKey.getTitle(for: yubiKey)
            Diag.info("Hardware key selected [key: \(yubiKey)]")
        } else {
            hardwareKeyField.text = "" // use "No Hardware Key" placeholder
            Diag.info("No hardware key selected")
        }
        refresh()
    }


    private func isFieldValid(_ textField: UITextField) -> Bool {
        switch textField {
        case passwordField, keyFileField, hardwareKeyField:
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

    private func areAllFieldsValid() -> Bool {
        let result = passwordField.isValid &&
            repeatPasswordField.isValid &&
            keyFileField.isValid &&
            hardwareKeyField.isValid
        return result
    }

    private func verifyEnteredKey(success successHandler: @escaping () -> Void) {
        let entropy = Float(passwordField.quality?.entropy ?? 0)
        let length = passwordField.text?.count ?? 0
        guard ManagedAppConfig.shared.isAcceptableDatabasePassword(length: length, entropy: entropy) else {
            Diag.warning("Database password strength does not meet organization's requirements")
            showNotification(
                LString.orgRequiresStrongerDatabasePassword,
                title: nil,
                image: .symbol(.managedParameter)?.withTintColor(.iconTint, renderingMode: .alwaysOriginal),
                hidePrevious: true,
                duration: 3
            )
            return
        }

        guard areAllFieldsValid() else {
            Diag.warning("Not all fields are valid, cannot save")
            return
        }

        let isGoodEnough = entropy > PasswordQuality.minDatabasePasswordEntropy
        if isGoodEnough || keyFileRef != nil || yubiKey != nil {
            successHandler()
            return
        }
        let confirmationAlert = UIAlertController.make(
            title: LString.titleWarning,
            message: LString.databasePasswordTooWeak,
            dismissButtonTitle: LString.actionCancel)
        confirmationAlert.addAction(title: LString.actionContinue) { _ in
            successHandler()
        }
        present(confirmationAlert, animated: true)
    }

    private func shakeInvalidInputs() {
        if areAllFieldsValid() {
            assertionFailure("Everything is ok, why are we here?")
            return
        }

        if !repeatPasswordField.isValid { 
            repeatPasswordField.shake()
            passwordMismatchImage.shake()
        } else { 
            inputPanel.shake()
            passwordMismatchImage.shake()
        }
    }


    @IBAction private func didPressSaveChanges(_ sender: Any) {
        verifyEnteredKey(success: { [weak self] in
            guard let self else { return }
            delegate?.didPressSaveChanges(in: self)
        })
    }
}

extension DatabaseKeyChangerVC: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case passwordField:
            repeatPasswordField.becomeFirstResponder()
        case repeatPasswordField:
            if areAllFieldsValid() {
                didPressSaveChanges(self)
            } else {
                shakeInvalidInputs()
            }
        default:
            break
        }
        return true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return true
        }
        let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
        switch textField {
        case keyFileField:
            delegate?.didPressSelectKeyFile(at: popoverAnchor, in: self)
            return false 
        case hardwareKeyField:
            delegate?.didPressSelectHardwareKey(at: popoverAnchor, in: self)
            return false 
        default:
            break
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard UIDevice.current.userInterfaceIdiom != .phone else {
            return
        }
        let isMac = ProcessInfo.isRunningOnMac
        let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
        switch textField {
        case keyFileField:
            delegate?.didPressSelectKeyFile(at: popoverAnchor, in: self)
            if isMac {
                passwordField.becomeFirstResponder()
            }
        case hardwareKeyField:
            delegate?.didPressSelectHardwareKey(at: popoverAnchor, in: self)
            if isMac {
                passwordField.becomeFirstResponder()
            }
        default:
            if !isMac {
                delegate?.shouldDismissPopovers(in: self)
            }
        }
    }

    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        if textField === keyFileField || textField === hardwareKeyField {
            return false
        }
        return true
    }
}

extension DatabaseKeyChangerVC: ValidatingTextFieldDelegate {
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        return isFieldValid(sender)
    }

    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        if sender === passwordField {
            passwordField.quality = PasswordQuality(password: text)
            repeatPasswordField.validate()
        }
    }

    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {
        refresh()
    }
}
