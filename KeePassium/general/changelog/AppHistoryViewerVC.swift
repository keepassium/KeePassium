//  KeePassium Password Manager
//  Copyright © 2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class AppHistoryItemCell: UITableViewCell {
    fileprivate static let storyboardID = "LogItemCell"
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailLabel: UILabel!
}

class AppHistoryFallbackCell: UITableViewCell {
    fileprivate static let storyboardID = "FallbackCell"
}

class AppHistoryViewerVC: UITableViewController {
    var appHistory: AppHistory? {
        didSet {
            updateSections()
        }
    }
    
    enum TableSection {
        case fallbackSeparator(date: Date)
        case historySection(section: AppHistory.Section)
    }
    
    private let fallbackDate = PremiumManager.shared.fallbackDate
    private var sections = [TableSection]()
    
    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        dateFormatter.doesRelativeDateFormatting = true
        return dateFormatter
    }()
    
    private func updateSections() {
        sections.removeAll()
        defer {
            tableView.reloadData()
        }
        
        guard let appHistory = appHistory else { return }
        
        guard let perpetualFallbackDate = fallbackDate else {
            sections = appHistory.sections.map { return TableSection.historySection(section: $0) }
            return
        }
        var isFallbackSectionAdded = false
        for release in appHistory.sections {
            if !isFallbackSectionAdded && release.releaseDate < perpetualFallbackDate {
                sections.append(TableSection.fallbackSeparator(date: perpetualFallbackDate))
                isFallbackSectionAdded = true
            }
            sections.append(TableSection.historySection(section: release))
        }
    }
}


extension AppHistoryViewerVC {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .fallbackSeparator:
            return 1
        case .historySection(section: let appHistorySection):
            return appHistorySection.items.count
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        titleForHeaderInSection section: Int)
        -> String?
    {
        switch sections[section] {
        case .fallbackSeparator:
            return nil
        case .historySection(section: let sectionInfo):
            let formattedDate = dateFormatter.string(from: sectionInfo.releaseDate)
            return "v\(sectionInfo.version) (\(formattedDate))"
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: section)
        }
    }
    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> UITableViewCell
    {
        switch sections[indexPath.section] {
        case .fallbackSeparator(date: let fallbackDate):
            let cell = tableView
                .dequeueReusableCell(withIdentifier: AppHistoryFallbackCell.storyboardID)
                as! AppHistoryFallbackCell
            let formattedDate = dateFormatter.string(from: fallbackDate)
            cell.textLabel?.text = String.localizedStringWithFormat(
                LString.perpetualLicenseStatus,
                formattedDate)
            return cell
        case .historySection(section: let releaseInfo):
            let cell = tableView
                .dequeueReusableCell(withIdentifier: AppHistoryItemCell.storyboardID)
                as! AppHistoryItemCell
            let item = releaseInfo.items[indexPath.row]
            let isOwned = (fallbackDate != nil) && (releaseInfo.releaseDate < fallbackDate!)
            setupCell(cell, item: item, isOwned: isOwned)
            return cell
        }
    }
    
    private func setupCell(_ cell: AppHistoryItemCell, item: AppHistory.Item, isOwned: Bool) {
        cell.titleLabel.text = item.title
        switch item.type {
        case .none:
            cell.detailLabel.text = ""
            cell.accessoryView = nil
            cell.accessoryType = isOwned ? .checkmark : .none
            cell.tintColor = .auxiliaryText
        case .free:
            cell.accessoryView = nil
            cell.tintColor = .auxiliaryText
            if isOwned {
                cell.accessoryType = .checkmark
                cell.detailLabel.text = ""
            } else {
                cell.accessoryType = .none
                cell.detailLabel.text = LString.premiumFreePlanPrice
            }
        case .premium:
            cell.detailLabel.text = ""
            if isOwned {
                cell.accessoryView = nil
                cell.accessoryType = .checkmark
                cell.tintColor = .systemYellow
            } else {
                cell.accessoryType = .none
                cell.accessoryView = PremiumBadgeAccessory()
            }
        }
    }
}

private class PremiumBadgeAccessory: UIImageView {
    required init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 25, height: 25))
        image = UIImage(asset: .premiumFeatureBadge)
        contentMode = .scaleAspectFill
        accessibilityLabel = "Premium"
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("Not implemented")
    }
}
