//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact us.

import KeePassiumLib

extension MainSettingsCoordinator {
    internal func _getPremiumState() -> SettingsPremiumState {
        if BusinessModel.type == .prepaid || LicenseManager.shared.hasActiveBusinessLicense() {
            return .prepaid
        }

        let premiumManager = PremiumManager.shared
        premiumManager.usageMonitor.refresh()
        premiumManager.updateStatus()
        let purchaseHistory = premiumManager.getPurchaseHistory()
        let fallbackStatus = getFallbackStatus(purchaseHistory)

        switch premiumManager.status {
        case .initialGracePeriod, .freeHeavyUse:
            let appUsageDescription = getAppUsageDescription()
            return fallbackStatus ?? .free(description: appUsageDescription)
        case .freeLightUse:
            return fallbackStatus ?? .free(description: nil)
        case .subscribed:
            guard let product = purchaseHistory.latestPremiumProduct else {
                assertionFailure("Subscribed, but no product info")
                return .active(description: "?", isSubscription: true)
            }
            let description = getActiveSubscriptionDescription(
                product: product,
                expiryDate: purchaseHistory.latestPremiumExpiryDate
            )
            return .active(description: description, isSubscription: product.isSubscription)
        case .lapsed:
            let description = getLapsedSubscriptionDescription(purchaseHistory)
            return fallbackStatus ?? .active(description: description, isSubscription: true)
        case .fallback:
            guard let fallbackStatus else {
                assertionFailure()
                return .fallback(description: "?")
            }
            return fallbackStatus
        }
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
        let formatter = getUsageTimeFormatter()
        guard let monthlyUsage = formatter.string(from: monthlyUseDuration),
              let annualUsage = formatter.string(from: annualUseDuration)
        else {
            return nil
        }
        let appUsageDescription = String.localizedStringWithFormat(
            LString.appBeingUsefulTemplate,
            monthlyUsage,
            annualUsage)
        return appUsageDescription
    }

    private func getUsageTimeFormatter() -> DateComponentsFormatter {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = [.hour, .minute]
        timeFormatter.collapsesLargestUnit = true
        timeFormatter.includesTimeRemainingPhrase = false
        timeFormatter.maximumUnitCount = 1
        timeFormatter.unitsStyle = .full
        return timeFormatter
    }

    private func getActiveSubscriptionDescription(product: InAppProduct, expiryDate: Date?) -> String {
        guard let expiryDate else {
            Diag.error("Active premium plan without an expiry date?")
            assertionFailure()
            return "?"
        }
        switch product {
        case .betaForever:
            return LString.premiumStatusBetaTesting
        case .forever,
             .forever2:
            return LString.premiumStatusValidForever
        case .montlySubscription,
             .yearlySubscription:
            let expiryDateString = DateFormatter.localizedString(
                from: expiryDate,
                dateStyle: .medium,
                timeStyle: Settings.current.isTestEnvironment ? .short : .none)
            return String.localizedStringWithFormat(
                LString.premiumStatusNextRenewalTemplate,
                expiryDateString)
        case .version88,
             .version96,
             .version99,
             .version120,
             .version139,
             .version154:
            assertionFailure("Cannot be subscribed to a version purchase")
            return ""
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            assertionFailure("This is a consumable purchase, why are we here?")
            return ""
        }
    }

    private func getLapsedSubscriptionDescription(_ purchaseHistory: PurchaseHistory) -> String {
        guard let premiumExpiryDate = purchaseHistory.latestPremiumExpiryDate else {
            Diag.debug("Lapsed status without an expiry date")
            assertionFailure()
            return "?"
        }
        let timeSinceExpiration = -premiumExpiryDate.timeIntervalSinceNow
        let timeFormatted = getExpiryTimeFormatter().string(from: timeSinceExpiration) ?? "?"
        return String.localizedStringWithFormat(
            LString.premiumStatusExpiredTemplate,
            timeFormatted)
    }

    private func getExpiryTimeFormatter() -> DateComponentsFormatter {
        let timeFormatter = DateComponentsFormatter()
        timeFormatter.allowedUnits = [.day, .hour, .minute]
        timeFormatter.collapsesLargestUnit = true
        timeFormatter.includesTimeRemainingPhrase = false
        timeFormatter.maximumUnitCount = 1
        timeFormatter.unitsStyle = .full
        return timeFormatter
    }

    private func getFallbackStatus(_ purchaseHistory: PurchaseHistory) -> SettingsPremiumState? {
        guard let fallbackDate = purchaseHistory.premiumFallbackDate else {
            return nil
        }
        if purchaseHistory.containsLifetimePurchase {
            return .fallback(description: LString.premiumStatusValidForever)
        }

        guard let _fallbackReleaseInfo else {
            loadFallbackReleaseInfo(on: fallbackDate) { [weak self] releaseInfo in
                self?._fallbackReleaseInfo = releaseInfo ?? "?"
                self?.refresh()
            }
            return .fallback(description: "…")
        }

        let purchasedVersion = _fallbackReleaseInfo
        let currentVersion = AppInfo.version

        var descriptionParts = [String]()
        descriptionParts.append(String.localizedStringWithFormat(
            LString.premiumStatusLicensedVersionTemplate,
            purchasedVersion
        ))
        if purchasedVersion != currentVersion {
            descriptionParts.append(String.localizedStringWithFormat(
                LString.premiumStatusCurrentVersionTemplate,
                currentVersion
            ))
        }
        return .fallback(description: descriptionParts.joined(separator: "\n"))
    }

    private func loadFallbackReleaseInfo(on date: Date, completion: @escaping (String?) -> Void) {
        AppHistory.load { appHistory in
            let releaseVersion = appHistory?.versionOnDate(date)
            completion(releaseVersion)
        }
    }
}
