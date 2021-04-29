//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseUnlockerDelegate: class {
    func didPressSelectKeyFile(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC)
    
    func didPressSelectHardwareKey(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC)
    
    func didPressUnlock(in viewController: DatabaseUnlockerVC)
    
    func didPressShowDiagnostics(
        at popoverAnchor: PopoverAnchor,
        in viewController: DatabaseUnlockerVC)
}

final class DatabaseUnlockerVC: UIViewController, Refreshable {

    @IBOutlet private weak var errorMessagePanel: UIView!
    @IBOutlet private weak var errorMessageLabel: UILabel!
    @IBOutlet private weak var errorDetailsButton: UIButton!
    @IBOutlet private weak var databaseLocationIconImage: UIImageView!
    @IBOutlet private weak var databaseFileNameLabel: UILabel!
    @IBOutlet private weak var inputPanel: UIView!
    @IBOutlet private weak var passwordField: ProtectedTextField!
    @IBOutlet private weak var keyFileField: KeyFileTextField!
    @IBOutlet private weak var announcementButton: UIButton!
    @IBOutlet private weak var unlockButton: UIButton!
    
    weak var delegate: DatabaseUnlockerDelegate?
    var shouldAutofocus = false
    var databaseRef: URLReference! {
        didSet { refresh() }
    }
    
    var password: String { return passwordField?.text ?? "" }
    private(set) var keyFileRef: URLReference?
    private(set) var yubiKey: YubiKey?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(patternImage: UIImage(asset: .backgroundPattern))
        view.layer.isOpaque = false
        unlockButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        errorMessagePanel.alpha = 0.0
        errorMessagePanel.isHidden = true
        
        refresh()
        
        passwordField.delegate = self
        keyFileField.delegate = self
        
        keyFileField.yubikeyHandler = {
            [weak self] (field, popoverAnchor) in
            guard let self = self else { return }
            self.delegate?.didPressSelectHardwareKey(at: popoverAnchor, in: self)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setToolbarHidden(true, animated: true)
        if shouldAutofocus {
            DispatchQueue.main.async { [weak self] in
                self?.passwordField?.becomeFirstResponder()
            }
        }
    }
    
    public func clearPasswordField() {
        passwordField.text = ""
    }
    
    func showErrorMessage(
        _ text: String,
        reason: String?=nil,
        suggestion: String?=nil,
        haptics: HapticFeedback.Kind?=nil
    ) {
        let text = [text, reason, suggestion]
            .compactMap { return $0 } 
            .joined(separator: "\n")
        errorMessageLabel.text = text
        Diag.error(text)
        UIAccessibility.post(notification: .announcement, argument: text)
        
        guard errorMessagePanel.isHidden else { return }

        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: .curveEaseIn,
            animations: {
                [weak self] in
                self?.errorMessagePanel.alpha = 1.0
                self?.errorMessagePanel.isHidden = false
            },
            completion: {
                [weak self] (finished) in
                self?.errorMessagePanel.shake()
                if let hapticsKind = haptics {
                    HapticFeedback.play(hapticsKind)
                }
            }
        )
        StoreReviewSuggester.registerEvent(.trouble)
    }
    
    func hideErrorMessage(animated: Bool) {
        guard !errorMessagePanel.isHidden else { return }

        if animated {
            UIView.animate(
                withDuration: 0.3,
                delay: 0.0,
                options: .curveEaseOut,
                animations: {
                    [weak self] in
                    self?.errorMessagePanel.alpha = 0.0
                    self?.errorMessagePanel.isHidden = true
                },
                completion: {
                    [weak self] (finished) in
                    self?.errorMessageLabel.text = " "
                }
            )
        } else {
            errorMessagePanel.alpha = 0.0
            errorMessagePanel.isHidden = true
            errorMessageLabel.text = " "
        }
    }

    func showMasterKeyInvalid(message: String) {
        showErrorMessage(message, haptics: .wrongPassword)
    }
    
    func maybeFocusOnPassword() {
        if !passwordField.isHidden {
            passwordField.becomeFirstResponder()
        }
    }
    
    func refresh() {
        guard isViewLoaded else { return }
        
        if let errorMessage = databaseRef.error?.localizedDescription {
            databaseFileNameLabel.text = errorMessage
            databaseFileNameLabel.textColor = UIColor.errorMessage
            databaseLocationIconImage.image = nil
        } else {
            databaseFileNameLabel.text = databaseRef.visibleFileName
            databaseFileNameLabel.textColor = UIColor.primaryText
            databaseLocationIconImage.image = databaseRef.getIcon(fileType: .database)
        }
        
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: databaseRef)
        if let associatedKeyFileRef = dbSettings?.associatedKeyFile {
            let allAvailableKeyFiles = FileKeeper.shared
                .getAllReferences(fileType: .keyFile, includeBackup: false)
            if let availableKeyFileRef = associatedKeyFileRef
                .find(in: allAvailableKeyFiles, fallbackToNamesake: true)
            {
                setKeyFile(availableKeyFileRef)
            }
        }

        if let associatedYubiKey = dbSettings?.associatedYubiKey {
            setYubiKey(associatedYubiKey)
        }
    }
    
    func setYubiKey(_ yubiKey: YubiKey?) {
        self.yubiKey = yubiKey
        keyFileField.isYubiKeyActive = (yubiKey != nil)

        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { (dbSettings) in
            dbSettings.maybeSetAssociatedYubiKey(yubiKey)
        }
        if let _yubiKey = yubiKey {
            Diag.info("Hardware key selected [key: \(_yubiKey)]")
        } else {
            Diag.info("No hardware key selected")
        }
    }
    
    func setKeyFile(_ fileRef: URLReference?) {
        self.keyFileRef = fileRef
        
        hideErrorMessage(animated: false)

        DatabaseSettingsManager.shared.updateSettings(for: databaseRef) { (dbSettings) in
            dbSettings.maybeSetAssociatedKeyFile(keyFileRef)
        }
        
        guard let keyFileRef = fileRef else {
            Diag.debug("No key file selected")
            keyFileField.text = ""
            return
        }
        if let errorDetails = keyFileRef.error?.localizedDescription {
            let errorMessage = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Database/Unlock] Key file error: %@",
                    value: "Key file error: %@",
                    comment: "Error message related to key file. [errorDetails: String]"),
                errorDetails)
            Diag.warning(errorMessage)
            showErrorMessage(errorMessage)
            keyFileField.text = ""
        } else {
            Diag.info("Key file set successfully")
            keyFileField.text = keyFileRef.visibleFileName
        }
    }
    
    
    @IBAction func didPressErrorDetailsButton(_ sender: UIButton) {
        Watchdog.shared.restart()
        let popoverAnchor = PopoverAnchor(sourceView: sender, sourceRect: sender.bounds)
        delegate?.didPressShowDiagnostics(at: popoverAnchor, in: self)
    }
    
    @IBAction func didPressUnlock(_ sender: Any) {
        Watchdog.shared.restart()
        passwordField.resignFirstResponder()
        delegate?.didPressUnlock(in: self)
    }
}

extension DatabaseUnlockerVC: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        Watchdog.shared.restart()
        if textField === keyFileField {
            passwordField.becomeFirstResponder()
            let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
            delegate?.didPressSelectKeyFile(at: popoverAnchor, in: self)
            return false 
        }
        return true
    }
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String) -> Bool
    {
        hideErrorMessage(animated: true)
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === passwordField {
            didPressUnlock(textField)
            return false
        }
        return true 
    }
}
