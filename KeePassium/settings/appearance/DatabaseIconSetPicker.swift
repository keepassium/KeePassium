//  KeePassium Password Manager
//  Copyright © 2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol DatabaseIconSetPickerDelegate: class {
    func didSelect(iconSet: DatabaseIconSet, in picker: DatabaseIconSetPicker)
}

internal class DatabaseIconSetPickerCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
}

class DatabaseIconSetPicker: UITableViewController {
    private let cellID = "DatabaseIconSetPickerCell"

    weak var delegate: DatabaseIconSetPickerDelegate?
    var selectedItem: DatabaseIconSet? {
        didSet {
            tableView?.reloadData()
        }
    }
    private var demoIconID: IconID = .key
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        randomizeDemoIcon()
    }
    
    private func randomizeDemoIcon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.demoIconID = IconID.all.randomElement() ?? .key
            self?.tableView.reloadData()
            self?.randomizeDemoIcon()
        }
    }
    
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else {
            assertionFailure()
            return 0
        }
        return DatabaseIconSet.allValues.count
    }
    
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: cellID,
            for: indexPath)
            as! DatabaseIconSetPickerCell
        
        guard let iconSet = DatabaseIconSet(rawValue: indexPath.row) else {
            _received_wrong_icon_set_id()
            fatalError()
        }
        cell.iconView?.image = iconSet.getIcon(demoIconID)
        cell.titleLabel?.text = iconSet.title
        
        let isCurrent = iconSet == selectedItem
        cell.accessoryType = isCurrent ? .checkmark : .none
        return cell
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let iconSet = DatabaseIconSet(rawValue: indexPath.row) else {
            _received_wrong_icon_set_id()
            fatalError()
        }
        Diag.debug("Selected an icon set [title: \(iconSet.title)]")
        selectedItem = iconSet
        delegate?.didSelect(iconSet: iconSet, in: self)
    }
    
    private func _received_wrong_icon_set_id() {
        fatalError()
    }
}
