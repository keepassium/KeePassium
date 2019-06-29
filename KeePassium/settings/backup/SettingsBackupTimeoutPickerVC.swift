//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol SettingsBackupTimeoutPickerDelegate: class {
    func didFinish(_ viewController: SettingsBackupTimeoutPickerVC)
}

class SettingsBackupTimeoutPickerVC: UITableViewController {
    private let cellID = "cell"
    private let items = Settings.BackupKeepingDuration.allValues
    
    public weak var delegate: SettingsBackupTimeoutPickerDelegate?
    
    public static func create(delegate: SettingsBackupTimeoutPickerDelegate?=nil)
        -> SettingsBackupTimeoutPickerVC
    {
        let vc = SettingsBackupTimeoutPickerVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        refresh()
    }

    func refresh() {
        tableView.reloadData()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.BackupKeepingDuration.allValues.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let item = items[indexPath.row]
        cell.textLabel?.text = item.fullTitle
        if item == Settings.current.backupKeepingDuration {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Settings.current.backupKeepingDuration = items[indexPath.row]
        refresh()
        delegate?.didFinish(self)
    }
}
