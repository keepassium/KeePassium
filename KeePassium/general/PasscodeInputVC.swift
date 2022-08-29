//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication

protocol PasscodeInputDelegate: AnyObject {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC)
    
    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool
    
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String)
    
    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC)
}

extension PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {}
    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }
    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode: String) {}
    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC) {}
}

class PasscodeInputVC: UIViewController {

    public enum Mode {
        case setup
        case change
        case verification
    }
    
    @IBOutlet weak var instructionsLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var passcodeTextField: ProtectedTextField!
    @IBOutlet weak var mainButton: UIButton!
    @IBOutlet weak var switchKeyboardButton: UIButton!
    @IBOutlet weak var useBiometricsButton: UIButton!
    @IBOutlet weak var keyboardLayoutConstraint: KeyboardLayoutConstraint!
    @IBOutlet weak var instructionsToCancelButtonConstraint: NSLayoutConstraint!
    
    public var mode: Mode = .setup
    public var shouldActivateKeyboard = true
    public var isCancelAllowed = true
    public var isBiometricsAllowed = false {
        didSet { refreshBiometricsButton() }
    }
    
    weak var delegate: PasscodeInputDelegate?
    private var nextKeyboardType = Settings.PasscodeKeyboardType.alphanumeric
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false
        
        mainButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        mainButton.titleLabel?.textAlignment = .center
        mainButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        self.presentationController?.delegate = self
        
        passcodeTextField.delegate = self
        passcodeTextField.validityDelegate = self

        switch mode {
        case .setup, .change:
            instructionsLabel.text = LString.titleSetupAppPasscode
            mainButton.setTitle(LString.actionSavePasscode, for: .normal)
            passcodeTextField.isWatchdogAware = true
        case .verification:
            instructionsLabel.text = LString.titleUnlockTheApp
            mainButton.setTitle(LString.actionUnlock, for: .normal)
            passcodeTextField.isWatchdogAware = false 
        }
        cancelButton.isHidden = !isCancelAllowed
        instructionsToCancelButtonConstraint.isActive = isCancelAllowed
        
        setKeyboardType(Settings.current.passcodeKeyboardType)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        mainButton.isEnabled = passcodeTextField.isValid
        refreshBiometricsButton()
        
        if shouldActivateKeyboard {
            showKeyboard()
        }
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateKeyboardLayoutConstraints()
        if shouldActivateKeyboard {
            showKeyboard()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        DispatchQueue.main.async {
            self.updateKeyboardLayoutConstraints()
        }
    }
    
    private func refreshBiometricsButton() {
        guard isViewLoaded else { return }

        useBiometricsButton.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        useBiometricsButton.isHidden = !isBiometricsAllowed
        if useBiometricsButton.isHidden {
            mainButton.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMinYCorner,
                .layerMaxXMaxYCorner
            ]
        } else {
            mainButton.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        }
        
        let biometryType = LAContext.getBiometryType()
        useBiometricsButton.setImage(biometryType.icon, for: .normal)
        useBiometricsButton.accessibilityLabel = biometryType.name
    }
    
    private func updateKeyboardLayoutConstraints() {
        guard let screen = view.window?.screen else { return }
        let windowSpace = screen.coordinateSpace
        
        let viewTop = view.convert(view.frame.origin, to: windowSpace).y
        let viewHeight = view.frame.height
        let windowHeight = windowSpace.bounds.height
        let viewBottomOffset = windowHeight - (viewTop + viewHeight)
        #if MAIN_APP
        keyboardLayoutConstraint.viewOffset = viewBottomOffset
        #else
        let weirdAutoFillOffset = CGFloat(50)
        keyboardLayoutConstraint.viewOffset = viewBottomOffset - weirdAutoFillOffset
        #endif
    }
    
    public func showKeyboard() {
        view.window?.makeKey()
        passcodeTextField.becomeFirstResponderWhenSafe()
    }
    
    private func setKeyboardType(_ type: Settings.PasscodeKeyboardType) {
        if ProcessInfo.isRunningOnMac || UIDevice.current.userInterfaceIdiom == .pad {
            switchKeyboardButton.isHidden = true
            return
        }
        
        Settings.current.passcodeKeyboardType = type
        let nextKeyboardTitle: String
        switch type {
        case .numeric:
            passcodeTextField.keyboardType = .numberPad
            nextKeyboardType = .alphanumeric
            nextKeyboardTitle = LString.actionSwitchToAlphanumericKeyboard
        case .alphanumeric:
            passcodeTextField.keyboardType = .asciiCapable
            nextKeyboardType = .numeric
            nextKeyboardTitle = LString.actionSwitchToDigitalKeyboard
        }
        passcodeTextField.reloadInputViews()
        switchKeyboardButton.setTitle(nextKeyboardTitle, for: .normal)
    }
    
    public func animateWrongPassccode() {
        passcodeTextField.shake()
        passcodeTextField.selectAll(nil)
    }
    
    
    @IBAction func didPressCancelButton(_ sender: Any) {
        delegate?.passcodeInputDidCancel(self)
    }
    
    @IBAction func didPressMainButton(_ sender: Any) {
        let passcode = passcodeTextField.text ?? ""
        delegate?.passcodeInput(self, didEnterPasscode: passcode)
    }
    
    @IBAction func didPressSwitchKeyboard(_ sender: Any) {
        setKeyboardType(nextKeyboardType)
    }
    
    @IBAction func didPressUseBiometricsButton(_ sender: Any) {
        delegate?.passcodeInputDidRequestBiometrics(self)
    }
}

extension PasscodeInputVC: UITextFieldDelegate, ValidatingTextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didPressMainButton(textField)
        return false
    }
    
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool {
        let passcode = passcodeTextField.text ?? ""
        let isAcceptable = delegate?
            .passcodeInput(_sender: self, canAcceptPasscode: passcode) ?? false
        mainButton.isEnabled = isAcceptable
        return isAcceptable
    }
}


extension PasscodeInputVC: UIAdaptivePresentationControllerDelegate {
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didPressCancelButton(self)
    }
}
