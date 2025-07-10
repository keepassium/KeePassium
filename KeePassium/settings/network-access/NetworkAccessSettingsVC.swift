//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol NetworkAccessSettingsDelegate: AnyObject {
    func didChangeNetworkPermission(isAllowed: Bool, in viewController: NetworkAccessSettingsVC)
    func didPressOpenURL(_ url: URL, in viewController: NetworkAccessSettingsVC)
    func didChangeAutoDownloadFavicons(isEnabled: Bool, in viewController: NetworkAccessSettingsVC)
}

final class NetworkAccessSettingsVC: UITableViewController, Refreshable {
    var isAccessAllowed = false
    var isAutoDownloadEnabled = false

    weak var delegate: NetworkAccessSettingsDelegate?

    private enum CellIndex {
        static let accessSwitchRows = 2
        static let accessDenied = IndexPath(row: 0, section: 0)
        static let accessGranted = IndexPath(row: 1, section: 0)

        static let autoDownloadFaviconsRows = 1
        static let autoDownloadSection = 1
        static let autoDownloadFavicons = IndexPath(row: 0, section: 1)

        static let privacyPolicySection = 2
        static let privacyPolicyRows = 2
        static let privacyPolicySummary = IndexPath(row: 0, section: 2)
        static let privacyPolicyLink = IndexPath(row: 1, section: 2)
    }

    static func make() -> NetworkAccessSettingsVC {
        return NetworkAccessSettingsVC(style: .insetGrouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = LString.titleNetworkAccessSettings

        tableView.register(
            ModeCell.classForCoder(),
            forCellReuseIdentifier: ModeCell.reuseIdentifier)
        tableView.register(
            PolicyCell.classForCoder(),
            forCellReuseIdentifier: PolicyCell.reuseIdentifier)
        tableView.register(
            SwitchCell.classForCoder(),
            forCellReuseIdentifier: SwitchCell.reuseIdentifier)
    }

    func refresh() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak tableView] in
            tableView?.reloadData()
        }
    }

    func refreshImmediately() {
        tableView.reloadData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case CellIndex.accessGranted.section:
            return CellIndex.accessSwitchRows
        case CellIndex.autoDownloadFavicons.section:
            return CellIndex.autoDownloadFaviconsRows
        case CellIndex.privacyPolicySummary.section:
            return CellIndex.privacyPolicyRows
        default:
            fatalError("Unexpected cell index")
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case CellIndex.privacyPolicySummary.section:
            return LString.About.titlePrivacyPolicy
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case CellIndex.autoDownloadSection:
            return LString.descriptionAutoDownloadFavicons
        default:
            return nil
        }
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        switch indexPath {
        case CellIndex.accessDenied:
            let modeCell = tableView
                .dequeueReusableCell(withIdentifier: ModeCell.reuseIdentifier, for: indexPath)
                as! ModeCell
            modeCell.textLabel?.text = LString.titleStayOffline
            modeCell.detailTextLabel?.text = LString.titleMaximumPrivacy
            modeCell.accessoryType = isAccessAllowed ? .none : .checkmark
            modeCell.imageView?.image = .symbol(.wifiSlash)
            return modeCell
        case CellIndex.accessGranted:
            let modeCell = tableView
                .dequeueReusableCell(withIdentifier: ModeCell.reuseIdentifier, for: indexPath)
                as! ModeCell
            modeCell.textLabel?.text = LString.titleAllowNetworkAccess
            modeCell.detailTextLabel?.text = LString.titleMaximumFunctionality
            modeCell.accessoryType = isAccessAllowed ? .checkmark : .none
            modeCell.imageView?.image = .symbol(.network)
            return modeCell
        case CellIndex.autoDownloadFavicons:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SwitchCell.reuseIdentifier,
                for: indexPath) as! SwitchCell
            cell.textLabel?.text = LString.titleAutoDownloadFavicons
            cell.detailTextLabel?.text = nil
            cell.theSwitch.isOn = isAutoDownloadEnabled && isAccessAllowed
            cell.setEnabled(isAccessAllowed)
            cell.onDidToggleSwitch = { [weak self] theSwitch in
                guard let self else { return }
                delegate?.didChangeAutoDownloadFavicons(isEnabled: theSwitch.isOn, in: self)
            }
            return cell
        case CellIndex.privacyPolicySummary:
            let policyCell = tableView
                .dequeueReusableCell(withIdentifier: PolicyCell.reuseIdentifier, for: indexPath)
                as! PolicyCell
            if isAccessAllowed {
                policyCell.textLabel?.text = LString.About.onlinePrivacyPolicyText
            } else {
                policyCell.textLabel?.text = LString.About.offlinePrivacyPolicyText
            }
            policyCell.textLabel?.textColor = .label
            policyCell.accessoryType = .none
            policyCell.selectionStyle = .none
            return policyCell
        case CellIndex.privacyPolicyLink:
            let policyCell = tableView
                .dequeueReusableCell(withIdentifier: PolicyCell.reuseIdentifier, for: indexPath)
                as! PolicyCell
            policyCell.textLabel?.text = LString.actionLearnMore
            policyCell.textLabel?.textColor = .actionTint
            policyCell.accessoryType = .disclosureIndicator
            policyCell.selectionStyle = .default
            return policyCell
        default:
            fatalError("Unexpected cell index")
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath {
        case CellIndex.accessDenied:
            isAccessAllowed = false
            HapticFeedback.play(.selectionChanged)
            delegate?.didChangeNetworkPermission(isAllowed: isAccessAllowed, in: self)
        case CellIndex.accessGranted:
            isAccessAllowed = true
            HapticFeedback.play(.selectionChanged)
            delegate?.didChangeNetworkPermission(isAllowed: isAccessAllowed, in: self)
        case CellIndex.privacyPolicySummary:
            return
        case CellIndex.privacyPolicyLink:
            delegate?.didPressOpenURL(URL.AppHelp.currentPrivacyPolicy, in: self)
        case CellIndex.autoDownloadFavicons:
            return
        default:
            fatalError("Unexpected cell index")
        }
    }
}

extension NetworkAccessSettingsVC {
    private final class ModeCell: SubtitleCell {}
    private final class PolicyCell: SubtitleCell {}
}
