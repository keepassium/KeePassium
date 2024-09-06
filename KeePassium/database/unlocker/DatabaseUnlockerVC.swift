//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseUnlockerDelegate: AnyObject {
    func shouldDismissFromKeyboard(_ viewController: DatabaseUnlockerVC) -> Bool
    func willAppear(viewController: DatabaseUnlockerVC)

    func didPressSelectKeyFile(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC)
    func didPressSelectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC)
    func shouldDismissPopovers(in viewController: DatabaseUnlockerVC)

    func canUnlockAutomatically(_ viewController: DatabaseUnlockerVC) -> Bool
    func didPressUnlock(in viewController: DatabaseUnlockerVC)
    func didPressLock(in viewController: DatabaseUnlockerVC)

    func didPressShowDiagnostics(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC)
}

final class DatabaseUnlockerVC: UIViewController, Refreshable {
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var databaseLocationIconImage: UIImageView!
    @IBOutlet private weak var databaseFileNameLabel: UILabel!
    @IBOutlet private weak var errorMessageView: ErrorMessageView!
    @IBOutlet private weak var inputPanel: UIView!
    @IBOutlet private weak var fakeUserNameField: UITextField!
    @IBOutlet private weak var passwordField: ProtectedTextField!
    @IBOutlet private weak var keyFileField: ValidatingTextField!
    @IBOutlet private weak var hardwareKeyField: ValidatingTextField!
    @IBOutlet private weak var unlockButton: UIButton!
    @IBOutlet private weak var masterKeyKnownLabel: UILabel!
    @IBOutlet private weak var lockDatabaseButton: UIButton!

    weak var delegate: DatabaseUnlockerDelegate?
    var shouldAutofocus = false
    var databaseRef: URLReference! {
        didSet {
            guard isViewLoaded else { return }
            hideErrorMessage(animated: false)
            refresh()
            maybeFocusOnPassword()
        }
    }

    var password: String { return passwordField?.text ?? "" }
    private(set) var keyFileRef: URLReference?
    private(set) var yubiKey: YubiKey?

    private var progressOverlay: ProgressOverlay?

    override var canDismissFromKeyboard: Bool {
        return delegate?.shouldDismissFromKeyboard(self) ?? false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = ImageAsset.backgroundPattern.asColor()
        view.layer.isOpaque = false
        unlockButton.titleLabel?.adjustsFontForContentSizeCategory = true

        passwordField.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        keyFileField.maskedCorners = []
        hardwareKeyField.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]

        #if targetEnvironment(macCatalyst)
        keyFileField.cursor = .arrow
        hardwareKeyField.cursor = .arrow
        #endif

        errorMessageView.isHidden = true

        refresh()

        fakeUserNameField.delegate = self
        passwordField.delegate = self
        keyFileField.delegate = self
        hardwareKeyField.delegate = self

        hardwareKeyField.placeholder = LString.noHardwareKey

        passwordField.accessibilityLabel = LString.fieldPassword
        keyFileField.accessibilityLabel = LString.fieldKeyFile
        hardwareKeyField.accessibilityLabel = LString.fieldHardwareKey

        setKeyFile(keyFileRef)
        setYubiKey(yubiKey)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearPasswordField()
        delegate?.willAppear(viewController: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        if shouldAutofocus {
            UIAccessibility.post(notification: .layoutChanged, argument: passwordField)
            maybeFocusOnPassword()
        }
    }

    public func clearPasswordField() {
        passwordField.text = ""
    }

    func showErrorMessage(
        _ text: String,
        reason: String? = nil,
        helpAnchor: String? = nil,
        haptics: HapticFeedback.Kind? = nil,
        action: ErrorMessageView.Action? = nil
    ) {
        guard isViewLoaded else { return }
        let text = [text, reason]
            .compactMap { $0 } 
            .joined(separator: "\n")
        Diag.error(text)

        if let haptics {
            HapticFeedback.play(haptics)
        }
        errorMessageView.message = text
        if let action {
            errorMessageView.action = action
        } else if let helpAnchor, let helpURL = URL(string: helpAnchor) {
            errorMessageView.action = .init(title: LString.actionViewHelpArticle) { [weak self] in
                guard let self else { return }
                URLOpener(self).open(url: helpURL)
            }
        }
        errorMessageView.show(animated: true)
        UIAccessibility.post(notification: .screenChanged, argument: errorMessageView)

        StoreReviewSuggester.registerEvent(.trouble)
        scrollView.setContentOffset(.zero, animated: true)
    }

    func hideErrorMessage(animated: Bool) {
        guard isViewLoaded else { return }

        errorMessageView.hide(animated: animated)
        UIAccessibility.post(notification: .screenChanged, argument: self.view)
    }

    func showMasterKeyInvalid(message: String) {
        showErrorMessage(
            message,
            haptics: .wrongPassword,
            action: .init(
                title: LString.forgotPasswordQuestion,
                isLink: true,
                handler: { [weak self] in
                    self?.showInvalidPasswordHelp()
                }
            )
        )
        errorMessageView.shake()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.maybeFocusOnPassword()
        }
    }

    private func showInvalidPasswordHelp() {
        let urlOpener = URLOpener(self)
        urlOpener.open(url: URL.AppHelp.invalidDatabasePassword) { [weak self] didOpen in
            if !didOpen {
                self?.didPressErrorDetails()
            }
        }
    }

    func maybeFocusOnPassword() {
        guard progressOverlay == nil else {
            return 
        }
        if !inputPanel.isHidden {
            passwordField.becomeFirstResponderWhenSafe()
        }
    }

    func refresh() {
        guard isViewLoaded else { return }

        databaseFileNameLabel.text = databaseRef.visibleFileName
        databaseFileNameLabel.textColor = UIColor.primaryText
        let locationSymbol = databaseRef.getIconSymbol(fileType: .database)
        databaseLocationIconImage.image = .symbol(locationSymbol)
        refreshInputMode()
    }

    private func refreshInputMode() {
        let canUnlockAutomatically = delegate?.canUnlockAutomatically(self) ?? false
        let shouldInputMasterKey = !canUnlockAutomatically

        masterKeyKnownLabel.isHidden = shouldInputMasterKey
        lockDatabaseButton.isHidden = shouldInputMasterKey
        inputPanel.isHidden = !shouldInputMasterKey
    }

    func setYubiKey(_ yubiKey: YubiKey?) {
        self.yubiKey = yubiKey
        guard isViewLoaded else {
            return
        }

        if let yubiKey = yubiKey {
            hardwareKeyField.text = YubiKey.getTitle(for: yubiKey)
            Diag.info("Hardware key selected [key: \(yubiKey)]")
        } else {
            hardwareKeyField.text = nil // shows "No Hardware Key" placeholder
            Diag.info("No hardware key selected")
        }
    }

    func setKeyFile(_ fileRef: URLReference?) {
        self.keyFileRef = fileRef
        guard isViewLoaded else {
            return
        }

        keyFileField.text = keyFileRef?.visibleFileName

        hideErrorMessage(animated: false)
        if let keyFileRef = fileRef {
            Diag.info("Key file set successfully")
            if let errorDetails = keyFileRef.error?.localizedDescription {
                let errorMessage = String.localizedStringWithFormat(
                    LString.keyFileErrorTemplate,
                    errorDetails)
                Diag.warning(errorMessage)
                showErrorMessage(errorMessage)
                keyFileField.text = ""
            }
        } else {
            Diag.debug("No key file selected")
        }
    }


    private func didPressErrorDetails() {
        Watchdog.shared.restart()
        hideErrorMessage(animated: true)
        let popoverAnchor = PopoverAnchor(sourceView: inputPanel, sourceRect: inputPanel.bounds)
        delegate?.didPressShowDiagnostics(at: popoverAnchor, in: self)
    }

    @IBAction private func didPressUnlock(_ sender: Any) {
        Watchdog.shared.restart()
        passwordField.resignFirstResponder()
        delegate?.didPressUnlock(in: self)
    }

    @IBAction private func didPressLockDatabase(_ sender: UIButton) {
        Watchdog.shared.restart()
        delegate?.didPressLock(in: self)
        refreshInputMode()
    }
}

extension DatabaseUnlockerVC: UITextFieldDelegate {

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        Watchdog.shared.restart()
        guard textField !== fakeUserNameField else {
            return false
        }

        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return true
        }
        let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
        switch textField {
        case keyFileField:
            hideErrorMessage(animated: true)
            delegate?.didPressSelectKeyFile(at: popoverAnchor, in: self)
            return false 
        case hardwareKeyField:
            hideErrorMessage(animated: true)
            delegate?.didPressSelectHardwareKey(at: popoverAnchor, in: self)
            return false 
        default:
            break
        }
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        Watchdog.shared.restart()
        guard UIDevice.current.userInterfaceIdiom != .phone else {
            return
        }
        let isMac = ProcessInfo.isRunningOnMac
        let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
        switch textField {
        case keyFileField:
            hideErrorMessage(animated: true)
            delegate?.didPressSelectKeyFile(at: popoverAnchor, in: self)
            if isMac {
                passwordField.becomeFirstResponder()
            }
        case hardwareKeyField:
            hideErrorMessage(animated: true)
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
        Watchdog.shared.restart()
        hideErrorMessage(animated: true)
        if textField === keyFileField || textField === hardwareKeyField {
            return false
        }
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        Watchdog.shared.restart()
        if textField === passwordField {
            didPressUnlock(textField)
            return false
        }
        return true 
    }
}

extension DatabaseUnlockerVC: ProgressViewHost {
    public func showProgressView(title: String, allowCancelling: Bool, animated: Bool) {
        if progressOverlay != nil {
            progressOverlay?.title = title
            progressOverlay?.isCancellable = allowCancelling
            return
        }
        progressOverlay = ProgressOverlay.addTo(
            view,
            title: title,
            animated: animated)
        progressOverlay?.isCancellable = allowCancelling
        progressOverlay?.unresponsiveCancelHandler = { [weak self] in
            guard let self = self else { return }
            let popoverAnchor = PopoverAnchor(sourceView: self.view, sourceRect: self.view.bounds)
            self.delegate?.didPressShowDiagnostics(at: popoverAnchor, in: self)
        }

        navigationItem.setHidesBackButton(true, animated: animated)
    }

    public func updateProgressView(with progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }

    public func hideProgressView(animated: Bool) {
        guard progressOverlay != nil else { return }
        navigationItem.setHidesBackButton(false, animated: animated)
        progressOverlay?.dismiss(animated: animated) { [weak self] _ in
            guard let self = self else { return }
            self.progressOverlay?.removeFromSuperview()
            self.progressOverlay = nil
        }
    }
}
