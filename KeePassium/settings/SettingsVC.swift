//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import LocalAuthentication

protocol SettingsViewControllerDelegate: AnyObject {
    func didPressUpgradeToPremium(in viewController: SettingsVC)
    func didPressManageSubscription(in viewController: SettingsVC)
    func didPressShowAppHistory(in viewController: SettingsVC)
 
    func didPressAppearanceSettings(in viewController: SettingsVC)
    func didPressSearchSettings(in viewController: SettingsVC)
    func didPressAutoFillSettings(in viewController: SettingsVC)
    func didPressAppProtectionSettings(in viewController: SettingsVC)
    func didPressDataProtectionSettings(in viewController: SettingsVC)
    func didPressBackupSettings(in viewController: SettingsVC)
    
    func didPressShowDiagnostics(in viewController: SettingsVC)
    func didPressContactSupport(at popoverAnchor: PopoverAnchor, in viewController: SettingsVC)
    func didPressAboutApp(in viewController: SettingsVC)
}

final class SettingsVC: UITableViewController, Refreshable {

    @IBOutlet private weak var appSafetyCell: UITableViewCell!
    @IBOutlet private weak var dataSafetyCell: UITableViewCell!
    @IBOutlet private weak var dataBackupCell: UITableViewCell!
    @IBOutlet private weak var autoFillCell: UITableViewCell!
    
    @IBOutlet private weak var searchCell: UITableViewCell!
    @IBOutlet private weak var autoUnlockStartupDatabaseSwitch: UISwitch!
    @IBOutlet private weak var appearanceCell: UITableViewCell!
    
    @IBOutlet private weak var diagnosticLogCell: UITableViewCell!
    @IBOutlet private weak var contactSupportCell: UITableViewCell!
    @IBOutlet private weak var rateTheAppCell: UITableViewCell!
    @IBOutlet private weak var aboutAppCell: UITableViewCell!
    
    @IBOutlet private weak var premiumTrialCell: UITableViewCell!
    @IBOutlet private weak var premiumStatusCell: UITableViewCell!
    @IBOutlet private weak var manageSubscriptionCell: UITableViewCell!
    @IBOutlet private weak var appHistoryCell: UITableViewCell!
    
    weak var delegate: SettingsViewControllerDelegate?
    
    private var isPremiumSectionHidden = false
    
    private enum CellIndexPath {
        static let premiumSectionIndex = 0
        static let premiumTrial = IndexPath(row: 0, section: premiumSectionIndex)
        static let premiumStatus = IndexPath(row: 1, section: premiumSectionIndex)
        static let manageSubscription = IndexPath(row: 2, section: premiumSectionIndex)
        static let appHistoryCell = IndexPath(row: 3, section: premiumSectionIndex)
    }
    private var hiddenIndexPaths = Set<IndexPath>()

    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPremiumStatus),
            name: PremiumManager.statusUpdateNotification,
            object: nil)
        if BusinessModel.type == .prepaid {
            isPremiumSectionHidden = true
            setPremiumCellVisibility(premiumTrialCell, isHidden: true)
            setPremiumCellVisibility(premiumStatusCell, isHidden: true)
            setPremiumCellVisibility(manageSubscriptionCell, isHidden: true)
            setPremiumCellVisibility(appHistoryCell, isHidden: true)
        }
        refreshPremiumStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: PremiumManager.statusUpdateNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    func refresh() {
        let settings = Settings.current
        
        autoUnlockStartupDatabaseSwitch.isOn = settings.isAutoUnlockStartupDatabase
        let biometryType = LAContext.getBiometryType()
        if let biometryTypeName = biometryType.name {
            appSafetyCell.detailTextLabel?.text = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Settings/AppLock/subtitle] App Lock, %@, timeout",
                    value: "App Lock, %@, timeout",
                    comment: "Settings: subtitle of the `App Protection` section. biometryTypeName will be either 'Touch ID' or 'Face ID'. [biometryTypeName: String]"),
                biometryTypeName)
        } else {
            appSafetyCell.detailTextLabel?.text =
                NSLocalizedString(
                    "[Settings/AppLock/subtitle] App Lock, passcode, timeout",
                    value: "App Lock, passcode, timeout",
                    comment: "Settings: subtitle of the `App Protection` section when biometric auth is not available.")
        }
        refreshPremiumStatus()
        
        contactSupportCell.accessibilityValue = SupportEmailComposer.getSupportEmail()
    }
    
    
    private func setPremiumCellVisibility(_ cell: UITableViewCell, isHidden: Bool) {
        cell.isHidden = isHidden
        if isHidden {
            switch cell {
            case premiumTrialCell:
                hiddenIndexPaths.insert(CellIndexPath.premiumTrial)
            case premiumStatusCell:
                hiddenIndexPaths.insert(CellIndexPath.premiumStatus)
            case manageSubscriptionCell:
                hiddenIndexPaths.insert(CellIndexPath.manageSubscription)
            case appHistoryCell:
                hiddenIndexPaths.insert(CellIndexPath.appHistoryCell)
            default:
                break
            }
        } else {
            switch cell {
            case premiumTrialCell:
                hiddenIndexPaths.remove(CellIndexPath.premiumTrial)
            case premiumStatusCell:
                hiddenIndexPaths.remove(CellIndexPath.premiumStatus)
            case manageSubscriptionCell:
                hiddenIndexPaths.remove(CellIndexPath.manageSubscription)
            case appHistoryCell:
                hiddenIndexPaths.remove(CellIndexPath.appHistoryCell)
            default:
                break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if hiddenIndexPaths.contains(indexPath) {
            return 0.01
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == CellIndexPath.premiumSectionIndex && isPremiumSectionHidden {
            return 0.01
        }
        return super.tableView(tableView, heightForFooterInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == CellIndexPath.premiumSectionIndex && isPremiumSectionHidden {
            return 0.01
        }
        return super.tableView(tableView, heightForHeaderInSection: section)
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == CellIndexPath.premiumSectionIndex && isPremiumSectionHidden {
            return nil
        }
        return super.tableView(tableView, titleForHeaderInSection: section)
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let popoverAnchor = PopoverAnchor(tableView: tableView, at: indexPath)
        
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case appSafetyCell:
            delegate?.didPressAppProtectionSettings(in: self)
        case autoFillCell:
            delegate?.didPressAutoFillSettings(in: self)
        case dataSafetyCell:
            delegate?.didPressDataProtectionSettings(in: self)
        case searchCell:
            delegate?.didPressSearchSettings(in: self)
        case appearanceCell:
            delegate?.didPressAppearanceSettings(in: self)
        case dataBackupCell:
            delegate?.didPressBackupSettings(in: self)
        case premiumStatusCell,
             premiumTrialCell:
            delegate?.didPressUpgradeToPremium(in: self)
        case manageSubscriptionCell:
            delegate?.didPressManageSubscription(in: self)
        case appHistoryCell:
            delegate?.didPressShowAppHistory(in: self)
        case diagnosticLogCell:
            delegate?.didPressShowDiagnostics(in: self)
        case contactSupportCell:
            delegate?.didPressContactSupport(at: popoverAnchor, in: self)
        case rateTheAppCell:
            AppStoreHelper.writeReview()
        case aboutAppCell:
            delegate?.didPressAboutApp(in: self)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == CellIndexPath.premiumSectionIndex else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }
        
        if !isPremiumSectionHidden && PremiumManager.shared.usageMonitor.isEnabled {
            return getAppUsageDescription()
        } else {
            return nil
        }
    }
    
    @IBAction func didToggleAutoUnlockStartupDatabase(_ sender: UISwitch) {
        Settings.current.isAutoUnlockStartupDatabase = sender.isOn
    }
    
    
    #if DEBUG
    private let premiumRefreshInterval = 1.0
    #else
    private let premiumRefreshInterval = 10.0
    #endif
    
    @objc private func refreshPremiumStatus() {
        guard BusinessModel.type != .prepaid else { return }
        
        let premiumManager = PremiumManager.shared
        premiumManager.usageMonitor.refresh()
        premiumManager.updateStatus()
        switch premiumManager.status {
        case .initialGracePeriod:
            setPremiumCellVisibility(premiumTrialCell, isHidden: false)
            setPremiumCellVisibility(premiumStatusCell, isHidden: true)
            setPremiumCellVisibility(manageSubscriptionCell, isHidden: true)
            
            if Settings.current.isTestEnvironment {
                let secondsLeft = premiumManager.gracePeriodSecondsRemaining
                let timeFormatted = DateComponentsFormatter.format(
                    secondsLeft,
                    allowedUnits: [.day, .hour, .minute, .second],
                    maxUnitCount: 2) ?? "?"
                Diag.debug("Initial setup period: \(timeFormatted) remaining")
            }
            premiumTrialCell.detailTextLabel?.text = nil
        case .subscribed:
            guard let expiryDate = premiumManager.getPremiumExpiryDate() else {
                assertionFailure()
                Diag.error("Subscribed, but no expiry date?")
                premiumStatusCell.detailTextLabel?.text = "?"
                return
            }
            guard let product = premiumManager.getPremiumProduct() else {
                assertionFailure()
                Diag.error("Subscribed, but no product info?")
                premiumStatusCell.detailTextLabel?.text = "?"
                return
            }
            
            setPremiumCellVisibility(premiumTrialCell, isHidden: true)
            setPremiumCellVisibility(premiumStatusCell, isHidden: false)
            setPremiumCellVisibility(manageSubscriptionCell, isHidden: !product.isSubscription)
            
            if expiryDate == .distantFuture {
                if Settings.current.isTestEnvironment {
                    premiumStatusCell.detailTextLabel?.text = NSLocalizedString(
                        "[Premium/status] Beta testing",
                        value: "Beta testing",
                        comment: "Status: special premium for beta-testing environment is active")
                } else {
                    premiumStatusCell.detailTextLabel?.text = NSLocalizedString(
                        "[Premium/status] Valid forever",
                        value: "Valid forever",
                        comment: "Status: validity period of once-and-forever premium")
                }
            } else {
                #if DEBUG
                let expiryDateString = DateFormatter
                    .localizedString(from: expiryDate, dateStyle: .medium, timeStyle: .short)
                #else
                let expiryDateString = DateFormatter
                    .localizedString(from: expiryDate, dateStyle: .medium, timeStyle: .none)
                #endif
                premiumStatusCell.detailTextLabel?.text = String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Premium/status] Next renewal on %@",
                        value: "Next renewal on %@",
                        comment: "Status: scheduled renewal date of a premium subscription. For example: `Next renewal on 1 Jan 2050`. [expiryDateString: String]"),
                    expiryDateString)
            }
        case .lapsed:
            setPremiumCellVisibility(premiumTrialCell, isHidden: false)
            setPremiumCellVisibility(premiumStatusCell, isHidden: false)
            setPremiumCellVisibility(manageSubscriptionCell, isHidden: false)
            
            let premiumStatusText: String
            if let secondsSinceExpiration = premiumManager.secondsSinceExpiration {
                let timeFormatted = DateComponentsFormatter.format(
                    secondsSinceExpiration,
                    allowedUnits: [.day, .hour, .minute],
                    maxUnitCount: 1) ?? "?"
                premiumStatusText = String.localizedStringWithFormat(
                    NSLocalizedString(
                        "[Premium/status] Expired %@ ago. Please renew.",
                        value: "Expired %@ ago. Please renew.",
                        comment: "Status: premium subscription has expired. For example: `Expired 1 day ago`. [timeFormatted: String, includes the time unit (day, hour, minute)]"),
                    timeFormatted)
            } else {
                assertionFailure()
                premiumStatusText = "?"
            }
            premiumTrialCell.detailTextLabel?.text = ""
            premiumStatusCell.detailTextLabel?.text = premiumStatusText
            premiumStatusCell.detailTextLabel?.textColor = .errorMessage
        case .freeLightUse,
             .freeHeavyUse:
            setPremiumCellVisibility(premiumTrialCell, isHidden: false)
            setPremiumCellVisibility(premiumStatusCell, isHidden: true)
            setPremiumCellVisibility(manageSubscriptionCell, isHidden: true)
            premiumTrialCell.detailTextLabel?.text = nil
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + premiumRefreshInterval) {
            [weak self] in
            self?.refreshPremiumStatus()
        }
    }
    
    private func getAppUsageDescription() -> String? {
        let usageMonitor = PremiumManager.shared.usageMonitor
        let monthlyUseDuration = usageMonitor.getAppUsageDuration(.perMonth)
        let annualUseDuration = 12 * monthlyUseDuration
        
        guard monthlyUseDuration > 5 * 60.0 else { return nil }
        guard let monthlyUsage = DateComponentsFormatter.format(
                monthlyUseDuration,
                allowedUnits: [.hour, .minute],
                maxUnitCount: 1,
                style: .full),
            let annualUsage = DateComponentsFormatter.format(
                annualUseDuration,
                allowedUnits: [.hour, .minute],
                maxUnitCount: 1,
                style: .full)
            else { return nil}
        let appUsageDescription = String.localizedStringWithFormat(
            NSLocalizedString(
                "[Premium/usage] App being useful: %@/month, that is around %@/year.",
                value: "App being useful: %@/month, that is around %@/year.",
                comment: "Status: how long the app has been used during some time period. For example: `App being useful: 1hr/month, about 12hr/year`. [monthlyUsage: String, annualUsage: String — already include the time unit (hours, minutes)]"),
            monthlyUsage,
            annualUsage)
        return appUsageDescription
    }
}

extension DateComponentsFormatter {
    static func format(
        _ interval: TimeInterval,
        allowedUnits: NSCalendar.Unit,
        maxUnitCount: Int = 3,
        style: DateComponentsFormatter.UnitsStyle = .abbreviated,
        addRemainingPhrase: Bool = false
        ) -> String?
    {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = allowedUnits
        timeFormatter.collapsesLargestUnit = true
        timeFormatter.includesTimeRemainingPhrase = addRemainingPhrase
        timeFormatter.maximumUnitCount = maxUnitCount
        timeFormatter.unitsStyle = style
        return timeFormatter.string(from: interval)
    }
}
