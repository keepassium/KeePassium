//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol DatabaseCreatorDelegate: class {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressContinue(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressErrorDetails(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressPickKeyFile(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    func didPressPickHardwareKey(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
}

class DatabaseCreatorVC: UIViewController {

    public var databaseFileName: String { return fileNameField.text ?? "" }
    public var password: String { return passwordField.text ?? ""}
    public var keyFile: URLReference? {
        didSet {
            showKeyFile(keyFile)
        }
    }
    public var yubiKey: YubiKey? {
        didSet {
            keyFileField?.isYubiKeyActive = (yubiKey != nil)
        }
    }

    @IBOutlet weak var fileNameField: ValidatingTextField!
    @IBOutlet weak var passwordField: ProtectedTextField!
    @IBOutlet weak var keyFileField: KeyFileTextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet var errorMessagePanel: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var keyboardLayoutConstraint: KeyboardLayoutConstraint!
    @IBOutlet weak var scrollView: UIScrollView!
    
    weak var delegate: DatabaseCreatorDelegate?

    private var containerView: UIView {
        return navigationController?.view ?? self.view
    }
    private var progressOverlay: ProgressOverlay?
    
    public static func create() -> DatabaseCreatorVC {
        return DatabaseCreatorVC.instantiateFromStoryboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = LString.titleCreateDatabase
        
        setError(message: nil, animated: false)
        
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false

        fileNameField.validityDelegate = self
        fileNameField.delegate = self
        passwordField.validityDelegate = self
        passwordField.delegate = self
        keyFileField.delegate = self
        
        keyFileField.yubikeyHandler = {
            [weak self] (field) in
            guard let self = self else { return }
            let popoverAnchor = PopoverAnchor(
                sourceView: self.keyFileField,
                sourceRect: self.keyFileField.bounds)
            self.delegate?.didPressPickHardwareKey(in: self, at: popoverAnchor)
        }
        keyFileField.isYubiKeyActive = (yubiKey != nil)
        
        passwordField.becomeFirstResponder()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateKeyboardLayoutConstraints()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async {
            self.updateKeyboardLayoutConstraints()
        }
    }
    
    private func updateKeyboardLayoutConstraints() {
        let view = containerView
        if let window = view.window {
            let viewTop = view.convert(view.frame.origin, to: window).y
            let viewHeight = view.frame.height
            let windowHeight = window.frame.height
            let viewBottomOffset = windowHeight - (viewTop + viewHeight)
            keyboardLayoutConstraint.viewOffset = viewBottomOffset
        }
    }
    
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return passwordField.becomeFirstResponder()
    }
    
    private func showKeyFile(_ keyFileRef: URLReference?) {
        guard let keyFileRef = keyFileRef else {
            keyFileField.text = nil
            return
        }
        
        if keyFileRef.hasError {
            keyFileField.text = keyFileRef.error?.localizedDescription
            keyFileField.textColor = .errorMessage
        } else {
            keyFileField.text = keyFileRef.visibleFileName
            keyFileField.textColor = .primaryText
        }
        setError(message: nil, animated: true)
    }
    
    func setError(message: String?, animated: Bool) {
        errorLabel.text = message
        let isToShow = message?.isNotEmpty ?? false
        let isToHide = !isToShow
        
        if isToShow {
            self.scrollView.setContentOffset(CGPoint(x: 0, y: 0), animated: animated)
        }

        guard errorMessagePanel.isHidden != isToHide else {
            return
        }
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.errorMessagePanel.isHidden = isToHide
                self.errorMessagePanel.superview?.layoutIfNeeded()
            }
        } else {
            errorMessagePanel.isHidden = isToHide
            errorMessagePanel.superview?.layoutIfNeeded()
        }
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressErrorDetails(_ sender: Any) {
        delegate?.didPressErrorDetails(in: self)
    }
    
    @IBAction func didPressContinue(_ sender: Any) {
        let hasPassword = passwordField.text?.isNotEmpty ?? false
        let hasKeyFile = keyFile != nil
        let hasYubiKey = yubiKey != nil
        guard hasPassword || hasKeyFile || hasYubiKey else {
            setError(
                message: NSLocalizedString(
                    "[Database/Create] Please enter a password or choose a key file.",
                    value: "Please enter a password or choose a key file.",
                    comment: "Hint shown when both password and key file are empty."),
                animated: true)
            return
        }
        delegate?.didPressContinue(in: self)
    }
}

extension DatabaseCreatorVC: ValidatingTextFieldDelegate {
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        guard let text = sender.text else { return false }
        switch sender {
        case fileNameField:
            return text.isNotEmpty && !text.contains("/")
        case passwordField:
            return true
        default:
            return true
        }
    }
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        if sender === passwordField {
            setError(message: nil, animated: true)
        }
    }
}

extension DatabaseCreatorVC: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if textField === keyFileField {
            setError(message: nil, animated: true)
            passwordField.becomeFirstResponder()
            let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
            delegate?.didPressPickKeyFile(in: self, at: popoverAnchor)
            return false
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.passwordField {
            didPressContinue(textField)
        }
        return true
    }
}
