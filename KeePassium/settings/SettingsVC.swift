//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib
import LocalAuthentication

class SettingsVC: UITableViewController, Refreshable {
    @IBOutlet weak var startWithSearchSwitch: UISwitch!

    @IBOutlet weak var appSafetyCell: UITableViewCell!
    @IBOutlet weak var dataSafetyCell: UITableViewCell!
    @IBOutlet weak var dataBackupCell: UITableViewCell!
    @IBOutlet weak var autoFillCell: UITableViewCell!
    
    @IBOutlet weak var diagnosticLogCell: UITableViewCell!
    @IBOutlet weak var contactSupportCell: UITableViewCell!
    @IBOutlet weak var rateTheAppCell: UITableViewCell!
    @IBOutlet weak var aboutAppCell: UITableViewCell!
    
    @IBOutlet weak var premiumTrialCell: UITableViewCell!
    @IBOutlet weak var premiumStatusCell: UITableViewCell!
    @IBOutlet weak var manageSubscriptionCell: UITableViewCell!
    
    private var settingsNotifications: SettingsNotifications!
    
    private enum CellIndexPath {
        static let premiumTrial = IndexPath(row: 0, section: 0)
        static let premiumStatus = IndexPath(row: 1, section: 0)
        static let manageSubscription = IndexPath(row: 2, section: 0)
    }
    private var hiddenIndexPaths = Set<IndexPath>()
    
    static func make(popoverFromBar barButtonSource: UIBarButtonItem?=nil) -> UIViewController {
        let vc = SettingsVC.instantiateFromStoryboard()
        
        let navVC = UINavigationController(rootViewController: vc)
        navVC.modalPresentationStyle = .popover
        if let popover = navVC.popoverPresentationController {
            popover.barButtonItem = barButtonSource
        }
        return navVC
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        settingsNotifications = SettingsNotifications(observer: self)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshPremiumStatus),
            name: PremiumManager.statusUpdateNotification,
            object: nil)
        refreshPremiumStatus()
        #if DEBUG
        premiumStatusCell.accessoryType = .detailButton
        premiumTrialCell.accessoryType = .detailButton
        #endif
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        settingsNotifications.startObserving()
        refresh()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        settingsNotifications.stopObserving()
        super.viewWillDisappear(animated)
    }
    
    func dismissPopover(animated: Bool) {
        navigationController?.dismiss(animated: animated, completion: nil)
    }
    
    func refresh() {
        let settings = Settings.current
        startWithSearchSwitch.isOn = settings.isStartWithSearch
        
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
    }
    
    private func setCellVisibility(_ cell: UITableViewCell, isHidden: Bool) {
        cell.isHidden = isHidden
        if isHidden {
            switch cell {
            case premiumTrialCell:
                hiddenIndexPaths.insert(CellIndexPath.premiumTrial)
            case premiumStatusCell:
                hiddenIndexPaths.insert(CellIndexPath.premiumStatus)
            case manageSubscriptionCell:
                hiddenIndexPaths.insert(CellIndexPath.manageSubscription)
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
            default:
                break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if hiddenIndexPaths.contains(indexPath) {
            return 0.0
        }
        return super.tableView(tableView, heightForRowAt: indexPath)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }
        switch selectedCell {
        case appSafetyCell:
            let appLockSettingsVC = SettingsAppLockVC.instantiateFromStoryboard()
            show(appLockSettingsVC, sender: self)
        case autoFillCell:
            let autoFillSettingsVC = SettingsAutoFillVC.instantiateFromStoryboard()
            show(autoFillSettingsVC, sender: self)
        case dataSafetyCell:
            let dataProtectionSettingsVC = SettingsDataProtectionVC.instantiateFromStoryboard()
            show(dataProtectionSettingsVC, sender: self)
        case dataBackupCell:
            let dataBackupSettingsVC = SettingsBackupVC.instantiateFromStoryboard()
            show(dataBackupSettingsVC, sender: self)
        case premiumStatusCell:
            break 
        case premiumTrialCell:
            didPressUpgradeToPremium()
        case manageSubscriptionCell:
            didPressManageSubscription()
        case diagnosticLogCell:
            let viewer = ViewDiagnosticsVC.make()
            show(viewer, sender: self)
        case contactSupportCell:
            SupportEmailComposer.show(includeDiagnostics: false)
        case rateTheAppCell:
            AppStoreHelper.writeReview()
        case aboutAppCell:
            let aboutVC = AboutVC.make()
            show(aboutVC, sender: self)
        default:
            break
        }
    }
    
    override func tableView(
        _ tableView: UITableView,
        accessoryButtonTappedForRowWith indexPath: IndexPath)
    {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        switch cell {
#if DEBUG
        case premiumStatusCell, premiumTrialCell:
            didPressUpgradeToPremium()
            refreshPremiumStatus()
#endif
        default:
            assertionFailure() 
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard section == 0 else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }
        
        if PremiumManager.shared.usageMonitor.isEnabled {
            return getAppUsageDescription()
        } else {
            return nil
        }
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        dismissPopover(animated: true)
    }
    
    @IBAction func didChangeStartWithSearch(_ sender: Any) {
        Settings.current.isStartWithSearch = startWithSearchSwitch.isOn
        refresh()
    }
    
    
    private var premiumCoordinator: PremiumCoordinator? 
    func didPressUpgradeToPremium() {
        assert(premiumCoordinator == nil)
        premiumCoordinator = PremiumCoordinator(presentingViewController: self)
        premiumCoordinator!.delegate = self
        premiumCoordinator!.start()
    }
    
    func didPressManageSubscription() {
        guard let application = AppGroup.applicationShared,
            let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions")
            else { assertionFailure(); return }
        application.open(url, options: [:])
    }
    
    
    #if DEBUG
    private let premiumRefreshInterval = 1.0
    #else
    private let premiumRefreshInterval = 10.0
    #endif
    
    @objc private func refreshPremiumStatus() {
        let premiumManager = PremiumManager.shared
        premiumManager.usageMonitor.refresh()
        premiumManager.updateStatus()
        switch premiumManager.status {
        case .initialGracePeriod:
            setCellVisibility(premiumTrialCell, isHidden: false)
            setCellVisibility(premiumStatusCell, isHidden: true)
            setCellVisibility(manageSubscriptionCell, isHidden: true)
            
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
            
            setCellVisibility(premiumTrialCell, isHidden: true)
            setCellVisibility(premiumStatusCell, isHidden: false)
            setCellVisibility(manageSubscriptionCell, isHidden: !product.isSubscription)
            
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
            setCellVisibility(premiumTrialCell, isHidden: false)
            setCellVisibility(premiumStatusCell, isHidden: false)
            setCellVisibility(manageSubscriptionCell, isHidden: false)
            
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
            setCellVisibility(premiumTrialCell, isHidden: false)
            setCellVisibility(premiumStatusCell, isHidden: true)
            setCellVisibility(manageSubscriptionCell, isHidden: true)
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

extension SettingsVC: SettingsObserver {
    func settingsDidChange(key: Settings.Keys) {
        guard key != .recentUserActivityTimestamp else { return }
        refresh()
    }
}

extension SettingsVC: PremiumCoordinatorDelegate {
    func didFinish(_ premiumCoordinator: PremiumCoordinator) {
        self.premiumCoordinator = nil
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
