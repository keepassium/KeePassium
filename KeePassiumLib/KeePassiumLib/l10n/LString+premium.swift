//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

// swiftlint:disable line_length
extension LString {

    public static let errorNoPurchasesAvailable = NSLocalizedString(
        "[Premium/Upgrade] Hmm, there are no upgrades available. This should not happen, please contact support.",
        bundle: Bundle.framework,
        value: "Hmm, there are no upgrades available. This should not happen, please contact support.",
        comment: "Error message: AppStore returned no available in-app purchase options")

    public static let subscriptionConditions = NSLocalizedString(
        "[Premium/Subscription/Legal/text]",
        bundle: Bundle.framework,
        value: """
Payment will be charged to your Apple ID account at the confirmation of purchase.

Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period.

You can manage and cancel your subscriptions by going to your account settings on the App Store after purchase.
""",
        comment: "Subscription conditions")

    public static let actionManageSubscriptions = NSLocalizedString(
        "[Premium/ManageSubscriptions/action]",
        bundle: Bundle.framework,
        value: "Manage subscriptions",
        comment: "Action: open AppStore subscription management page")


    public static let premiumFreePlanTitle = NSLocalizedString(
        "[Premium/Price Plan/Free/title]",
        bundle: Bundle.framework,
        value: "Free",
        comment: "Name of the free pricing plan")
    public static let premiumFreePlanPrice = NSLocalizedString(
        "[Premium/Price Plan/Free/price]",
        bundle: Bundle.framework,
        value: "Free",
        comment: "Price of the free pricing plan")
    public static let premiumPopularPlan = NSLocalizedString(
        "[Premium/Price Plan/popular]",
        bundle: Bundle.framework,
        value: "Popular",
        comment: "Marks the default pricing plan")

    public static let priceTemplateMonthly = NSLocalizedString(
        "[Premium/Upgrade/price] %@ / month",
        bundle: Bundle.framework,
        value: "%@ / month",
        comment: "Product price for monthly premium subscription. [localizedPrice: String]")
    public static let priceTemplateYearly = NSLocalizedString(
        "[Premium/Upgrade/price] %@ / year",
        bundle: Bundle.framework,
        value: "%@ / year",
        comment: "Product price for annual premium subscription. [localizedPrice: String]")
    public static let priceTemplateOnce = NSLocalizedString(
        "[Premium/Upgrade/price] %@ once",
        bundle: Bundle.framework,
        value: "%@ once",
        comment: "Product price for once-and-forever premium. [localizedPrice: String]")
    public static let priceTemplateEquivalentMonthly = NSLocalizedString(
        "[Premium/Upgrade/price] around %@ / month",
        bundle: Bundle.framework,
        value: "≈ %@ / month",
        comment: "Equivalent monthly price for an annual subscription. For example: `$12/year ≈ $1 / month`")
    public static let trialConditionsTemplate = NSLocalizedString(
        "[Premium/Trial/trial then price]",
        bundle: Bundle.framework,
        value: "%@ free, then %@",
        comment: "Trial conditions. For example `30 days free, then $1 per month`")

    public static let premiumWhatYouGet = NSLocalizedString(
        "[Premium/Benefits/Positive/header] ",
        bundle: Bundle.framework,
        value: "What you get",
        comment: "List of premium benefits/advantages")
    public static let premiumWhatYouMiss = NSLocalizedString(
        "[Premium/Benefits/Negative/header] ",
        bundle: Bundle.framework,
        value: "What you are missing",
        comment: "List of premium benefits/advantages")


    public static let planConditionUpdatesAndFixes = NSLocalizedString(
        "[Premium/Price Plan/Conditions/updates and bug fixes]",
        bundle: Bundle.framework,
        value: "Updates and bug fixes",
        comment: "What's included in a price plan")
    public static let planConditionFreemiumReminders = NSLocalizedString(
        "[Premium/Price Plan/Conditions/freemium reminders]",
        bundle: Bundle.framework,
        value: "Freemium reminders",
        comment: "What's included in a free plan: reminders that the version is free")
    public static let planConditionCommunitySupport = NSLocalizedString(
        "[Premium/Price Plan/Conditions/community support]",
        bundle: Bundle.framework,
        value: "Customer support: Online forums",
        comment: "What's included in a free plan: support via forums (as opposed to email support)")
    public static let planConditionEmailSupport = NSLocalizedString(
        "[Premium/Price Plan/Conditions/email support]",
        bundle: Bundle.framework,
        value: "Customer support: Email",
        comment: "What's included in a price plan: support via email")
    public static let planConditionOneYearEmailSupport = NSLocalizedString(
        "[Premium/Price Plan/Conditions/1 year email support]",
        bundle: Bundle.framework,
        value: "One year of email support",
        comment: "What's included in a price plan: 1 year of support via email")
    public static let planConditionAllPremiumFeatures = NSLocalizedString(
        "[Premium/Price Plan/Conditions/all premium features]",
        bundle: Bundle.framework,
        value: "All premium features",
        comment: "What's included in a price plan")
    public static let planConditionCurrentPremiumFeatures = NSLocalizedString(
        "[Premium/Price Plan/Conditions/current premium features]",
        bundle: Bundle.framework,
        value: "Current premium features",
        comment: "What's included in a price plan: existing premium features only (as opposed to `current + future`)")
    public static let planConditionUpcomingPremiumFeatures = NSLocalizedString(
        "[Premium/Price Plan/Conditions/future premium features]",
        bundle: Bundle.framework,
        value: "Future premium features",
        comment: "What's included in a price plan: upcoming premium features (as opposed to `current only`)")
    public static let planConditionPerpetualFallback = NSLocalizedString(
        "[Premium/Price Plan/Conditions/perpetual fallback]",
        bundle: Bundle.framework,
        value: "Rent-to-own license (Perpetual fallback license)",
        comment: "What's included in a price plan. Please leave `perpetual fallback license` in English.")
    public static let planConditionSubscriptionAsPurchase = NSLocalizedString(
        "[Premium/Price Plan/Conditions/subscription as purchase]",
        bundle: Bundle.framework,
        value: "Subscription as a purchase",
        comment: "What's included in a subscription plan. By subscribing for a certain period, the user receives a permanent license for a version of the app. More info: https://keepassium.com/articles/perpetual-fallback-license/")
    public static let planConditionFamilySharing = NSLocalizedString(
        "[Premium/Price Plan/Conditions/family sharing]",
        bundle: Bundle.framework,
        value: "Family Sharing",
        comment: "Family Sharing programme. Translation must match Apple's: https://www.apple.com/family-sharing/")
    public static let planConditionFullPriceUpgrade = NSLocalizedString(
        "[Premium/Price Plan/Conditions/full price upgrade]",
        bundle: Bundle.framework,
        value: "Premium features added in the future would require a new purchase at full price.",
        comment: "Upgrade conditions for current-version premium purchase.")


    public static let premiumCallToActionFree = NSLocalizedString(
        "[Premium/CallToAction/free]",
        bundle: Bundle.framework,
        value: "Continue Testing",
        comment: "Call to action: continue using the free version")
    public static let premiumCallToActionStartTrial = NSLocalizedString(
        "[Premium/CallToAction/startTrial]",
        bundle: Bundle.framework,
        value: "Try it free",
        comment: "Call to action: start free trial")
    public static let premiumCallToActionUpgradeNow = NSLocalizedString(
        "[Premium/CallToAction/upgradeNow]",
        bundle: Bundle.framework,
        value: "Upgrade Now",
        comment: "Call to action: upgrade to premium")
    public static let premiumCallToActionBuyNow = NSLocalizedString(
        "[Premium/CallToAction/buyNow]",
        bundle: Bundle.framework,
        value: "Buy Now",
        comment: "Call to action")


    public static let statusContactingAppStore = NSLocalizedString(
        "[Premium/Upgrade/Progress] Contacting AppStore...",
        bundle: Bundle.framework,
        value: "Contacting AppStore...",
        comment: "Status message when downloading available in-app purchases")
    public static let statusPurchasing = NSLocalizedString(
        "[Premium/Upgrade/Progress] Purchasing...",
        bundle: Bundle.framework,
        value: "Purchasing...",
        comment: "Status: in-app purchase started")
    public static let statusDeferredPurchase = NSLocalizedString(
        "[Premium/Upgrade/Deferred/text] Thank you! You can use KeePassium while purchase is awaiting approval.",
        bundle: Bundle.framework,
        value: "Thank you! You can use KeePassium while purchase is awaiting approval.",
        comment: "Message shown when in-app purchase is deferred until approval (parental or corporate).")


    public static let titlePurchaseSuccess = NSLocalizedString(
        "[Premium/Upgrade/Success/thankYou]",
        bundle: Bundle.framework,
        value: "Thank you for the purchase!",
        comment: "Message shown after buying or subscribing.")
    public static let messageCancelOldSubscriptions = NSLocalizedString(
        "[Premium/Upgrade/cancelOngoingSubscription]",
        bundle: Bundle.framework,
        value: "Please check if you need to cancel your old subscription.",
        comment: "Message shown after buying a lifetime version.")


    public static let titlePurchaseRestored = NSLocalizedString(
        "[Premium/Upgrade/Restored/title] Purchase Restored",
        bundle: Bundle.framework,
        value: "Purchase Restored",
        comment: "Title of the message shown after in-app purchase was successfully restored")
    public static let purchaseRestored = NSLocalizedString(
        "[Premium/Upgrade/Restored/text] Upgrade successful, enjoy the app!",
        bundle: Bundle.framework,
        value: "Upgrade successful, enjoy the app!",
        comment: "Text of the message shown after in-app purchase was successfully restored")

    public static let titleRestorePurchaseError = NSLocalizedString(
        "[Premium/Upgrade/RestoreFailed/title] Sorry",
        bundle: Bundle.framework,
        value: "Sorry",
        comment: "Title of an error message: there were no in-app purchases that can be restored")
    public static let errorNoPreviousPurchaseToRestore = NSLocalizedString(
        "[Premium/Upgrade/RestoreFailed/text] No previous purchase could be restored.",
        bundle: Bundle.framework,
        value: "No previous purchase could be restored.",
        comment: "Text of an error message: there were no in-app purchases that can be restored")


    public static let perpetualLicense = NSLocalizedString(
        "[Premium/perpetualLicense]",
        bundle: Bundle.framework,
        value: "Perpetual license",
        comment: "Name of the permanent/never-ending license.")

    public static let perpetualLicenseStatus = NSLocalizedString(
        "[Premium/PerpetualLicense/status]",
        bundle: Bundle.framework,
        value: "You have a perpetual license for all the versions before %@.",
        comment: "[formattedDate: String]")


    public static let premiumManualUpgradeTitle = NSLocalizedString(
        "[AutoFill/Premium/Upgrade/Manual/title] Premium Upgrade",
        bundle: Bundle.framework,
        value: "Premium Upgrade",
        comment: "Title of a message related to upgrading to the premium version")
    public static let premiumManualUpgradeMessage = NSLocalizedString(
        "[AutoFill/Premium/Upgrade/Manual/text] To upgrade, please manually open KeePassium from your home screen.",
        bundle: Bundle.framework,
        value: "To upgrade, please manually open KeePassium from your home screen.",
        comment: "Message shown when AutoFill cannot automatically open the main app for upgrading to a premium version.")
}

extension LString {
    public static let premiumFeatureGenericTitle = NSLocalizedString(
        "[PremiumFeature/Generic/title]",
        bundle: Bundle.framework,
        value: "Premium Feature",
        comment: "A generic title of a premium feature")
    public static let premiumFeatureGenericDescription = NSLocalizedString(
        "[PremiumFeature/Generic/description]",
        bundle: Bundle.framework,
        value: "Upgrade to Premium and enjoy KeePassium at its best.",
        comment: "A generic description of a premium feature")

    public static let premiumFeatureMultipleDatabasesTitle = NSLocalizedString(
            "[PremiumFeature/MultiDB/title] Multiple Databases",
            bundle: Bundle.framework,
            value: "Multiple Databases",
            comment: "Title of a premium feature: ability to use multiple databases (In Title Case)")
    public static let premiumFeatureMultipleDatabasesDescription = NSLocalizedString(
        "[PremiumFeature/MultiDB/description] Easily switch between databases in the premium version.",
        bundle: Bundle.framework,
        value: "Easily switch between databases in the premium version.",
        comment: "Description/advertisement for the `Multiple Databases` premium feature")
    public static let premiumBenefitMultipleDatabasesTitle = NSLocalizedString(
        "[Premium/Benefits/MultiDB/title]",
        bundle: Bundle.framework,
        value: "Sync with the team",
        comment: "Title of a premium feature")
    public static let premiumBenefitMultipleDatabasesDescription = NSLocalizedString(
        "[Premium/Benefits/MultiDB/details]",
        bundle: Bundle.framework,
        value: "Add multiple databases and quickly switch between them.",
        comment: "Explanation of the premium feature")

    public static let premiumFeatureHardwareKeysTitle = NSLocalizedString(
            "[PremiumFeature/HardwareKeys/title] Hardware Keys",
            bundle: Bundle.framework,
            value: "Hardware Keys",
            comment: "Title of a premium feature: ability use hardware keys (e.g. YubiKey) for encryption (In Title Case)")
    public static let premiumFeatureHardwareKeysDescription = NSLocalizedString(
        "[PremiumFeature/HardwareKeys/description]",
        bundle: Bundle.framework,
        value: "Strengthen your security with hardware keys (YubiKey) in the premium version.",
        comment: "Description/advertisement for the `Hardware Keys` premium feature")
    public static let premiumBenefitHardwareKeysTitle = NSLocalizedString(
        "[Premium/Benefits/HardwareKeys/title]",
        bundle: Bundle.framework,
        value: "Use hardware keys",
        comment: "Title of a premium feature")
    public static let premiumBenefitHardwareKeysDescription = NSLocalizedString(
        "[Premium/Benefits/HardwareKeys/details]",
        bundle: Bundle.framework,
        value: "Protect your secrets with a hardware key, such as YubiKey.",
        comment: "Explanation of the premium feature")

    public static let premiumFeatureQuickAutoFillTitle = NSLocalizedString(
        "[PremiumFeature/QuickAutoFill/title]",
        bundle: Bundle.framework,
        value: "Quick AutoFill",
        comment: "Title of a premium feature: show relevant AutoFill entries right under the input field")
    public static let premiumFeatureQuickAutoFillDescription = NSLocalizedString(
        "[PremiumFeature/QuickAutoFill/description]",
        bundle: Bundle.framework,
        value: "Fill out login forms with a single tap, without even opening KeePassium.",
        comment: "Description/call to action for the `Quick AutoFill` premium feature.")
    public static let premiumBenefitQuickAutoFillTitle = premiumFeatureQuickAutoFillTitle
    public static let premiumBenefitQuickAutoFillDescription = premiumFeatureQuickAutoFillDescription

    public static let premiumFeatureBusinessCloudsTitle = NSLocalizedString(
        "[PremiumFeature/BusinessClouds/title]",
        bundle: Bundle.framework,
        value: "Corporate cloud storage",
        comment: "Title of a premium feature: access to company's cloud accounts like 'OneDrive for Business'")
    public static let premiumFeatureBusinessCloudsDescription = NSLocalizedString(
        "[PremiumFeature/BusinessClouds/description]",
        bundle: Bundle.framework,
        value: "Connect directly to enterprise storage accounts, such as OneDrive for Business.",
        comment: "Description/call to action for the `Business Cloud Storage` premium feature.")
    public static let premiumBenefitBusinessCloudsTitle = NSLocalizedString(
        "[Premium/Benefits/BusinessClouds/title]",
        bundle: Bundle.framework,
        value: "Sync with corporate storage",
        comment: "Title of a premium feature")
    public static let premiumBenefitBusinessCloudsDescription = premiumFeatureBusinessCloudsDescription

    public static let premiumFeaturePasswordAuditTitle = NSLocalizedString(
        "[PremiumFeature/PasswordAudit/title]",
        bundle: Bundle.framework,
        value: "Password audit",
        comment: "Title of a premium feature: discover which passwords are known to be compromized")
    public static let premiumFeaturePasswordAuditDescription = NSLocalizedString(
        "[PremiumFeature/PasswordAudit/description]",
        bundle: Bundle.framework,
        value: "Find out if any of your passwords have been exposed in a known data breach.",
        comment: "Description/call to action for the `Password Audit` premium feature.")
    public static let premiumBenefitPasswordAuditTitle = NSLocalizedString(
        "[Premium/Benefits/PasswordAudit/title]",
        bundle: Bundle.framework,
        value: "Check your passwords",
        comment: "Title of a premium feature")
    public static let premiumBenefitPasswordAuditDescription = premiumFeaturePasswordAuditDescription

    public static let premiumFeatureLinkedDatabasesTitle = NSLocalizedString(
        "[PremiumFeature/LinkedDatabases/title]",
        bundle: Bundle.framework,
        value: "Linked Databases",
        comment: "Title of a premium feature: ability to open databases referenced in another database (In Title Case)")
    public static let premiumFeatureLinkedDatabasesDescription = NSLocalizedString(
        "[PremiumFeature/LinkedDatabases/description]",
        bundle: Bundle.framework,
        value: "Upgrade to premium and open linked databases in one step.",
        comment: "Description/advertisement for the `Linked Databases` premium feature")
    public static let premiumBenefitLinkedDatabasesTitle = NSLocalizedString(
        "[Premium/Benefits/LinkedDatabases/title]",
        bundle: Bundle.framework,
        value: "Open linked databases",
        comment: "Title of a premium feature")
    public static let premiumBenefitLinkedDatabasesDescription = NSLocalizedString(
        "[Premium/Benefits/LinkedDatabases/details]",
        bundle: Bundle.framework,
        value: "Open another database in one step — using credentials stored in an entry.",
        comment: "Explanation of the premium feature")
}
// swiftlint:enable line_length
