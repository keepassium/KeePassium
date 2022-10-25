//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import Foundation

protocol RemoteFilePickerDelegate: AnyObject {
    func didPressSelectConnectionType(
        at popoverAnchor: PopoverAnchor,
        in viewController: RemoteFilePickerVC
    )
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: RemoteFilePickerVC
    )
    func didPressLoginToOneDrive(privateSession: Bool, in viewController: RemoteFilePickerVC)
}

final class RemoteFilePickerVC: UITableViewController {
    private enum CellID {
        static let selectorCell = "SelectorCell"
        static let textFieldCell = "TextFieldCell"
        static let switchCell = "SwitchCell"
        static let buttonCell = "ButtonCell"
    }
    private enum CellIndex {
        static let commonSectionCount = 1
        static let typeSelector = IndexPath(row: 0, section: 0)
        
        static let webdavSectionSizes = [0, 2, 2] 
        static let webdavURL = IndexPath(row: 0, section: 1)
        static let webdavAllowUntrusted = IndexPath(row: 1, section: 1)
        static let webdavUsername = IndexPath(row: 0, section: 2)
        static let webdavPassword = IndexPath(row: 1, section: 2)
        
        static let oneDriveSectionSizes = [0, 2] 
        static let oneDrivePrivateSession = IndexPath(row: 0, section: 1)
        static let oneDriveLogin = IndexPath(row: 1, section: 1)
    }
    
    weak var delegate: RemoteFilePickerDelegate?
    
    public var webdavURL: URL?
    public var webdavUsername: String = ""
    public var webdavPassword: String = ""
    public var allowUntrustedCertificate = false
    public var oneDrivePrivateSession = false
    
    private var isBusy = false

    private lazy var titleView: SpinnerLabel = {
        let view = SpinnerLabel(frame: .zero)
        view.label.text = LString.titleRemoteConnection
        view.label.font = .preferredFont(forTextStyle: .headline)
        view.spinner.startAnimating()
        return view
    }()
    private var doneButton: UIBarButtonItem! 

    public var connectionType: RemoteConnectionType = .webdav {
        didSet { refresh() }
    }
    private weak var webdavURLTextField: ValidatingTextField?
    private weak var webdavUsernameTextField: ValidatingTextField?
    private weak var webdavPasswordTextField: ValidatingTextField?

    
    public static func make() -> RemoteFilePickerVC {
        return RemoteFilePickerVC.init(style: .insetGrouped)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = titleView
        
        tableView.register(
            SwitchCell.classForCoder(),
            forCellReuseIdentifier: CellID.switchCell)
        tableView.register(
            TextFieldCell.classForCoder(),
            forCellReuseIdentifier: CellID.textFieldCell)
        tableView.register(
            RightDetailCell.classForCoder(),
            forCellReuseIdentifier: CellID.selectorCell)
        tableView.register(
            ButtonCell.classForCoder(),
            forCellReuseIdentifier: CellID.buttonCell)
        tableView.alwaysBounceVertical = false
        setupDoneButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        switch connectionType {
        case .webdav:
            populateWebDAVControls()
            DispatchQueue.main.async {
                self.webdavURLTextField?.becomeFirstResponder()
            }
        case .oneDrive, .oneDriveForBusiness:
            break
        }
    }
    
    private func populateWebDAVControls() {
        webdavUsernameTextField?.text = webdavUsername
        webdavPasswordTextField?.text = webdavPassword
        
        setWebdavInputURL(fromText: webdavURL?.absoluteString ?? "")
    }
    
    private func setupDoneButton() {
        doneButton = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction() { [weak self] _ in
                self?.didPressDone()
            },
            menu: nil)
        navigationItem.rightBarButtonItem = doneButton
    }
    
    public func setState(isBusy: Bool) {
        titleView.showSpinner(isBusy, animated: true)
        self.isBusy = isBusy
        refresh()
    }
    
    private func refresh() {
        tableView.reloadData()
        refreshDoneButton()
    }
    
    private func refreshDoneButton() {
        guard isViewLoaded else { return }
        switch connectionType {
        case .webdav:
            doneButton.isEnabled = (webdavURL != nil) && !isBusy
        case .oneDrive, .oneDriveForBusiness:
            doneButton.isEnabled = false 
        }
    }
    
    private func didPressDone() {
        guard doneButton.isEnabled else {
            return
        }
        switch connectionType {
        case .webdav:
            delegate?.didPressDone(
                nakedWebdavURL: webdavURL!,
                credential: NetworkCredential(
                    username: webdavUsername,
                    password: webdavPassword,
                    allowUntrustedCertificate: allowUntrustedCertificate
                ),
                in: self
            )
        case .oneDrive, .oneDriveForBusiness:
            assertionFailure("Done button was enabled for OneDrive connection?")
            break
        }
    }
}

extension RemoteFilePickerVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        switch connectionType {
        case .webdav:
            return CellIndex.webdavSectionSizes.count
        case .oneDrive, .oneDriveForBusiness:
            return CellIndex.oneDriveSectionSizes.count
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (connectionType, section) {
        case (_, CellIndex.typeSelector.section): 
            return 1
        case (.webdav, _):
            return CellIndex.webdavSectionSizes[section]
        case (.oneDrive, _),
             (.oneDriveForBusiness, _):
            return CellIndex.oneDriveSectionSizes[section]
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch (connectionType, section) {
        case (.webdav, CellIndex.webdavURL.section):
            return LString.titleFileURL
        case (.webdav, CellIndex.webdavUsername.section):
            return LString.titleCredentials
        default:
            return nil
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: getReusableCellID(for: indexPath),
            for: indexPath
        )
        resetCellStyle(cell)
        switch (connectionType, indexPath.section) {
        case (_, CellIndex.typeSelector.section):
            configureConnectionTypeSelectorCell(cell as! RightDetailCell)
        case (.webdav, _):
            configureWebdavConnectionCell(cell, at: indexPath)
        case (.oneDrive, _),
             (.oneDriveForBusiness, _):
            configureOneDriveConnectionCell(cell, at: indexPath)
        }
        return cell
    }
    
    private func getReusableCellID(for indexPath: IndexPath) -> String {
        switch (connectionType, indexPath) {
        case (_, CellIndex.typeSelector):
            return CellID.selectorCell
        case (.webdav, CellIndex.webdavURL),
            (.webdav, CellIndex.webdavUsername),
            (.webdav, CellIndex.webdavPassword):
            return CellID.textFieldCell
        case (.webdav, CellIndex.webdavAllowUntrusted):
            return CellID.switchCell
        case (.oneDrive, CellIndex.oneDriveLogin),
             (.oneDriveForBusiness, CellIndex.oneDriveLogin):
            return CellID.buttonCell
        case (.oneDrive, CellIndex.oneDrivePrivateSession),
             (.oneDriveForBusiness, CellIndex.oneDrivePrivateSession):
            return CellID.switchCell
        default:
            fatalError("Unexpected cell index")
        }
    }
    
    private func resetCellStyle(_ cell: UITableViewCell) {
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.textColor = .primaryText
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
        cell.detailTextLabel?.textColor = .auxiliaryText
        cell.imageView?.image = nil
        cell.accessoryType = .none
        
        cell.textLabel?.accessibilityLabel = nil
        cell.detailTextLabel?.accessibilityLabel = nil
        cell.accessibilityTraits = []
        cell.accessibilityValue = nil
        cell.accessibilityHint = nil
    }
    
    private func configureConnectionTypeSelectorCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .default
        cell.textLabel?.text = LString.titleConnection
        cell.detailTextLabel?.text = connectionType.description
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
        cell.accessoryType = .disclosureIndicator
    }
}

extension RemoteFilePickerVC {
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        switch indexPath {
        case CellIndex.typeSelector:
            return indexPath
        default:
            return nil
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.typeSelector:
            tableView.deselectRow(at: indexPath, animated: true)
            let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
            delegate?.didPressSelectConnectionType(at: popoverAnchor, in: self)
        default:
            break
        }
    }
}

extension RemoteFilePickerVC {
    private func configureWebdavConnectionCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.webdavURL:
            configureWebdavURLCell(cell as! TextFieldCell)
        case CellIndex.webdavAllowUntrusted:
            configureWebdavAllowUntrustedCell(cell as! SwitchCell)
        case CellIndex.webdavUsername:
            configureWebdavUsernameCell(cell as! TextFieldCell)
        case CellIndex.webdavPassword:
            configureWebdavPasswordCell(cell as! TextFieldCell)
        default:
            fatalError("Unexpected cell index")
        }
    }
    
    private func configureWebdavURLCell(_ cell: TextFieldCell) {
        cell.textField.placeholder = "https://host:port/path/file.kdbx"
        cell.textField.textContentType = .URL
        cell.textField.isSecureTextEntry = false
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        cell.textField.keyboardType = .URL
        cell.textField.clearButtonMode = .whileEditing
        cell.textField.returnKeyType = .next
        cell.textField.borderWidth = 0

        webdavURLTextField = cell.textField
        webdavURLTextField?.delegate = self
        webdavURLTextField?.validityDelegate = self
        webdavURLTextField?.text = webdavURL?.absoluteString
    }
    
    private func configureWebdavAllowUntrustedCell(_ cell: SwitchCell) {
        cell.textLabel?.text = LString.titleAllowUntrustedCertificate
        cell.detailTextLabel?.text = nil
        cell.theSwitch.isOn = allowUntrustedCertificate
        cell.onDidToggleSwitch = { [weak self] theSwitch in
            self?.allowUntrustedCertificate = theSwitch.isOn
        }
    }
    
    private func configureWebdavUsernameCell(_ cell: TextFieldCell) {
        cell.textField.placeholder = LString.fieldUserName
        cell.textField.textContentType = .username
        cell.textField.isSecureTextEntry = false
        cell.textField.autocapitalizationType = .none
        cell.textField.autocorrectionType = .no
        cell.textField.keyboardType = .emailAddress
        cell.textField.clearButtonMode = .whileEditing
        cell.textField.returnKeyType = .next
        cell.textField.borderWidth = 0

        webdavUsernameTextField = cell.textField
        webdavUsernameTextField?.delegate = self
        webdavUsernameTextField?.validityDelegate = self
        webdavUsernameTextField?.text = webdavUsername
    }
    
    private func configureWebdavPasswordCell(_ cell: TextFieldCell) {
        cell.textField.placeholder = LString.fieldPassword
        cell.textField.textContentType = .password
        cell.textField.isSecureTextEntry = true
        cell.textField.keyboardType = .default
        cell.textField.clearButtonMode = .whileEditing
        cell.textField.returnKeyType = .continue
        cell.textField.borderWidth = 0

        webdavPasswordTextField = cell.textField
        webdavPasswordTextField?.delegate = self
        webdavPasswordTextField?.validityDelegate = self
        webdavPasswordTextField?.text = webdavPassword
    }
    
    private func setWebdavInputURL(fromText text: String) {
        guard var urlComponents = URLComponents(string: text),
              (urlComponents.scheme?.isNotEmpty ?? false),
              (urlComponents.host?.isNotEmpty ?? false),
              urlComponents.path.count > 1,
              let inputURL = urlComponents.url
        else { 
            self.webdavURL = nil
            refreshDoneButton()
            return
        }
        
        let inputURLScheme = inputURL.scheme ?? ""
        guard WebDAVFileURL.schemes.contains(inputURLScheme) else {
            self.webdavURL = nil
            refreshDoneButton()
            return
        }
        
        if let urlUser = urlComponents.user {
            webdavUsername = urlUser
            webdavUsernameTextField?.text = urlUser
        }
        if let urlPassword = urlComponents.password {
            webdavPassword = urlPassword
            webdavPasswordTextField?.text = urlPassword
        }
        urlComponents.user = nil
        urlComponents.password = nil
        self.webdavURL = urlComponents.url
        webdavURLTextField?.text = self.webdavURL?.absoluteString ?? text
        
        refreshDoneButton()
    }
}

extension RemoteFilePickerVC {
    private func configureOneDriveConnectionCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.oneDriveLogin:
            configureOneDriveLoginCell(cell as! ButtonCell)
        case CellIndex.oneDrivePrivateSession:
            configureOneDrivePrivateSessionCell(cell as! SwitchCell)
        default:
            fatalError("Unexpected cell index")
        }
    }
    
    private func configureOneDriveLoginCell(_ cell: ButtonCell) {
        cell.button.setTitle(LString.actionSignInToOneDrive, for: .normal)
        cell.button.contentHorizontalAlignment = .leading
        cell.button.isEnabled = !isBusy
        cell.buttonPressHandler = { [weak self] theSwitch in
            guard let self = self else { return }
            self.delegate?.didPressLoginToOneDrive(
                privateSession: self.oneDrivePrivateSession,
                in: self
            )
        }
    }
    
    private func configureOneDrivePrivateSessionCell(_ cell: SwitchCell) {
        cell.textLabel?.text = LString.titlePrivateBrowserMode
        cell.detailTextLabel?.text = LString.descriptionPrivateBrowserMode
        
        cell.theSwitch.isOn = oneDrivePrivateSession
        cell.onDidToggleSwitch = { [weak self] theSwitch in
            self?.oneDrivePrivateSession = theSwitch.isOn
            self?.tableView.reloadSections([CellIndex.oneDrivePrivateSession.section], with: .automatic)
        }
    }
}

extension RemoteFilePickerVC: ValidatingTextFieldDelegate, UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case webdavURLTextField:
            webdavUsernameTextField?.becomeFirstResponder()
            return false
        case webdavUsernameTextField:
            webdavPasswordTextField?.becomeFirstResponder()
            return false
        case webdavPasswordTextField:
            didPressDone()
            return false
        default:
            return true 
        }
    }
    
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {
        switch sender {
        case webdavURLTextField:
            setWebdavInputURL(fromText: text)
        case webdavUsernameTextField:
            self.webdavUsername = text
        case webdavPasswordTextField:
            self.webdavPassword = text
        default:
            return
        }
    }
}
