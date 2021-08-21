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
    func didPressDonations(at popoverAnchor: PopoverAnchor, in viewController: SettingsVC)
    func didPressAboutApp(in viewController: SettingsVC)
}

final class SettingsVC: NavTableViewController, Refreshable {

    @IBOutlet private weak var appSafetyCell: UITableViewCell!
    @IBOutlet private weak var dataSafetyCell: UITableViewCell!
    @IBOutlet private weak var dataBackupCell: UITableViewCell!
    @IBOutlet private weak var autoFillCell: UITableViewCell!
    
    @IBOutlet private weak var searchCell: UITableViewCell!
    @IBOutlet private weak var autoUnlockStartupDatabaseSwitch: UISwitch!
    @IBOutlet private weak var appearanceCell: UITableViewCell!
    
    @IBOutlet private weak var diagnosticLogCell: UITableViewCell!
    @IBOutlet private weak var contactSupportCell: UITableViewCell!
    @IBOutlet private weak var tipBoxCell: UITableViewCell!
    @IBOutlet private weak var aboutAppCell: UITableViewCell!
    
    @IBOutlet private weak var premiumPurchaseCell: UITableViewCell!
    @IBOutlet private weak var premiumStatusCell: UITableViewCell!
    @IBOutlet private weak var manageSubscriptionCell: UITableViewCell!
    @IBOutlet private weak var appHistoryCell: UITableViewCell!
    
    weak var delegate: SettingsViewControllerDelegate?
    
    private var isPremiumSectionHidden = false
    private var premiumSectionFooter: String?
    
    private enum CellIndexPath {
        static let premiumSectionIndex = 1
        static let premiumTrial = IndexPath(row: 0, section: premiumSectionIndex)
        static let premiumStatus = IndexPath(row: 1, section: premiumSectionIndex)
        static let manageSubscription = IndexPath(row: 2, section: premiumSectionIndex)

        static let supportSectionIndex = 6
        static let tipBoxCell = IndexPath(row: 1, section: supportSectionIndex)
    }
    private var hiddenIndexPaths = Set<IndexPath>()
    
    private lazy var usageTimeFormatter: DateComponentsFormatter = {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = [.hour, .minute]
        timeFormatter.collapsesLargestUnit = true
        timeFormatter.includesTimeRemainingPhrase = false
        timeFormatter.maximumUnitCount = 1
        timeFormatter.unitsStyle = .full
        return timeFormatter
    }()
    
    private lazy var expiryTimeFormatter: DateComponentsFormatter = {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = [.day, .hour, .minute]
        timeFormatter.collapsesLargestUnit = true
        timeFormatter.includesTimeRemainingPhrase = false
        timeFormatter.maximumUnitCount = 1
        timeFormatter.unitsStyle = .full
        return timeFormatter
    }()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        
        if BusinessModel.type == .prepaid {
            isPremiumSectionHidden = true
            premiumSectionFooter = nil
            setCellVisibility(premiumPurchaseCell, isHidden: true)
            setCellVisibility(premiumStatusCell, isHidden: true)
            setCellVisibility(manageSubscriptionCell, isHidden: true)
            setCellVisibility(tipBoxCell, isHidden: true)
        }
        
        premiumStatusCell.detailTextLabel?.text = nil 
        tipBoxCell.textLabel?.text = LString.tipBoxTitle2
        tipBoxCell.detailTextLabel?.text = LString.tipBoxTitle3
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }
    
    func refresh() {
        let settings = Settings.current
        autoUnlockStartupDatabaseSwitch.isOn = settings.isAutoUnlockStartupDatabase

        if let biometryTypeName = LAContext.getBiometryType().name {
            appSafetyCell.detailTextLabel?.text = String.localizedStringWithFormat(
                LString.appLockWithBiometricsSubtitleTemplate,
                biometryTypeName)
        } else {
            appSafetyCell.detailTextLabel?.text = LString.appLockWithPasscodeSubtitle
        }
        refreshPremiumStatus()
        
        contactSupportCell.accessibilityValue = SupportEmailComposer.getSupportEmail()
    }
    
    
    private func setCells(show cellsToShow: [UITableViewCell], hide cellsToHide: [UITableViewCell]) {
        cellsToShow.forEach {
            self.setCellVisibility($0, isHidden: false)
        }
        cellsToHide.forEach {
            self.setCellVisibility($0, isHidden: true)
        }
    }
    
    private func setCellVisibility(_ cell: UITableViewCell, isHidden: Bool) {
        cell.isHidden = isHidden
        if isHidden {
            switch cell {
            case premiumPurchaseCell:
                hiddenIndexPaths.insert(CellIndexPath.premiumTrial)
            case premiumStatusCell:
                hiddenIndexPaths.insert(CellIndexPath.premiumStatus)
            case manageSubscriptionCell:
                hiddenIndexPaths.insert(CellIndexPath.manageSubscription)
            case tipBoxCell:
                hiddenIndexPaths.insert(CellIndexPath.tipBoxCell)
            default:
                break
            }
        } else {
            switch cell {
            case premiumPurchaseCell:
                hiddenIndexPaths.remove(CellIndexPath.premiumTrial)
            case premiumStatusCell:
                hiddenIndexPaths.remove(CellIndexPath.premiumStatus)
            case manageSubscriptionCell:
                hiddenIndexPaths.remove(CellIndexPath.manageSubscription)
            case tipBoxCell:
                hiddenIndexPaths.remove(CellIndexPath.tipBoxCell)
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
             premiumPurchaseCell:
            delegate?.didPressUpgradeToPremium(in: self)
        case manageSubscriptionCell:
            delegate?.didPressManageSubscription(in: self)
        case appHistoryCell:
            delegate?.didPressShowAppHistory(in: self)
        case diagnosticLogCell:
            delegate?.didPressShowDiagnostics(in: self)
        case contactSupportCell:
            delegate?.didPressContactSupport(at: popoverAnchor, in: self)
        case tipBoxCell:
            delegate?.didPressDonations(at: popoverAnchor, in: self)
        case aboutAppCell:
            delegate?.didPressAboutApp(in: self)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == CellIndexPath.premiumSectionIndex {
            return premiumSectionFooter
        }
        return super.tableView(tableView, titleForFooterInSection: section)
    }
    
    @IBAction func didToggleAutoUnlockStartupDatabase(_ sender: UISwitch) {
        Settings.current.isAutoUnlockStartupDatabase = sender.isOn
    }
    
    
    #if DEBUG
    private let premiumRefreshInterval = 1.0
    #else
    private let premiumRefreshInterval = 20.0
    #endif
    
    @objc private func refreshPremiumStatus() {
        guard BusinessModel.type != .prepaid else { return }
        
        let premiumManager = PremiumManager.shared
        premiumManager.usageMonitor.refresh()
        premiumManager.updateStatus()

        premiumSectionFooter = nil 
        let purchaseHistory = premiumManager.getPurchaseHistory()
        switch premiumManager.status {
        case .initialGracePeriod:
            displayInitialGracePeriodStatus(purchaseHistory)
        case .freeLightUse:
            displayFreeStatus(heavyUse: false, purchaseHistory)
        case .freeHeavyUse:
            displayFreeStatus(heavyUse: true, purchaseHistory)
        case .subscribed:
            displaySubscribedStatus(purchaseHistory)
        case .lapsed:
            displayLapsedStatus(purchaseHistory)
        case .fallback:
            guard let fallbackDate = purchaseHistory.premiumFallbackDate else {
                assertionFailure()
                return
            }
            displayPurchasedStatus(fallbackDate: fallbackDate, purchaseHistory)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + premiumRefreshInterval) {
            [weak self] in
            self?.refreshPremiumStatus()
        }
    }
    
    private func displayInitialGracePeriodStatus(_ purchaseHistory: PurchaseHistory) {
        if Settings.current.isTestEnvironment {
            let secondsLeft = PremiumManager.shared.gracePeriodSecondsRemaining
            Diag.debug("Initial setup period: \(secondsLeft) seconds remaining")
        }
        displayFreeStatus(heavyUse: false, purchaseHistory)
    }
    
    private func displayFreeStatus(heavyUse: Bool, _ purchaseHistory: PurchaseHistory) {
        if let fallbackDate = purchaseHistory.premiumFallbackDate {
            displayPurchasedStatus(fallbackDate: fallbackDate, purchaseHistory)
            return
        }

        setCells(
            show: [premiumPurchaseCell],
            hide: [premiumStatusCell, manageSubscriptionCell]
        )
        if heavyUse {
            premiumSectionFooter = getAppUsageDescription()
        }
    }
    
    private func displaySubscribedStatus(_ purchaseHistory: PurchaseHistory) {
        premiumStatusCell.detailTextLabel?.textColor = .auxiliaryText

        guard let expiryDate = purchaseHistory.latestPremiumExpiryDate,
              let product = purchaseHistory.latestPremiumProduct
        else {
            Diag.error("Subscribed, but no product info?")
            assertionFailure()
            premiumStatusCell.detailTextLabel?.text = "?"
            return
        }
        
        setCells(show: [premiumStatusCell], hide: [premiumPurchaseCell])
        setCellVisibility(manageSubscriptionCell, isHidden: !product.isSubscription)
        
        let premiumStatusText: String
        switch product {
        case .betaForever:
            premiumStatusText = LString.premiumStatusBetaTesting
        case .forever,
             .forever2:
            premiumStatusText = LString.premiumStatusValidForever
        case .montlySubscription,
             .yearlySubscription:
            let expiryDateString = DateFormatter.localizedString(
                from: expiryDate,
                dateStyle: .medium,
                timeStyle: Settings.current.isTestEnvironment ? .short : .none)
            premiumStatusText = String.localizedStringWithFormat(
                LString.premiumStatusNextRenewalTemplate,
                expiryDateString)
        case .version88:
            premiumStatusText = ""
            assertionFailure("Cannot be subscribed to a version purchase")
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            premiumStatusText = ""
            assertionFailure("This is a consumable purchase, why are we here?")
        }
        premiumStatusCell.detailTextLabel?.text = premiumStatusText
    }
    
    private func displayLapsedStatus(_ purchaseHistory: PurchaseHistory) {
        if let fallbackDate = purchaseHistory.premiumFallbackDate {
            displayPurchasedStatus(fallbackDate: fallbackDate, purchaseHistory)
            return
        }
        
        setCells(
            show: [premiumStatusCell, manageSubscriptionCell],
            hide: [premiumPurchaseCell]
        )
        let premiumStatusText: String
        if let premiumExpiryDate = purchaseHistory.latestPremiumExpiryDate {
            let timeSinceExpiration = -premiumExpiryDate.timeIntervalSinceNow
            let timeFormatted = expiryTimeFormatter.string(from: timeSinceExpiration) ?? "?"
            premiumStatusText = String.localizedStringWithFormat(
                LString.premiumStatusExpiredTemplate,
                timeFormatted)
        } else {
            assertionFailure()
            Diag.debug("Lapsed status without expiry date")
            premiumStatusText = "?"
        }
        premiumStatusCell.detailTextLabel?.text = premiumStatusText
        premiumStatusCell.detailTextLabel?.textColor = .errorMessage
    }
    
    private func displayPurchasedStatus(fallbackDate: Date, _ purchaseHistory: PurchaseHistory) {
        premiumStatusCell.detailTextLabel?.textColor = .auxiliaryText
        if purchaseHistory.containsLifetimePurchase {
            setCells(
                show: [premiumStatusCell],
                hide: [premiumPurchaseCell, manageSubscriptionCell])
            premiumStatusCell.detailTextLabel?.text = LString.premiumStatusValidForever
            return
        }
        
        setCells(
            show: [premiumStatusCell],
            hide: [premiumPurchaseCell, manageSubscriptionCell])
        
        AppHistory.load(completion: { [weak self] appHistory in
            guard let self = self else { return }
            let purchasedVersion = appHistory?.versionOnDate(fallbackDate) ?? "?"
            let currentVersion = AppInfo.version
            var textParts = [String]()
            textParts.append(String.localizedStringWithFormat(
                LString.premiumStatusLicensedVersionTemplate,
                purchasedVersion
            ))
            if purchasedVersion != currentVersion {
                textParts.append(String.localizedStringWithFormat(
                    LString.premiumStatusCurrentVersionTemplate,
                    currentVersion
                ))
            }
            self.premiumStatusCell.detailTextLabel?.text = textParts.joined(separator: "\n")
            self.tableView.reloadData()
        })
    }
    
    private func getAppUsageDescription() -> String? {
        let usageMonitor = PremiumManager.shared.usageMonitor
        guard usageMonitor.isEnabled else {
            return nil
        }
        
        let monthlyUseDuration = usageMonitor.getAppUsageDuration(.perMonth)
        let annualUseDuration = 12 * monthlyUseDuration
        
        guard monthlyUseDuration > 5 * 60.0 else { return nil }
        guard let monthlyUsage = usageTimeFormatter.string(from: monthlyUseDuration),
              let annualUsage = usageTimeFormatter.string(from: annualUseDuration)
        else {
            return nil
        }
        let appUsageDescription = String.localizedStringWithFormat(
            LString.appBeingUsefulTemplate,
            monthlyUsage,
            annualUsage)
        return appUsageDescription
    }
}

extension LString {
    fileprivate static let appLockWithBiometricsSubtitleTemplate = NSLocalizedString(
        "[Settings/AppLock/subtitle] App Lock, %@, timeout",
        value: "App Lock, %@, timeout",
        comment: "Settings: subtitle of the `App Protection` section. biometryTypeName will be either 'Touch ID' or 'Face ID'. [biometryTypeName: String]")
    fileprivate static let appLockWithPasscodeSubtitle = NSLocalizedString(
        "[Settings/AppLock/subtitle] App Lock, passcode, timeout",
        value: "App Lock, passcode, timeout",
        comment: "Settings: subtitle of the `App Protection` section when biometric auth is not available.")
    
    public static let premiumStatusBetaTesting = NSLocalizedString(
        "[Premium/status] Beta testing",
        value: "Beta testing",
        comment: "Status: special premium for beta-testing environment is active")
    public static let premiumStatusValidForever = NSLocalizedString(
        "[Premium/status] Valid forever",
        value: "Valid forever",
        comment: "Status: validity period of once-and-forever premium")
    public static let premiumStatusNextRenewalTemplate = NSLocalizedString(
        "[Premium/status] Next renewal on %@",
        value: "Next renewal on %@",
        comment: "Status: scheduled renewal date of a premium subscription. For example: `Next renewal on 1 Jan 2050`. [expiryDateString: String]")
    public static let premiumStatusExpiredTemplate = NSLocalizedString(
        "[Premium/status] Expired %@ ago. Please renew.",
        value: "Expired %@ ago. Please renew.",
        comment: "Status: premium subscription has expired. For example: `Expired 1 day ago`. [timeFormatted: String, includes the time unit (day, hour, minute)]")
    public static let premiumStatusLicensedVersionTemplate = NSLocalizedString(
        "[Premium/status] Licensed version: %@",
        value: "Licensed version: %@",
        comment: "Status: licensed premium version of the app. For example: `Licensed version: 1.23`. [version: String]")
    public static let premiumStatusCurrentVersionTemplate = NSLocalizedString(
        "[Premium/status] Current version: %@",
        value: "Current version: %@",
        comment: "Status: current version of the app. For example: `Current version: 1.23`. Should be similar to the `Licensed version` string. [version: String]")
    
    public static let appBeingUsefulTemplate = NSLocalizedString(
        "[Premium/usage] App being useful: %@/month, that is around %@/year.",
        value: "App being useful: %@/month, that is around %@/year.",
        comment: "Status: how long the app has been used during some time period. For example: `App being useful: 1hr/month, about 12hr/year`. [monthlyUsage: String, annualUsage: String — already include the time unit (hours, minutes)]")
}
