//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol WebDAVConnectionSetupVCDelegate: AnyObject {
    func didPressDone(
        nakedWebdavURL: URL,
        credential: NetworkCredential,
        in viewController: WebDAVConnectionSetupVC
    )
}

final class WebDAVConnectionSetupVC: UITableViewController {
    private enum CellID {
        static let textFieldCell = "TextFieldCell"
        static let protectedTextFieldCell = "ProtectedTextFieldCell"
        static let switchCell = "SwitchCell"
        static let buttonCell = "ButtonCell"
    }
    private enum CellIndex {
        static let sectionSizes = [2, 2]
        static let url = IndexPath(row: 0, section: 0)
        static let allowUntrusted = IndexPath(row: 1, section: 0)
        static let username = IndexPath(row: 0, section: 1)
        static let password = IndexPath(row: 1, section: 1)
    }

    weak var delegate: WebDAVConnectionSetupVCDelegate?

    public var webdavURL: URL?
    public var webdavUsername: String = ""
    public var webdavPassword: String = ""
    public var allowUntrustedCertificate = false

    private var isBusy = false

    private lazy var titleView: SpinnerLabel = {
        let view = SpinnerLabel(frame: .zero)
        view.label.text = LString.titleRemoteConnection
        view.label.font = .preferredFont(forTextStyle: .headline)
        view.spinner.startAnimating()
        return view
    }()
    private var doneButton: UIBarButtonItem! 

    private weak var webdavURLTextField: ValidatingTextField?
    private weak var webdavUsernameTextField: ValidatingTextField?
    private weak var webdavPasswordTextField: ValidatingTextField?

    public static func make() -> Self {
        return Self(style: .insetGrouped)
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
            ProtectedTextFieldCell.classForCoder(),
            forCellReuseIdentifier: CellID.protectedTextFieldCell)
        tableView.register(
            ButtonCell.classForCoder(),
            forCellReuseIdentifier: CellID.buttonCell)
        tableView.alwaysBounceVertical = false
        setupDoneButton()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
        populateWebDAVControls()
        DispatchQueue.main.async {
            self.webdavURLTextField?.becomeFirstResponder()
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
            primaryAction: UIAction { [weak self] _ in
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
        titleView.label.text = RemoteConnectionType.webdav.description
        tableView.reloadData()
        refreshDoneButton()
    }

    private func refreshDoneButton() {
        guard isViewLoaded else { return }
        doneButton.isEnabled = (webdavURL != nil) && !isBusy
    }

    private func didPressDone() {
        guard doneButton.isEnabled else {
            return
        }
        delegate?.didPressDone(
            nakedWebdavURL: webdavURL!,
            credential: NetworkCredential(
                username: webdavUsername,
                password: webdavPassword,
                allowUntrustedCertificate: allowUntrustedCertificate
            ),
            in: self
        )
    }
}

extension WebDAVConnectionSetupVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return CellIndex.sectionSizes.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return CellIndex.sectionSizes[section]
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch section {
        case CellIndex.url.section:
            return LString.titleFileURL
        case CellIndex.username.section:
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
        configureWebdavConnectionCell(cell, at: indexPath)
        return cell
    }

    private func getReusableCellID(for indexPath: IndexPath) -> String {
        switch indexPath {
        case CellIndex.url,
             CellIndex.username:
            return CellID.textFieldCell
        case CellIndex.password:
            return CellID.protectedTextFieldCell
        case CellIndex.allowUntrusted:
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
}

extension WebDAVConnectionSetupVC {
    private func configureWebdavConnectionCell(_ cell: UITableViewCell, at indexPath: IndexPath) {
        switch indexPath {
        case CellIndex.url:
            configureWebdavURLCell(cell as! TextFieldCell)
        case CellIndex.allowUntrusted:
            configureWebdavAllowUntrustedCell(cell as! SwitchCell)
        case CellIndex.username:
            configureWebdavUsernameCell(cell as! TextFieldCell)
        case CellIndex.password:
            configureWebdavPasswordCell(cell as! ProtectedTextFieldCell)
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
              urlComponents.scheme?.isNotEmpty ?? false,
              urlComponents.host?.isNotEmpty ?? false,
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

        var inputTextNeedsUpdate = false
        if let urlUser = urlComponents.user {
            webdavUsername = urlUser
            webdavUsernameTextField?.text = urlUser
            inputTextNeedsUpdate = true
        }
        if let urlPassword = urlComponents.password {
            webdavPassword = urlPassword
            webdavPasswordTextField?.text = urlPassword
            inputTextNeedsUpdate = true
        }
        urlComponents.user = nil
        urlComponents.password = nil
        self.webdavURL = urlComponents.url
        if inputTextNeedsUpdate {
            webdavURLTextField?.text = self.webdavURL?.absoluteString ?? text
        }

        refreshDoneButton()
    }
}

extension WebDAVConnectionSetupVC: ValidatingTextFieldDelegate, UITextFieldDelegate {
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
