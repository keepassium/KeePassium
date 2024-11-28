//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import UIKit

protocol AboutDelegate: AnyObject {
    func didPressContactSupport(at popoverAnchor: PopoverAnchor, in viewController: AboutVC)
    func didPressWriteReview(at popoverAnchor: PopoverAnchor, in viewController: AboutVC)
    func didPressOpenURL(_ url: URL, at popoverAnchor: PopoverAnchor, in viewController: AboutVC)
}

final class AboutVC: UITableViewController {
    @IBOutlet private weak var appTitleLabel: UILabel!
    @IBOutlet private weak var contactSupportCell: UITableViewCell!
    @IBOutlet private weak var writeReviewCell: UITableViewCell!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var copyrightLabel: UILabel!
    @IBOutlet private weak var acceptInputFromAutoFillCell: UITableViewCell!
    @IBOutlet private weak var privacyPolicyCell: UITableViewCell!
    @IBOutlet private weak var privacyPolicyLabel: UILabel!

    private static let creditsSectionIndex = 3
    private static let credistsCellId = "creditsCell"

    private lazy var creditsCellConfiguration: UIListContentConfiguration = {
        var configuration = UIListContentConfiguration.subtitleCell()
        configuration.textProperties.font = UIFont.preferredFont(forTextStyle: .body)
        configuration.textProperties.color = .primaryText
        configuration.secondaryTextProperties.color = .auxiliaryText
        configuration.secondaryTextProperties.font = UIFont.preferredFont(forTextStyle: .caption1)
        configuration.textToSecondaryTextVerticalPadding = 4
        return configuration
    }()

    weak var delegate: AboutDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.credistsCellId)

        var versionParts = ["v\(AppInfo.version).\(AppInfo.build)"]
        if Settings.current.isTestEnvironment {
            versionParts.append("beta")
        } else {
            if BusinessModel.type == .prepaid {
                versionParts.append("Pro")
            }
        }
        appTitleLabel.text = AppInfo.name
        versionLabel.text = versionParts.joined(separator: " ")
        copyrightLabel.text = LString.copyrightNotice
        contactSupportCell.detailTextLabel?.text = SupportEmailComposer.getSupportEmail()
        if Settings.current.isNetworkAccessAllowed {
            privacyPolicyLabel.text = LString.About.onlinePrivacyPolicyText
        } else {
            privacyPolicyLabel.text = LString.About.offlinePrivacyPolicyText
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0.1
        }
        return super.tableView(tableView, heightForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == Self.creditsSectionIndex {
            let item = Credits.all[indexPath.row]
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.credistsCellId, for: indexPath)
            configure(cell: cell, item: item)
            return cell
        }
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if cell == acceptInputFromAutoFillCell {
            cell.accessoryType = Settings.current.acceptAutoFillInput ? .checkmark : .none
        }
        return cell
    }

    private func configure(cell: UITableViewCell, item: Credits) {
        var configuration = creditsCellConfiguration
        configuration.text = item.title
        configuration.secondaryText = item.license.title
        cell.contentConfiguration = configuration
        cell.accessoryType = item.url != nil ? .disclosureIndicator : .none
        cell.selectionStyle = item.url != nil ? .default : .none
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }

        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        switch selectedCell {
        case contactSupportCell:
            delegate?.didPressContactSupport(at: popoverAnchor, in: self)
        case writeReviewCell:
            delegate?.didPressWriteReview(at: popoverAnchor, in: self)
        case privacyPolicyCell:
            delegate?.didPressOpenURL(URL.AppHelp.currentPrivacyPolicy, at: popoverAnchor, in: self)
        case acceptInputFromAutoFillCell:
            let newValue = !Settings.current.acceptAutoFillInput
            Settings.current.acceptAutoFillInput = newValue
            Diag.info("Accept input from AutoFill providers: \(newValue)")
            tableView.reloadData()
        default:
            if let url = Credits.all[indexPath.row].url {
                delegate?.didPressOpenURL(url, at: popoverAnchor, in: self)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == Self.creditsSectionIndex {
            return Credits.all.count
        }
        return super.tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
