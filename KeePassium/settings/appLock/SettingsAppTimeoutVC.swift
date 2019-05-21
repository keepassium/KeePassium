//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsAppTimeoutVC: UITableViewController, Refreshable {
    private let cellID = "Cell"
    
    public static func make() -> UIViewController {
        return SettingsAppTimeoutVC.instantiateFromStoryboard()
    }
    
    func refresh() {
        tableView.reloadData()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.AppLockTimeout.allValues.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        let timeout = Settings.AppLockTimeout.allValues[indexPath.row]
        cell.textLabel?.text = timeout.fullTitle
        cell.detailTextLabel?.text = timeout.description
        if timeout == Settings.current.appLockTimeout {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let timeout = Settings.AppLockTimeout.allValues[indexPath.row]
        Settings.current.appLockTimeout = timeout
        Watchdog.shared.restart() 
        refresh()
        DispatchQueue.main.async {
            self.navigationController?.popViewController(animated: true)
        }
    }
}
