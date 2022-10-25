//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol ConnectionTypePickerDelegate: AnyObject {
    func willSelect(
        connectionType: RemoteConnectionType,
        in viewController: ConnectionTypePickerVC) -> Bool
    func didSelect(connectionType: RemoteConnectionType, in viewController: ConnectionTypePickerVC)
}

final class ConnectionTypePickerVC: UITableViewController, Refreshable {
    private enum CellID {
        static let itemCell = "itemCell"
    }
    
    public weak var delegate: ConnectionTypePickerDelegate?

    public let values = RemoteConnectionType.allValues
    
    public var selectedValue: RemoteConnectionType?
    
    public static func make() -> ConnectionTypePickerVC {
        return ConnectionTypePickerVC(style: .insetGrouped)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.titleConnection

        tableView.register(
            SubtitleCell.classForCoder(),
            forCellReuseIdentifier: CellID.itemCell)
        tableView.allowsSelection = true
    }
    
    func refresh() {
        tableView.reloadData()
    }
}

extension ConnectionTypePickerVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return values.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: CellID.itemCell, for: indexPath)
            as! SubtitleCell
        
        let value = values[indexPath.row]
        cell.textLabel?.text = value.description
        cell.imageView?.contentMode = .scaleAspectFit
        cell.imageView?.image = value.icon
        cell.selectionStyle = .default
        
        if value.isPremiumUpgradeRequired {
            cell.accessoryType = .none
            cell.accessoryView = PremiumBadgeAccessory()
        } else {
            cell.accessoryView = nil
            cell.accessoryType = value == selectedValue ? .checkmark : .none
        }
        return cell
    }
}

extension ConnectionTypePickerVC {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedValue = values[indexPath.row]
        let canSelect = delegate?.willSelect(connectionType: selectedValue, in: self) ?? false
        guard canSelect else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        self.selectedValue = selectedValue
        tableView.reloadData()
        delegate?.didSelect(connectionType: selectedValue, in: self)
    }
}
