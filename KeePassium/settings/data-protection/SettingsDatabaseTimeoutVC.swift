//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

final class SettingsDatabaseTimeoutCell: UITableViewCell {
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

final class SettingsDatabaseTimeoutVC: UITableViewController, Refreshable {
    private let timeoutCellID = "TimeoutCell"
    private let switchCellID = "SwitchCell"

    enum SectionID: Int, CaseIterable {
        case lockOnReboot = 0
        case timeout = 1
    }

    private var premiumStatus: PremiumManager.Status = .initialGracePeriod

    weak var delegate: SettingsDatabaseTimeoutViewControllerDelegate?

    public static func make() -> Self {
        return Self.instantiateFromStoryboard()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.databaseTimeoutTitle
        tableView.register(SwitchCell.classForCoder(), forCellReuseIdentifier: switchCellID)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    func refresh() {
        premiumStatus = PremiumManager.shared.status
        tableView.reloadData()
    }
}

extension SettingsDatabaseTimeoutVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return SectionID.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SectionID(rawValue: section)! {
        case .timeout:
            return Settings.DatabaseLockTimeout.allValues.count
        case .lockOnReboot:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch SectionID(rawValue: section)! {
        case .timeout:
            return LString.databaseTimeoutTitle
        case .lockOnReboot:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch SectionID(rawValue: section)! {
        case .timeout:
            return LString.databaseTimeoutDescription
        case .lockOnReboot:
            return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch SectionID(rawValue: indexPath.section)! {
        case .timeout:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: timeoutCellID,
                for: indexPath)
            as! SettingsDatabaseTimeoutCell
            configureTimeoutCell(cell, index: indexPath.row)
            return cell
        case .lockOnReboot:
            let cell = tableView.dequeueReusableCell(withIdentifier: switchCellID, for: indexPath) as! SwitchCell
            configureLockOnRebootCell(cell)
            return cell
        }
    }

    private func configureTimeoutCell(_ cell: SettingsDatabaseTimeoutCell, index: Int) {
        let timeout = Settings.DatabaseLockTimeout.allValues[index]
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
    }

    private func configureLockOnRebootCell(_ cell: SwitchCell) {
        cell.textLabel?.text = LString.lockDatabasesOnRebootTitle
        cell.theSwitch.isOn = Settings.current.isLockDatabasesOnReboot
        cell.onDidToggleSwitch = { [weak self] theSwitch in
            Settings.current.isLockDatabasesOnReboot = theSwitch.isOn
            self?.refresh()
            self?.showNotificationIfManaged(setting: .lockDatabasesOnReboot)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch SectionID(rawValue: indexPath.section)! {
        case .timeout:
            let timeout = Settings.DatabaseLockTimeout.allValues[indexPath.row]
            delegate?.didSelectTimeout(timeout, in: self)
        case .lockOnReboot:
            break
        }
    }
}
