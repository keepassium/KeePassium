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
    func didPressPickKeyFile(in databaseCreatorVC: DatabaseCreatorVC, popoverSource: UIView)
}

class DatabaseCreatorVC: UIViewController {

    public var databaseFileName: String { return fileNameField.text ?? "" }
    public var password: String { return passwordField.text ?? ""}
    public var keyFile: URLReference? {
        didSet {
            showKeyFile(keyFile)
        }
    }

    @IBOutlet weak var fileNameField: ValidatingTextField!
    @IBOutlet weak var passwordField: ProtectedTextField!
    @IBOutlet weak var keyFileField: WatchdogAwareTextField!
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
    
    private func showKeyFile(_ keyFile: URLReference?) {
        guard let info = keyFile?.getInfo() else {
            keyFileField.text = nil
            return
        }
        
        if info.hasError {
            keyFileField.text = info.errorMessage
            keyFileField.textColor = .errorMessage
        } else {
            keyFileField.text = info.fileName
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
        let diagInfoVC = ViewDiagnosticsVC.make()
        present(diagInfoVC, animated: true, completion: nil)
    }
    
    @IBAction func didPressContinue(_ sender: Any) {
        let hasPassword = passwordField.text?.isNotEmpty ?? false
        guard hasPassword || (keyFile != nil) else {
            setError(
                message: NSLocalizedString("Please enter a password or choose a key file.", comment: "Hint shown when both password and key file are empty."),
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
            delegate?.didPressPickKeyFile(in: self, popoverSource: textField)
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

extension DatabaseCreatorVC: ProgressViewHost {
    
    func showProgressView(title: String, allowCancelling: Bool) {
        if progressOverlay != nil {
            progressOverlay?.title = title
            progressOverlay?.isCancellable = allowCancelling
            return
        }
        navigationItem.hidesBackButton = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        continueButton.isEnabled = false
        progressOverlay = ProgressOverlay.addTo(
            containerView,
            title: title,
            animated: true)
        progressOverlay?.isCancellable = allowCancelling
    }
    
    func updateProgressView(with progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }
    
    func hideProgressView() {
        guard progressOverlay != nil else { return }
        navigationItem.hidesBackButton = false
        navigationItem.rightBarButtonItem?.isEnabled = true
        continueButton.isEnabled = true
        progressOverlay?.dismiss(animated: true) {
            [weak self] (finished) in
            guard let _self = self else { return }
            _self.progressOverlay?.removeFromSuperview()
            _self.progressOverlay = nil
        }
    }
}
