//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

protocol SettingsFileSortingDelegate: AnyObject {
    func didChangeSortOrder(
        sortOrder: Settings.FilesSortOrder,
        in viewCoordinator: SettingsFileSortingVC
    )
    func didChangeBackupVisibility(
        isBackupVisible: Bool,
        in viewCoordinator: SettingsFileSortingVC
    )
}

final class SettingsBackupFileVisibilityCell: UITableViewCell {
    fileprivate static let storyboardID = "BackupVisibilityCell"
    @IBOutlet weak var theSwitch: UISwitch!
    
    var switchToggleHandler: ((UISwitch) -> ())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        theSwitch.isOn = Settings.current.isBackupFilesVisible
        theSwitch.addTarget(self, action: #selector(didToggleSwitch), for: .valueChanged)
    }
    
    @objc private func didToggleSwitch(_ sender: UISwitch) {
        switchToggleHandler?(theSwitch)
    }
}

final class SettingsFileSortingVC: NavTableViewController, Refreshable {
    private let sortingCellID = "SortingCell"
    
    weak var delegate: SettingsFileSortingDelegate?
    
    func refresh() {
        tableView.reloadData()
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
    ) -> String? {
        switch section {
        case 0:
            return NSLocalizedString(
                "[Settings/FileLists/Backup/title] Backup",
                value: "Backup",
                comment: "Title of a settings section about making backup files")
        case 1:
            return NSLocalizedString(
                "[Settings/FileLists/Sorting/title] Sorting",
                value: "Sorting",
                comment: "Title of a settings section about file order in lists")
        default:
            assertionFailure("Unexpected section number")
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return Settings.FilesSortOrder.allValues.count
        default:
            assertionFailure("Unexpected section number")
            return 0
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SettingsBackupFileVisibilityCell.storyboardID,
                for: indexPath)
                as! SettingsBackupFileVisibilityCell
            cell.switchToggleHandler = { [weak self] theSwitch in
                guard let self = self else { return }
                self.delegate?.didChangeBackupVisibility(isBackupVisible: theSwitch.isOn, in: self)
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: sortingCellID, for: indexPath)
            let cellValue = Settings.FilesSortOrder.allValues[indexPath.row]
            cell.textLabel?.text = cellValue.longTitle
            if Settings.current.filesSortOrder == cellValue {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            return cell
        default:
            assertionFailure("Unexpected section number")
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            return
        case 1:
            let selectedSortOrder = Settings.FilesSortOrder.allValues[indexPath.row]
            delegate?.didChangeSortOrder(sortOrder: selectedSortOrder, in: self)
        default:
            assertionFailure("Unexpected section number")
        }
        refresh()
    }
}
