//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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

    func passcodeInput(_ sender: PasscodeInputVC, shouldTryPasscode passcode: String)

    func passcodeInput(_ sender: PasscodeInputVC, didEnterPasscode passcode: String)

    func passcodeInputDidRequestBiometrics(_ sender: PasscodeInputVC)
}

extension PasscodeInputDelegate {
    func passcodeInputDidCancel(_ sender: PasscodeInputVC) {}
    func passcodeInput(_sender: PasscodeInputVC, canAcceptPasscode passcode: String) -> Bool {
        return passcode.count > 0
    }
    func passcodeInput(_ sender: PasscodeInputVC, shouldTryPasscode passcode: String) {}
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
    @IBOutlet weak var instructionsToCancelButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var biometricsHintLabel: UILabel!

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

        view.backgroundColor = ImageAsset.backgroundPattern.asColor()
        view.layer.isOpaque = false

        mainButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        mainButton.titleLabel?.textAlignment = .center
        mainButton.titleLabel?.adjustsFontForContentSizeCategory = true

        self.presentationController?.delegate = self

        passcodeTextField.invalidBackgroundColor = passcodeTextField.backgroundColor
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

        setupKeyCommands()
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
        if shouldActivateKeyboard {
            showKeyboard()
        }
    }

    private func setupKeyCommands() {
        switch mode {
        case .verification:
            let useBiometricsCommand = UIKeyCommand(
                input: UIKeyCommand.inputEscape,
                modifierFlags: [],
                action: #selector(didPressUseBiometricsButton)
            )
            addKeyCommand(useBiometricsCommand)
        case .setup, .change:
            let cancelCommand = UIKeyCommand(
                input: UIKeyCommand.inputEscape,
                modifierFlags: [],
                action: #selector(didPressCancelButton)
            )
            addKeyCommand(cancelCommand)
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
        useBiometricsButton.setImage(
            .symbol(biometryType.symbolName),
            for: .normal)
        useBiometricsButton.accessibilityLabel = biometryType.name

        let showMacOSBiometricHint = ProcessInfo.isRunningOnMac && !useBiometricsButton.isHidden
        biometricsHintLabel.isHidden = !showMacOSBiometricHint
        biometricsHintLabel.text = LString.hintPressEscForTouchID
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


    @IBAction private func didPressCancelButton(_ sender: Any) {
        guard cancelButton.isEnabled && !cancelButton.isHidden else {
            return
        }
        delegate?.passcodeInputDidCancel(self)
    }

    @IBAction private func didPressMainButton(_ sender: Any) {
        let passcode = passcodeTextField.text ?? ""
        delegate?.passcodeInput(self, didEnterPasscode: passcode)
    }

    @IBAction private func didPressSwitchKeyboard(_ sender: Any) {
        setKeyboardType(nextKeyboardType)
    }

    @IBAction private func didPressUseBiometricsButton(_ sender: Any) {
        guard useBiometricsButton.isEnabled && !useBiometricsButton.isHidden else {
            return
        }
        delegate?.passcodeInputDidRequestBiometrics(self)
    }
}

extension PasscodeInputVC: UITextFieldDelegate, ValidatingTextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard passcodeTextField.isValid else {
            return false
        }
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

    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        guard mode == .verification,
              sender.isValid
        else {
            return
        }
        if !Settings.current.isLockAllDatabasesOnFailedPasscode {
            delegate?.passcodeInput(self, shouldTryPasscode: text)
        }
    }
}


extension PasscodeInputVC: UIAdaptivePresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didPressCancelButton(self)
    }
}
