//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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
    func didPressNetworkAccessSettings(in viewController: SettingsVC)
    func didPressBackupSettings(in viewController: SettingsVC)

    func didPressShowDiagnostics(in viewController: SettingsVC)
    func didPressContactSupport(at popoverAnchor: PopoverAnchor, in viewController: SettingsVC)
    func didPressDonations(at popoverAnchor: PopoverAnchor, in viewController: SettingsVC)
    func didPressAboutApp(in viewController: SettingsVC)
}

final class SettingsVC: UITableViewController, Refreshable {

    @IBOutlet private weak var appSafetyCell: UITableViewCell!
    @IBOutlet private weak var dataSafetyCell: UITableViewCell!
    @IBOutlet private weak var dataBackupCell: UITableViewCell!
    @IBOutlet private weak var autoFillCell: UITableViewCell!
    @IBOutlet private weak var networkAccessCell: UITableViewCell!

    @IBOutlet private weak var searchCell: UITableViewCell!
    @IBOutlet private weak var autoUnlockStartupDatabaseLabel: UILabel!
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

        static let accessControlSectionIndex = 4
        static let appProtection = IndexPath(row: 0, section: accessControlSectionIndex)

        static let supportSectionIndex = 7
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

        title = LString.titleSettings

        if BusinessModel.type == .prepaid || LicenseManager.shared.hasActiveBusinessLicense() {
            isPremiumSectionHidden = true
            premiumSectionFooter = nil
            setCellVisibility(premiumPurchaseCell, isHidden: true)
            setCellVisibility(premiumStatusCell, isHidden: true)
            setCellVisibility(manageSubscriptionCell, isHidden: true)
            setCellVisibility(tipBoxCell, isHidden: true)
        }
        if !ManagedAppConfig.shared.isAppProtectionAllowed {
            setCellVisibility(appSafetyCell, isHidden: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureCells()
        refresh()
    }

    private func configureCells() {
        setLocalizedStrings()

        premiumPurchaseCell.imageView?.image = UIImage.premiumBadge
        tipBoxCell.imageView?.image = .symbol(.heart, tint: .red)
    }

    private func setLocalizedStrings() {
        appHistoryCell.textLabel?.text = LString.titleAppHistory
        premiumPurchaseCell.textLabel?.text = LString.actionUpgradeToPremium
        premiumStatusCell.textLabel?.text = LString.premiumVersion
        premiumStatusCell.detailTextLabel?.text = nil 
        manageSubscriptionCell.textLabel?.text = LString.actionManageSubscriptions

        autoUnlockStartupDatabaseLabel.text = LString.autoOpenPreviousDatabase

        appearanceCell.textLabel?.text = LString.titleAppearanceSettings
        autoFillCell.textLabel?.text = LString.titleAutoFillSettings
        searchCell.textLabel?.text = LString.titleSearchSettings

        appSafetyCell.textLabel?.text = LString.titleAppProtectionSettings
        dataSafetyCell.textLabel?.text = LString.titleDataProtectionSettings
        dataSafetyCell.detailTextLabel?.text = LString.subtitleDataProtectionSettings

        networkAccessCell.textLabel?.text = LString.titleNetworkAccessSettings

        dataBackupCell.textLabel?.text = LString.titleDatabaseBackupSettings
        contactSupportCell.textLabel?.text = LString.actionContactUs
        contactSupportCell.detailTextLabel?.text = LString.subtitleContactUs
        tipBoxCell.textLabel?.text = LString.tipBoxTitle2
        tipBoxCell.detailTextLabel?.text = LString.tipBoxTitle3
        diagnosticLogCell.textLabel?.text = LString.titleDiagnosticLog
        diagnosticLogCell.detailTextLabel?.text = LString.subtitleDiagnosticLog
        aboutAppCell.textLabel?.text = LString.titleAboutKeePassium
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

        if settings.isNetworkAccessAllowed {
            networkAccessCell.detailTextLabel?.text = LString.statusFeatureOn
        } else {
            networkAccessCell.detailTextLabel?.text = LString.statusFeatureOff
        }
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
            case appSafetyCell:
                hiddenIndexPaths.insert(CellIndexPath.appProtection)
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
            case appSafetyCell:
                hiddenIndexPaths.remove(CellIndexPath.appProtection)
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
        case networkAccessCell:
            delegate?.didPressNetworkAccessSettings(in: self)
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

    @IBAction private func didToggleAutoUnlockStartupDatabase(_ sender: UISwitch) {
        Settings.current.isAutoUnlockStartupDatabase = sender.isOn
        showNotificationIfManaged(setting: .autoUnlockStartupDatabase)
    }


    #if DEBUG
    private let premiumRefreshInterval = 1.0
    #else
    private let premiumRefreshInterval = 20.0
    #endif

    @objc private func refreshPremiumStatus() {
        if BusinessModel.type == .prepaid || LicenseManager.shared.hasActiveBusinessLicense() {
            return
        }

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
        DispatchQueue.main.asyncAfter(deadline: .now() + premiumRefreshInterval) { [weak self] in
            self?.refreshPremiumStatus()
        }
    }

    private func displayInitialGracePeriodStatus(_ purchaseHistory: PurchaseHistory) {
        if Settings.current.isTestEnvironment {
            let secondsLeft = PremiumManager.shared.gracePeriodRemaining
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
        case .version88,
             .version96,
             .version99,
             .version120,
             .version139,
             .version154:
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
        guard monthlyUseDuration > 5 * TimeInterval.minute else {
            return nil
        }
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
