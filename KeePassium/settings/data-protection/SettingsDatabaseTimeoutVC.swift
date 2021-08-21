//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

final class SettingsDatabaseTimeoutCell: UITableViewCell {
    static let storyboardID = "Cell"
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
    @IBOutlet weak var premiumBadge: UIImageView!
}

protocol SettingsDatabaseTimeoutViewControllerDelegate: AnyObject {
    func didSelectTimeout(
        _ timeout: Settings.DatabaseLockTimeout,
        in viewController: SettingsDatabaseTimeoutVC
    )
}

final class SettingsDatabaseTimeoutVC: NavTableViewController, Refreshable {
    private var premiumStatus: PremiumManager.Status = .initialGracePeriod
    
    weak var delegate: SettingsDatabaseTimeoutViewControllerDelegate?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    func refresh() {
        premiumStatus = PremiumManager.shared.status
        tableView.reloadData()
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Settings.DatabaseLockTimeout.allValues.count
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else { return nil }
        return NSLocalizedString(
            "[Settings/DatabaseLockTimeout/description] If you are not interacting with the app for some time, the database will be closed for your safety. To open it, you will need to enter its master password again.",
            value: "If you are not interacting with the app for some time, the database will be closed for your safety. To open it, you will need to enter its master password again.",
            comment: "Description of the Database Lock Timeout")
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: SettingsDatabaseTimeoutCell.storyboardID,
            for: indexPath)
            as! SettingsDatabaseTimeoutCell
            
        let timeout = Settings.DatabaseLockTimeout.allValues[indexPath.row]
        cell.titleLabel?.text = timeout.fullTitle
        cell.detailLabel?.text = timeout.description
        let settings = Settings.current
        let isAvailable = settings.isShownAvailable(timeout: timeout, for: premiumStatus)
        cell.premiumBadge.isHidden = isAvailable
        cell.accessibilityLabel = AccessibilityHelper.decorateAccessibilityLabel(
            premiumFeature: cell.titleLabel?.text,
            isEnabled: isAvailable)
        
        if timeout == settings.premiumDatabaseLockTimeout {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let timeout = Settings.DatabaseLockTimeout.allValues[indexPath.row]
        delegate?.didSelectTimeout(timeout, in: self)
    }
}
