//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import Foundation

public enum RemoteConnectionType: CustomStringConvertible {
    case webdav
    
    public var description: String {
        switch self {
        case .webdav:
            return LString.connectionTypeWebDAV
        }
    }
}

protocol RemoteFilePickerDelegate: AnyObject {
    func didPressDone(
        url: URL,
        credential: NetworkCredential,
        in viewController: RemoteFilePickerVC
    )
}

final class RemoteFilePickerVC: UITableViewController {
    private enum CellID {
        static let selectorCell = "SelectorCell"
        static let textFieldCell = "TextFieldCell"
        static let switchCell = "SwitchCell"
    }
    private enum CellIndex {
        static let commonSectionCount = 1
        static let typeSelector = IndexPath(row: 0, section: 0)
        
        static let webdavSectionCount = 2
        static let webdavSectionSizes = [0, 2, 2] 
        static let webdavURL = IndexPath(row: 0, section: 1)
        static let webdavAllowUntrusted = IndexPath(row: 1, section: 1)
        static let webdavUsername = IndexPath(row: 0, section: 2)
        static let webdavPassword = IndexPath(row: 1, section: 2)
    }
    
    weak var delegate: RemoteFilePickerDelegate?
    
    public var url: URL?
    public var username: String = ""
    public var password: String = ""
    public var allowUntrustedCertificate = false
    
    private lazy var titleView: SpinnerLabel = {
        let view = SpinnerLabel(frame: .zero)
        view.label.text = LString.titleRemoteConnection
        view.label.font = .preferredFont(forTextStyle: .headline)
        view.spinner.startAnimating()
        return view
    }()
    private var doneButton: UIBarButtonItem! 
    
    private var connectionType: RemoteConnectionType = .webdav
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
        tableView.alwaysBounceVertical = false
        setupDoneButton()
        refresh()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        populateControls()
        refresh()
        webdavURLTextField?.becomeFirstResponder()
    }
    
    private func populateControls() {
        webdavUsernameTextField?.text = username
        webdavPasswordTextField?.text = password
        
        setWebdavInputURL(fromText: url?.absoluteString ?? "")
    }
    
    private func setupDoneButton() {
        doneButton = UIBarButtonItem(
            systemItem: .done,
            primaryAction: UIAction() { [weak self] _ in
                self?.webdavDidPressDone()
            },
            menu: nil)
        navigationItem.rightBarButtonItem = doneButton
    }
    
    public func showBusy(_ isBusy: Bool) {
        doneButton.isEnabled = !isBusy
        titleView.showSpinner(isBusy, animated: true)
    }
    
    private func refresh() {
        doneButton.isEnabled = (url != nil)
    }
}

extension RemoteFilePickerVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        switch connectionType {
        case .webdav:
            return CellIndex.commonSectionCount + CellIndex.webdavSectionCount
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch (connectionType, section) {
        case (_, CellIndex.typeSelector.section): 
            return 1
        case (.webdav, _):
            return CellIndex.webdavSectionSizes[section]
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
        cell.selectionStyle = .none
        cell.textLabel?.text = LString.titleConnection
        cell.detailTextLabel?.text = connectionType.description
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .body)
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
        
        webdavURLTextField = cell.textField
        webdavURLTextField?.delegate = self
        webdavURLTextField?.validityDelegate = self
        webdavURLTextField?.text = url?.absoluteString
    }
    
    private func configureWebdavAllowUntrustedCell(_ cell: SwitchCell) {
        cell.textLabel?.text = LString.titleAllowUntrustedCertificate
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

        webdavUsernameTextField = cell.textField
        webdavUsernameTextField?.delegate = self
        webdavUsernameTextField?.validityDelegate = self
        webdavUsernameTextField?.text = username
    }
    
    private func configureWebdavPasswordCell(_ cell: TextFieldCell) {
        cell.textField.placeholder = LString.fieldPassword
        cell.textField.textContentType = .password
        cell.textField.isSecureTextEntry = true
        cell.textField.keyboardType = .default
        cell.textField.clearButtonMode = .whileEditing
        cell.textField.returnKeyType = .continue

        webdavPasswordTextField = cell.textField
        webdavPasswordTextField?.delegate = self
        webdavPasswordTextField?.validityDelegate = self
        webdavPasswordTextField?.text = password
    }
    
    private func setWebdavInputURL(fromText text: String) {
        guard var urlComponents = URLComponents(string: text),
              (urlComponents.scheme?.isNotEmpty ?? false),
              (urlComponents.host?.isNotEmpty ?? false),
              urlComponents.path.count > 1,
              let inputURL = urlComponents.url
        else { 
            self.url = nil
            refresh()
            return
        }
        
        let inputURLScheme = inputURL.scheme ?? ""
        guard WebDAVDataSource.urlSchemes.contains(inputURLScheme) else {
            self.url = nil
            refresh()
            return
        }
        
        if let urlUser = urlComponents.user {
            username = urlUser
            webdavUsernameTextField?.text = urlUser
        }
        if let urlPassword = urlComponents.password {
            password = urlPassword
            webdavPasswordTextField?.text = urlPassword
        }
        urlComponents.user = nil
        urlComponents.password = nil
        self.url = urlComponents.url
        webdavURLTextField?.text = self.url?.absoluteString ?? text
        
        refresh()
    }
    
    private func webdavDidPressDone() {
        guard doneButton.isEnabled else {
            return
        }
        delegate?.didPressDone(
            url: url!,
            credential: NetworkCredential(
                username: username,
                password: password,
                allowUntrustedCertificate: allowUntrustedCertificate
            ),
            in: self
        )
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
            webdavDidPressDone()
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
            self.username = text
        case webdavPasswordTextField:
            self.password = text
        default:
            return
        }
    }
}
