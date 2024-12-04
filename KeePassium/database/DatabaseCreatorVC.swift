//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol DatabaseCreatorDelegate: AnyObject {
    func didPressCancel(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressSaveToFiles(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressSaveToServer(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressErrorDetails(in databaseCreatorVC: DatabaseCreatorVC)
    func didPressPickKeyFile(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    func didPressPickHardwareKey(
        in databaseCreatorVC: DatabaseCreatorVC,
        at popoverAnchor: PopoverAnchor)
    func shouldDismissPopovers(in databaseCreatorVC: DatabaseCreatorVC)
}

class DatabaseCreatorVC: UIViewController, BusyStateIndicating, Refreshable {
    enum DestinationType {
        case files
        case remoteServer
    }

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
    @IBOutlet weak var saveToFilesButton: UIButton!
    @IBOutlet weak var saveToServerButton: UIButton!
    @IBOutlet weak var errorMessagePanel: UIView!
    @IBOutlet weak var errorLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!

    weak var delegate: DatabaseCreatorDelegate?

    private var containerView: UIView {
        return navigationController?.view ?? self.view
    }
    private var progressOverlay: ProgressOverlay?
    private var isBusy = false

    private var hasPassword: Bool { passwordField.text?.isNotEmpty ?? false }
    private var hasKeyFile: Bool { keyFile != nil }
    private var hasYubiKey: Bool { yubiKey != nil }

    public static func create() -> DatabaseCreatorVC {
        return DatabaseCreatorVC.instantiateFromStoryboard()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = LString.titleNewDatabase

        view.backgroundColor = ImageAsset.backgroundPattern.asColor()
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
        setupSaveToServerButton()
        refresh()
    }

    private func setupSaveToServerButton() {
        var config = UIButton.Configuration.borderedTinted()
        config.title = LString.actionSaveToServer
        config.cornerStyle = .medium
        config.image = .symbol(.network)
        config.preferredSymbolConfigurationForImage = .init(scale: .medium)
        config.imagePadding = 8
        saveToServerButton.configuration = config
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

    func indicateState(isBusy: Bool) {
        self.isBusy = isBusy
        refresh()
    }

    func refresh() {
        let appConfig = ManagedAppConfig.shared
        saveToFilesButton.isEnabled = !isBusy && appConfig.areSystemFileProvidersAllowed
        saveToServerButton.isEnabled = !isBusy && appConfig.areInAppFileProvidersAllowed
    }

    func showErrorMessage(_ message: String, haptics: HapticFeedback.Kind) {
        Diag.error(message)
        UIAccessibility.post(notification: .announcement, argument: message)
        HapticFeedback.play(haptics)

        showNotification(message, image: .symbol(.exclamationMarkTriangle))
        StoreReviewSuggester.registerEvent(.trouble)
    }

    func hideErrorMessage(animated: Bool) {
        view.hideToast()
    }
}

extension DatabaseCreatorVC {
    @IBAction private func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }

    private func didPressErrorDetails() {
        hideErrorMessage(animated: true)
        delegate?.didPressErrorDetails(in: self)
    }

    private func verifyEnteredKey(success successHandler: @escaping () -> Void) {
        guard hasPassword || hasKeyFile || hasYubiKey else {
            showErrorMessage(
                NSLocalizedString(
                    "[Database/Create] Please enter a password or choose a key file.",
                    value: "Please enter a password or choose a key file.",
                    comment: "Hint shown when both password and key file are empty."),
                haptics: .wrongPassword
            )
            return
        }

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

        let isGoodEnough = entropy > PasswordQuality.minDatabasePasswordEntropy
        if isGoodEnough || hasKeyFile || hasYubiKey {
            successHandler()
            return
        }
        let confirmationAlert = UIAlertController.make(
            title: LString.titleWarning,
            message: LString.databasePasswordTooWeak,
            dismissButtonTitle: LString.actionCancel)
        confirmationAlert.addAction(title: LString.actionIgnoreAndContinue) { _ in
            successHandler()
        }
        present(confirmationAlert, animated: true)
    }

    @IBAction private func didPressSaveToFiles(_ sender: Any) {
        verifyEnteredKey(success: { [weak self] in
            guard let self else { return }
            delegate?.didPressSaveToFiles(in: self)
        })
    }

    @IBAction private func didPressSaveToServer(_ sender: Any) {
        verifyEnteredKey(success: { [weak self] in
            guard let self else { return }
            delegate?.didPressSaveToServer(in: self)
        })
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
            passwordField.quality = PasswordQuality(password: text)
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
            didPressSaveToFiles(textField)
        }
        return true
    }
}

extension LString {
    public static let orgRequiresStrongerDatabasePassword = NSLocalizedString(
        "[Database/Create/orgRequiresStronger]",
        value: "Your organization requires a more complex database password.",
        comment: "Notification for business users when they set up too weak database password.")
    public static let databasePasswordTooWeak = NSLocalizedString(
        "[Database/Create/weakPasswordWarning]",
        value: "This password is easy to guess. Try entering a stronger one.",
        comment: "Notification when user sets up too weak a database password.")
}
