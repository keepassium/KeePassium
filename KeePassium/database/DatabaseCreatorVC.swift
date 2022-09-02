//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol DatabaseCreatorDelegate: AnyObject {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressContinue(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressErrorDetails(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressPickKeyFile(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    func didPressPickHardwareKey(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    func shouldDismissPopovers(in databaseCreatorVC: DatabaseCreatorVC)
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
            if yubiKey != nil {
                hardwareKeyField.text = YubiKey.getTitle(for: yubiKey)
            } else {
                hardwareKeyField.text = nil // use the "No Hardware Key" placeholder
            }
        }
    }

    @IBOutlet weak var fileNameField: ValidatingTextField!
    @IBOutlet weak var passwordField: ProtectedTextField!
    @IBOutlet weak var keyFileField: ValidatingTextField!
    @IBOutlet weak var hardwareKeyField: ValidatingTextField!
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var errorMessagePanel: UIView!
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
        
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false

        passwordField.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        keyFileField.maskedCorners = []
        hardwareKeyField.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        #if targetEnvironment(macCatalyst)
        keyFileField.cursor = .arrow
        hardwareKeyField.cursor = .arrow
        #endif

        fileNameField.validityDelegate = self
        fileNameField.delegate = self
        passwordField.validityDelegate = self
        passwordField.delegate = self
        keyFileField.delegate = self
        hardwareKeyField.delegate = self
        
        hardwareKeyField.placeholder = LString.noHardwareKey
        
        passwordField.accessibilityLabel = LString.fieldPassword
        keyFileField.accessibilityLabel = LString.fieldKeyFile
        hardwareKeyField.accessibilityLabel = LString.fieldHardwareKey
        
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
        hideErrorMessage(animated: true)
    }
    
    func showErrorMessage(_ message: String, haptics: HapticFeedback.Kind?, animated: Bool) {
        Diag.error(message)
        UIAccessibility.post(notification: .announcement, argument: message)
        
        var toastStyle = ToastStyle()
        toastStyle.backgroundColor = .warningMessage
        toastStyle.imageSize = CGSize(width: 29, height: 29)
        toastStyle.displayShadow = false
        let toastAction = ToastAction(
            title: LString.actionShowDetails,
            handler: { [weak self] in
                self?.didPressErrorDetails()
            }
        )
        let toastView = view.toastViewForMessage(
            message,
            title: nil,
            image: UIImage.get(.exclamationMarkTriangle),
            action: toastAction,
            style: toastStyle
        )
        view.showToast(toastView, duration: 5, position: .top, action: toastAction, completion: nil)
        StoreReviewSuggester.registerEvent(.trouble)
    }
    
    func hideErrorMessage(animated: Bool) {
        view.hideToast()
    }
    
    
    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    private func didPressErrorDetails() {
        hideErrorMessage(animated: true)
        delegate?.didPressErrorDetails(in: self)
    }
    
    @IBAction func didPressContinue(_ sender: Any) {
        let hasPassword = passwordField.text?.isNotEmpty ?? false
        let hasKeyFile = keyFile != nil
        let hasYubiKey = yubiKey != nil
        guard hasPassword || hasKeyFile || hasYubiKey else {
            showErrorMessage(
                NSLocalizedString(
                    "[Database/Create] Please enter a password or choose a key file.",
                    value: "Please enter a password or choose a key file.",
                    comment: "Hint shown when both password and key file are empty."),
                haptics: .wrongPassword,
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
            hideErrorMessage(animated: true)
        }
    }
}

extension DatabaseCreatorVC: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return true
        }
        let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
        switch textField {
        case keyFileField:
            hideErrorMessage(animated: true)
            delegate?.didPressPickKeyFile(in: self, at: popoverAnchor)
            return false 
        case hardwareKeyField:
            hideErrorMessage(animated: true)
            delegate?.didPressPickHardwareKey(in: self, at: popoverAnchor)
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
            hideErrorMessage(animated: true)
            delegate?.didPressPickKeyFile(in: self, at: popoverAnchor)
            if isMac {
                passwordField.becomeFirstResponder()
            }
        case hardwareKeyField:
            hideErrorMessage(animated: true)
            delegate?.didPressPickHardwareKey(in: self, at: popoverAnchor)
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
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.passwordField {
            didPressContinue(textField)
        }
        return true
    }
}
