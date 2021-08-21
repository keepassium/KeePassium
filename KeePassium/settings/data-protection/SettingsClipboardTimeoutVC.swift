//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol SettingsClipboardTimeoutViewControllerDelegate: AnyObject {
    func didFinishSelection(in viewController: SettingsClipboardTimeoutVC)
}

final class SettingsClipboardTimeoutVC: NavTableViewController, Refreshable {
    private let cellID = "Cell"
    
    weak var delegate: SettingsClipboardTimeoutViewControllerDelegate?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func refresh() {
        tableView.reloadData()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.ClipboardTimeout.allValues.count
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return NSLocalizedString(
            "[Settings/ClipboardTimeout/description] When you copy some text from an entry, the app will automatically clear your clipboard (pasteboard) after this time.",
            value: "When you copy some text from an entry, the app will automatically clear your clipboard (pasteboard) after this time.",
            comment: "Description of the clipboard/pasteboard timeout.")
    }
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        let timeout = Settings.ClipboardTimeout.allValues[indexPath.row]
        cell.textLabel?.text = timeout.fullTitle
        if timeout == Settings.current.clipboardTimeout {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let timeout = Settings.ClipboardTimeout.allValues[indexPath.row]
        didSelectTimeout(timeout)
    }
    
    private func didSelectTimeout(_ timeout: Settings.ClipboardTimeout) {
        Settings.current.clipboardTimeout = timeout
        refresh()
        delegate?.didFinishSelection(in: self)
    }
}
