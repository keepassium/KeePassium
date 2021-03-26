//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseUnlockerDelegate: class {
    func databaseUnlockerShouldUnlock(
        _ sender: DatabaseUnlockerVC,
        database: URLReference,
        password: String,
        keyFile: URLReference?,
        yubiKey: YubiKey?)
    func didPressNewsItem(in databaseUnlocker: DatabaseUnlockerVC, newsItem: NewsItem)
    func didPressSelectKeyFile(
        in databaseUnlocker: DatabaseUnlockerVC,
        at popoverAnchor: PopoverAnchor)
    func didPressSelectHardwareKey(
        in databaseUnlocker: DatabaseUnlockerVC,
        at popoverAnchor: PopoverAnchor)
    func didPressShowDiagnostics(
        in databaseUnlocker: DatabaseUnlockerVC,
        at popoverAnchor: PopoverAnchor)
}

class DatabaseUnlockerVC: UIViewController, Refreshable {

    @IBOutlet weak var errorMessagePanel: UIView!
    @IBOutlet weak var errorMessageLabel: UILabel!
    @IBOutlet weak var errorDetailsButton: UIButton!
    @IBOutlet weak var databaseLocationIconImage: UIImageView!
    @IBOutlet weak var databaseFileNameLabel: UILabel!
    @IBOutlet weak var inputPanel: UIView!
    @IBOutlet weak var passwordField: ProtectedTextField!
    @IBOutlet weak var keyFileField: KeyFileTextField!
    @IBOutlet weak var announcementButton: UIButton!
    @IBOutlet weak var unlockButton: UIButton!
    
    weak var delegate: DatabaseUnlockerDelegate?
    var shouldAutofocus = false
    var databaseRef: URLReference? {
        didSet { refresh() }
    }
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
            [weak self] (field) in
            guard let self = self else { return }
            let popoverAnchor = PopoverAnchor(
                sourceView: self.keyFileField,
                sourceRect: self.keyFileField.bounds)
            self.delegate?.didPressSelectHardwareKey(in: self, at: popoverAnchor)
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
    
    func refresh() {
        guard isViewLoaded else { return }
        refreshNews()
        
        guard let dbRef = databaseRef else {
            databaseLocationIconImage.image = nil
            databaseFileNameLabel.text = ""
            return
        }
        if let errorMessage = dbRef.error?.localizedDescription {
            databaseFileNameLabel.text = errorMessage
            databaseFileNameLabel.textColor = UIColor.errorMessage
            databaseLocationIconImage.image = nil
        } else {
            databaseFileNameLabel.text = dbRef.visibleFileName
            databaseFileNameLabel.textColor = UIColor.primaryText
            databaseLocationIconImage.image = dbRef.getIcon(fileType: .database)
        }
        
        let dbSettings = DatabaseSettingsManager.shared.getSettings(for: dbRef)
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

        guard let databaseRef = databaseRef else { assertionFailure(); return }
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

        guard let databaseRef = databaseRef else { return }
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
    
    private(set) var progressOverlay: ProgressOverlay?

    public func showProgressOverlay(animated: Bool) {
        guard progressOverlay == nil else {
            progressOverlay?.title = LString.databaseStatusLoading
            return
        }
        navigationItem.hidesBackButton = true
        progressOverlay = ProgressOverlay.addTo(
            self.view,
            title: LString.databaseStatusLoading,
            animated: animated)
    }
    
    public func updateProgress(with progress: ProgressEx) {
        progressOverlay?.update(with: progress)
    }
    
    public func hideProgressOverlay() {
        navigationItem.hidesBackButton = false
        progressOverlay?.dismiss(animated: true) {
            [weak self] (finished) in
            guard finished, let _self = self else { return }
            _self.progressOverlay?.removeFromSuperview()
            _self.progressOverlay = nil
        }
    }

    
    
    private var newsItem: NewsItem?
    
    private func refreshNews() {
        let nc = NewsCenter.shared
        if let newsItem = nc.getTopItem() {
            announcementButton.titleLabel?.numberOfLines = 0
            announcementButton.setTitle(newsItem.title, for: .normal)
            announcementButton.isHidden = false
            self.newsItem = newsItem
        } else {
            announcementButton.isHidden = true
            self.newsItem = nil
        }
    }
    
    
    @IBAction func didPressErrorDetailsButton(_ sender: UIButton) {
        Watchdog.shared.restart()
        let popoverAnchor = PopoverAnchor(sourceView: sender, sourceRect: sender.bounds)
        delegate?.didPressShowDiagnostics(in: self, at: popoverAnchor)
    }
    
    @IBAction func didPressUnlock(_ sender: Any) {
        Watchdog.shared.restart()
        guard let databaseRef = databaseRef else { return }
        delegate?.databaseUnlockerShouldUnlock(
            self,
            database: databaseRef,
            password: passwordField.text ?? "",
            keyFile: keyFileRef,
            yubiKey: yubiKey)
    }
    
    @IBAction func didPressAnouncementButton(_ sender: Any) {
        guard let newsItem = newsItem else { return }
        delegate?.didPressNewsItem(in: self, newsItem: newsItem)
    }
}

extension DatabaseUnlockerVC: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        Watchdog.shared.restart()
        if textField === keyFileField {
            passwordField.becomeFirstResponder()
            let popoverAnchor = PopoverAnchor(sourceView: textField, sourceRect: textField.bounds)
            delegate?.didPressSelectKeyFile(in: self, at: popoverAnchor)
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
