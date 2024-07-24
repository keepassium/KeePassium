//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol AppIconPickerDelegate: AnyObject {
    func didSelectIcon(_ appIcon: AppIcon, in appIconPicker: AppIconPicker)
}

class AppIconPickerCell: UITableViewCell {
    static let storyboardID = "AppIconPickerCell"

    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var premiumBadge: UIImageView!
}

class AppIconPicker: UITableViewController, Refreshable {
    weak var delegate: AppIconPickerDelegate?

    private let appIcons: [AppIcon] = {
        switch BusinessModel.type {
        case .freemium:
            return [AppIcon.classicFree] + AppIcon.allCustom
        case .prepaid:
            return [AppIcon.classicPro, AppIcon.classicFree] + AppIcon.allCustom
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.titleAppIcon
    }

    func refresh() {
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return appIcons.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: AppIconPickerCell.storyboardID,
            for: indexPath)
            as! AppIconPickerCell
        let appIcon = appIcons[indexPath.row]
        cell.iconView?.image = UIImage(named: appIcon.asset)
        cell.titleLabel?.text = appIcon.name

        cell.premiumBadge.isHidden = true
        cell.accessibilityLabel = AccessibilityHelper.decorateAccessibilityLabel(
            premiumFeature: appIcon.name,
            isEnabled: true
        )

        let isCurrent = (UIApplication.shared.alternateIconName == appIcon.key)
        cell.accessoryType = isCurrent ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedIcon = appIcons[indexPath.row]
        delegate?.didSelectIcon(selectedIcon, in: self)
        tableView.reloadData()
    }
}
