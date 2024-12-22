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

final class PasscodeInputVC: UIViewController {

    public enum Mode {
        case setup
        case change
        case verification
    }

    @IBOutlet private weak var instructionsLabel: UILabel!
    @IBOutlet private weak var cancelButton: UIButton!
    @IBOutlet private weak var passcodeTextField: ProtectedTextField!
    @IBOutlet private weak var mainButton: UIButton!
    @IBOutlet private weak var switchKeyboardButton: UIButton!
    @IBOutlet private weak var useBiometricsButton: UIButton!
    @IBOutlet private weak var instructionsToCancelButtonConstraint: NSLayoutConstraint!
    @IBOutlet private weak var hintLabel: UILabel!

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
        hintLabel.isHidden = true

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

        let showMacOSBiometricHint = ProcessInfo.isRunningOnMac
            && !useBiometricsButton.isHidden
            && mode == .verification
        if showMacOSBiometricHint {
            hintLabel.isHidden = false
            hintLabel.text = LString.hintPressEscForTouchID
        }
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

        switch mode {
        case .verification:
            delegate?.passcodeInput(self, didEnterPasscode: passcode)
        case .setup, .change:
            verifyNewPasscode(success: { [weak self] in
                guard let self else { return }
                delegate?.passcodeInput(self, didEnterPasscode: passcode)
            })
        }
    }

    private func verifyNewPasscode(success successHandler: @escaping () -> Void) {
        assert(mode != .verification, "Should check only newly defined passcodes")

        let entropy = Float(passcodeTextField.quality?.entropy ?? 0)
        let length = passcodeTextField.text?.count ?? 0
        guard ManagedAppConfig.shared.isAcceptableAppPasscode(length: length, entropy: entropy) else {
            Diag.warning("App passcode strength does not meet organization's requirements")
            showNotification(
                LString.orgRequiresStrongerPasscode,
                title: nil,
                image: .symbol(.managedParameter)?.withTintColor(.iconTint, renderingMode: .alwaysOriginal),
                hidePrevious: true,
                duration: 3
            )
            return
        }
        successHandler()
    }

    private func refreshPasscodeQualityWarning(_ quality: PasswordQuality?) {
        switch mode {
        case .setup, .change:
            guard let quality else {
                hintLabel.isHidden = true
                return
            }
            let isGoodEnough = Float(quality.entropy) > PasswordQuality.minAppPasscodeEntropy
            hintLabel.isHidden = isGoodEnough
            hintLabel.text = String.localizedStringWithFormat(
                LString.Warning.iconWithMessageTemplate,
                LString.appPasscodeTooWeak
            )
        default:
            return
        }
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
        let isAcceptable = delegate?.passcodeInput(_sender: self, canAcceptPasscode: passcode) ?? false
        mainButton.isEnabled = isAcceptable
        return isAcceptable
    }

    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        switch mode {
        case .change, .setup:
            let quality = PasswordQuality(password: text)
            passcodeTextField.quality = quality
            refreshPasscodeQualityWarning(quality)
        case .verification:
            guard sender.isValid else {
                return
            }
            if !Settings.current.isLockAllDatabasesOnFailedPasscode {
                delegate?.passcodeInput(self, shouldTryPasscode: text)
            }
        }
    }
}


extension PasscodeInputVC: UIAdaptivePresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        didPressCancelButton(self)
    }
}

extension LString {
    public static let appPasscodeTooWeak = NSLocalizedString(
        "[AppLock/weakPasscodeWarning]",
        value: "This passcode is easy to guess. Try entering a stronger one.",
        comment: "Notification when user tries to set up too weak an app protection passcode.")
}
