//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

class SettingsItemListVC: UITableViewController, Refreshable {
    private let cellID = "Cell"
    private enum Section: Int {
        static let allValues = [groupSorting, entrySubtitle]
        case entrySubtitle = 0
        case groupSorting = 1
        var title: String? {
            switch self {
            case .groupSorting:
                return NSLocalizedString(
                    "[Settings/GroupViewer] Sort Order",
                    value: "Sort Order",
                    comment: "Title of a settings section: sort order of groups and entries in a list")
            case .entrySubtitle:
                return NSLocalizedString(
                    "[Settings/GroupViewer] Entry Subtitle",
                    value: "Entry Subtitle",
                    comment: "Title of a settings section: which entry field to show along with entry title")
            }
        }
    }
    
    static func make(barPopoverSource: UIBarButtonItem?) -> UIViewController {
        let vc = SettingsItemListVC.instantiateFromStoryboard()
        
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .popover
        if let popover = navVC.popoverPresentationController {
            popover.barButtonItem = barPopoverSource
        }
        return navVC
    }

    func refresh() {
        tableView.reloadData()
    }
    
    
    @IBAction func didPressDone(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allValues.count
    }

    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int
        ) -> String?
    {
        guard let section = Section(rawValue: section) else {
            return nil
        }
        return section.title
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else {
            return 0
        }
        switch section {
        case .groupSorting:
            return Settings.GroupSortOrder.allValues.count
        case .entrySubtitle:
            return Settings.EntryListDetail.allValues.count
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
        ) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        guard let section = Section(rawValue: indexPath.section) else {
            assertionFailure()
            return cell
        }
        switch section {
        case .groupSorting:
            let groupSorting = Settings.GroupSortOrder.allValues[indexPath.row]
            cell.textLabel?.text = groupSorting.longTitle
            if groupSorting == Settings.current.groupSortOrder {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        case .entrySubtitle:
            let entrySubtitle = Settings.EntryListDetail.allValues[indexPath.row]
            cell.textLabel?.text = entrySubtitle.longTitle
            if entrySubtitle == Settings.current.entryListDetail {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        }
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else {
            assertionFailure()
            return
        }
        
        switch section {
        case .groupSorting:
            Settings.current.groupSortOrder = Settings.GroupSortOrder.allValues[indexPath.row]
        case .entrySubtitle:
            Settings.current.entryListDetail = Settings.EntryListDetail.allValues[indexPath.row]
        }
        refresh()
    }
}
