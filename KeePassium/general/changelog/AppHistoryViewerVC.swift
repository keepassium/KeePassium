//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

final class AppHistoryViewerVC: UITableViewController {

    var appHistory: AppHistory? {
        didSet {
            updateSections()
        }
    }

    private enum TableSection {
        case fallbackSeparator(date: Date)
        case historySection(section: AppHistory.Section)
    }

    private enum CellID {
        static let fallbackCell = "FallbackCell"
        static let itemCell = "ItemCell"
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

    private lazy var itemCellConfiguration: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .callout)
        configuration.textProperties.color = .primaryText
        configuration.secondaryTextProperties.color = .auxiliaryText
        configuration.textToSecondaryTextVerticalPadding = 4
        configuration.directionalLayoutMargins = .init(top: 8, leading: 0, bottom: 10, trailing: 2)
        return configuration
    }()

    private lazy var fallbackCellConfiguration: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.cell()
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        configuration.textProperties.color = .primaryText
        configuration.image = .symbol(.checkmarkSeal)
        return configuration
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = LString.titleAppHistory
        registerCellClasses(tableView)
    }

    private func updateSections() {
        sections.removeAll()
        defer {
            tableView.reloadData()
        }

        guard let appHistory = appHistory else { return }

        sections = appHistory.sections.map { return TableSection.historySection(section: $0) }
        if let perpetualFallbackDate = fallbackDate {
            sections.insert(TableSection.fallbackSeparator(date: perpetualFallbackDate), at: 0)
        }
    }
}


extension AppHistoryViewerVC {
    private func registerCellClasses(_ tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellID.itemCell)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: CellID.fallbackCell)
    }

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
        titleForHeaderInSection section: Int
    ) -> String? {
        switch sections[section] {
        case .fallbackSeparator:
            return nil
        case .historySection(section: let sectionInfo):
            let formattedDate = dateFormatter.string(from: sectionInfo.releaseDate)
            return "Version \(sectionInfo.version) (\(formattedDate))"
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let headerView = view as? UITableViewHeaderFooterView {
            headerView.textLabel?.text = self.tableView(tableView, titleForHeaderInSection: section)
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .fallbackSeparator(date: let fallbackDate):
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.fallbackCell, for: indexPath)
            configure(cell: cell, fallbackDate: fallbackDate)
            return cell
        case .historySection(section: let releaseInfo):
            let item = releaseInfo.items[indexPath.row]
            let isOwned = (fallbackDate != nil) && (releaseInfo.releaseDate < fallbackDate!)
            let cell = tableView.dequeueReusableCell(withIdentifier: CellID.itemCell, for: indexPath)
            configure(cell: cell, item: item, isOwned: isOwned)
            return cell
        }
    }

    private func configure(cell: UITableViewCell, fallbackDate: Date) {
        var configuration = fallbackCellConfiguration
        configuration.text = fallbackDate == .distantFuture
            ? LString.perpetualLicense
            : appHistory?.versionOnDate(fallbackDate).flatMap {
                String.localizedStringWithFormat(
                    LString.premiumStatusLicensedVersionTemplate,
                    $0)
            }
        cell.contentConfiguration = configuration
        cell.accessoryType = fallbackDate == .distantFuture ? .none : .disclosureIndicator
    }

    private func configure(cell: UITableViewCell, item: AppHistory.Item, isOwned: Bool) {
        var configuration = itemCellConfiguration
        configuration.text = item.title
        configuration.image = .symbol(item.change.symbolName)
        configuration.imageProperties.tintColor = item.change.tintColor
        configuration.imageProperties.preferredSymbolConfiguration = .init(scale: .large)
        if item.credits.isEmpty {
            configuration.secondaryText = nil
        } else {
            let creditsText = item.credits.joined(separator: ", ")
            configuration.secondaryText = String.localizedStringWithFormat(
                LString.appHistoryThanksTemplate,
                creditsText
            )
        }
        cell.contentConfiguration = configuration
        cell.selectionStyle = .none

        cell.isAccessibilityElement = true
        cell.accessibilityLabel = [item.change.description, ": ", item.title].joined()

        let itemType = LicenseManager.shared.hasActiveBusinessLicense() ? .none : item.type
        switch itemType {
        case .none:
            cell.accessoryView = nil
            cell.accessoryType = .none
            cell.tintColor = .auxiliaryText
        case .free:
            cell.accessoryView = nil
            cell.tintColor = .auxiliaryText
            if isOwned {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
                cell.accessoryView = FreeBadgeAccessory()
                cell.accessoryView?.sizeToFit()
            }
        case .premium:
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section] {
        case .fallbackSeparator(date: let fallbackDate):
            scrollToDate(fallbackDate)
        default:
            break
        }
    }

    private func scrollToDate(_ date: Date) {
        let sectionIndex = sections.firstIndex(where: {
            switch $0 {
            case .fallbackSeparator:
                return false
            case .historySection(section: let section):
                return section.releaseDate < date
            }
        })
        guard let sectionIndex = sectionIndex else {
            return
        }
        tableView.scrollToRow(
            at: IndexPath(row: 0, section: sectionIndex),
            at: .top,
            animated: true
        )
    }
}

extension LString {
    static let titleAppHistory = NSLocalizedString(
        "[AppHistory/title]",
        value: "What's New",
        comment: "Title of the app history (changelog) screen")

    static let appHistoryThanksTemplate = "Thanks, %@"
}
