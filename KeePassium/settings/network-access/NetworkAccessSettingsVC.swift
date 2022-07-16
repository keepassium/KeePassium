//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol NetworkAccessSettingsDelegate: AnyObject {
    func didChangeNetworkPermission(isAllowed: Bool, in viewController: NetworkAccessSettingsVC)
    func didPressOpenURL(_ url: URL, in viewController: NetworkAccessSettingsVC)
}

final class NetworkAccessSettingsVC: UITableViewController {
    var isAccessAllowed: Bool = false {
        didSet {
            tableView.reloadData()
        }
    }
    
    weak var delegate: NetworkAccessSettingsDelegate?
    
    private enum CellIndex {
        static let accessSwitchRows = 2
        static let accessDenied = IndexPath(row: 0, section: 0)
        static let accessGranted = IndexPath(row: 1, section: 0)

        static let privacyPolicyRows = 2
        static let privacyPolicySummary = IndexPath(row: 0, section: 1)
        static let privacyPolicyLink = IndexPath(row: 1, section: 1)
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
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case CellIndex.accessGranted.section:
            return CellIndex.accessSwitchRows
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
            modeCell.imageView?.image = UIImage.get(.wifiSlash)?
                .applyingSymbolConfiguration(.init(scale: .large))
            return modeCell
        case CellIndex.accessGranted:
            let modeCell = tableView
                .dequeueReusableCell(withIdentifier: ModeCell.reuseIdentifier, for: indexPath)
                as! ModeCell
            modeCell.textLabel?.text = LString.titleAllowNetworkAccess
            modeCell.detailTextLabel?.text = LString.titleMaximumFunctionality
            modeCell.accessoryType = isAccessAllowed ? .checkmark : .none
            modeCell.imageView?.image = UIImage.get(.network)?
                .applyingSymbolConfiguration(.init(scale: .large))
            return modeCell
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
            delegate?.didChangeNetworkPermission(isAllowed: isAccessAllowed, in: self)
        case CellIndex.accessGranted:
            isAccessAllowed = true
            delegate?.didChangeNetworkPermission(isAllowed: isAccessAllowed, in: self)
        case CellIndex.privacyPolicySummary:
            return
        case CellIndex.privacyPolicyLink:
            delegate?.didPressOpenURL(URL.AppHelp.currentPrivacyPolicy, in: self)
        default:
            fatalError("Unexpected cell index")
        }
    }
}

extension NetworkAccessSettingsVC {
    final class ModeCell: UITableViewCell {
        static let reuseIdentifier = "ModeCell"
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: .subtitle, reuseIdentifier: ModeCell.reuseIdentifier)
            configureCell()
        }
        
        required init?(coder: NSCoder) {
            fatalError("Not implemented")
        }
        
        override func awakeFromNib() {
            super.awakeFromNib()
            configureCell()
        }
        
        private func configureCell() {
            textLabel?.font = .preferredFont(forTextStyle: .body)
            textLabel?.textColor = .label
            textLabel?.numberOfLines = 0
            textLabel?.lineBreakMode = .byWordWrapping
            
            detailTextLabel?.font = .preferredFont(forTextStyle: .footnote)
            detailTextLabel?.textColor = .secondaryLabel
            detailTextLabel?.numberOfLines = 0
            detailTextLabel?.lineBreakMode = .byWordWrapping
        }
    }
    
    final class PolicyCell: UITableViewCell {
        static let reuseIdentifier = "PolicyCell"
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: .default, reuseIdentifier: PolicyCell.reuseIdentifier)
            configureCell()
        }
        
        required init?(coder: NSCoder) {
            fatalError("Not implemented")
        }
        
        override func awakeFromNib() {
            super.awakeFromNib()
            configureCell()
        }
        
        private func configureCell() {
            textLabel?.font = .preferredFont(forTextStyle: .body)
            textLabel?.textColor = .label
            textLabel?.numberOfLines = 0
            textLabel?.lineBreakMode = .byWordWrapping
        }
    }

}
