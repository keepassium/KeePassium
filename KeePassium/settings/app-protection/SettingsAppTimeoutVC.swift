//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsAppTimeoutVC: UITableViewController, Refreshable {
    private let timeoutCellID = "TimeoutCell"
    private let switchCellID = "SwitchCell"
    
    enum SectionID: Int {
        static let all = [timeout, launchTrigger]
        case timeout = 0
        case launchTrigger = 1
    }
    
    public static func make() -> UIViewController {
        return SettingsAppTimeoutVC.instantiateFromStoryboard()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()        
        tableView.register(SwitchCell.classForCoder(), forCellReuseIdentifier: switchCellID)
    }
    
    func refresh() {
        tableView.reloadData()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SectionID.all.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForFooterInSection section: Int
    ) -> String? {
        switch SectionID(rawValue: section)! {
        case .launchTrigger:
            return LString.lockAppOnLaunchDescription
        case .timeout:
            return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SectionID(rawValue: section)! {
        case .launchTrigger:
            return 1
        case .timeout:
            return Settings.AppLockTimeout.allValues.count
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch SectionID(rawValue: indexPath.section)! {
        case .launchTrigger:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellID, for: indexPath) as! SwitchCell
            configureLaunchTriggerCell(cell)
            return cell
        case .timeout:
            let cell = tableView.dequeueReusableCell(withIdentifier: timeoutCellID, for: indexPath)
            configureTimeoutCell(cell, index: indexPath.row)
            return cell
        }
    }
    
    private func configureLaunchTriggerCell(_ cell: SwitchCell) {
        cell.textLabel?.text = LString.lockAppOnLaunchTitle
        cell.theSwitch.isOn = Settings.current.isLockAppOnLaunch
        cell.onDidToggleSwitch = { (theSwitch) in
            Settings.current.isLockAppOnLaunch = theSwitch.isOn
        }
    }
    
    private func configureTimeoutCell(_ cell: UITableViewCell, index: Int) {
        let timeout = Settings.AppLockTimeout.allValues[index]
        cell.textLabel?.text = timeout.fullTitle
        cell.detailTextLabel?.text = timeout.description
        if timeout == Settings.current.appLockTimeout {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
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
