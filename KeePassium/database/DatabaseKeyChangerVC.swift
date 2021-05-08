//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
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
}

final class DatabaseKeyChangerVC: UIViewController {
   
    @IBOutlet private weak var keyboardAdjView: UIView!
    @IBOutlet private weak var databaseNameLabel: UILabel!
    @IBOutlet private weak var databaseIcon: UIImageView!
    @IBOutlet private weak var passwordField: ValidatingTextField!
    @IBOutlet private weak var repeatPasswordField: ValidatingTextField!
    @IBOutlet private weak var keyFileField: KeyFileTextField!
    @IBOutlet private weak var passwordMismatchImage: UIImageView!
    @IBOutlet private weak var keyboardAdjConstraint: KeyboardLayoutConstraint!
    
    weak var delegate: DatabaseKeyChangerDelegate?
    
    internal var password: String { return passwordField.text ?? ""}
    internal private(set) var keyFileRef: URLReference?
    internal private(set) var yubiKey: YubiKey?
    private var databaseRef: URLReference!

    static func make(for databaseRef: URLReference) -> DatabaseKeyChangerVC {
        let vc = DatabaseKeyChangerVC.instantiateFromStoryboard()
        vc.databaseRef = databaseRef
        return vc
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
    
    private func setupHardwareKeyPicker() {
        keyFileField.yubikeyHandler = {
            [weak self] (field, popoverAnchor) in
            guard let self = self else { return }
            self.delegate?.didPressSelectHardwareKey(at: popoverAnchor, in: self)
        }
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
        keyFileField.isYubiKeyActive = (yubiKey != nil)

        if let _yubiKey = yubiKey {
            Diag.info("Hardware key selected [key: \(_yubiKey)]")
        } else {
            Diag.info("No hardware key selected")
        }
        refresh()
    }
    
    
    @IBAction func didPressSaveChanges(_ sender: Any) {
        delegate?.didPressSaveChanges(in: self)
    }
}

extension DatabaseKeyChangerVC: UITextFieldDelegate {
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
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField === keyFileField {
            passwordField.becomeFirstResponder()
            let popoverAnchor = PopoverAnchor(sourceView: keyFileField, sourceRect: keyFileField.bounds)
            delegate?.didPressSelectKeyFile(at: popoverAnchor, in: self)
        }
    }
}

extension DatabaseKeyChangerVC: ValidatingTextFieldDelegate {
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
