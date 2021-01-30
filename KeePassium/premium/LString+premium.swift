//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import Foundation

extension LString {
    
    public static let errorNoPurchasesAvailable = NSLocalizedString(
        "[Premium/Upgrade] Hmm, there are no upgrades available. This should not happen, please contact support.",
        value: "Hmm, there are no upgrades available. This should not happen, please contact support.",
        comment: "Error message: AppStore returned no available in-app purchase options")
    
    public static let subscriptionConditions = NSLocalizedString(
        "[Premium/Subscription/Legal/text]",
        value:"""
Payment will be charged to your Apple ID account at the confirmation of purchase.

Subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period.

You can manage and cancel your subscriptions by going to your account settings on the App Store after purchase.
""",
        comment: "Subscription conditions")
    
    public static let premiumFeatureGenericTitle = NSLocalizedString(
        "[PremiumFeature/Generic/title]",
        value: "Premium Feature",
        comment: "A generic title of a premium feature")
    public static let premiumFeatureGenericDescription = NSLocalizedString(
        "[PremiumFeature/Generic/description]",
        value: "Upgrade to Premium and enjoy KeePassium at its best.",
        comment: "A generic description of a premium feature")
    
    public static let actionManageSubscriptions = NSLocalizedString(
        "[Premium/ManageSubscriptions/action]",
        value: "Manage subscriptions",
        comment: "Action: open AppStore subscription management page")
    

    public static let premiumFreePlanTitle = NSLocalizedString(
        "[Premium/Price Plan/Free/title]",
        value: "Free",
        comment: "Name of the free pricing plan")
    public static let premiumFreePlanPrice = NSLocalizedString(
        "[Premium/Price Plan/Free/price]",
        value: "Free",
        comment: "Price of the free pricing plan")
    public static let premiumPopularPlan = NSLocalizedString(
        "[Premium/Price Plan/popular]",
        value: "Popular",
        comment: "Marks the default pricing plan")
    
    public static let priceTemplateMonthly = NSLocalizedString(
        "[Premium/Upgrade/price] %@ / month",
        value: "%@ / month",
        comment: "Product price for monthly premium subscription. [localizedPrice: String]")
    public static let priceTemplateYearly = NSLocalizedString(
        "[Premium/Upgrade/price] %@ / year",
        value: "%@ / year",
        comment: "Product price for annual premium subscription. [localizedPrice: String]")
    public static let priceTemplateOnce = NSLocalizedString(
        "[Premium/Upgrade/price] %@ once",
        value: "%@ once",
        comment: "Product price for once-and-forever premium. [localizedPrice: String]")
    public static let priceTemplateEquivalentMonthly = NSLocalizedString(
        "[Premium/Upgrade/price] around %@ / month",
        value: "≈ %@ / month",
        comment: "Equivalent monthly price for an annual subscription. For example: `$12/year ≈ $1 / month`")
    public static let trialConditionsTemplate = NSLocalizedString(
        "[Premium/Trial/trial then price]",
        value: "%@ free, then %@",
        comment: "Trial conditions. For example `30 days free, then $1 per month`")
    
    public static let premiumWhatYouGet = NSLocalizedString(
        "[Premium/Benefits/Positive/header] ",
        value: "What you get",
        comment: "List of premium benefits/advantages")
    public static let premiumWhatYouMiss = NSLocalizedString(
        "[Premium/Benefits/Negative/header] ",
        value: "What you are missing",
        comment: "List of premium benefits/advantages")
    
    
    public static let planConditionUpdatesAndFixes = NSLocalizedString(
        "[Premium/Price Plan/Conditions/updates and bug fixes]",
        value: "Updates and bug fixes",
        comment: "What's included in a price plan")
    public static let planConditionFreemiumReminders = NSLocalizedString(
        "[Premium/Price Plan/Conditions/freemium reminders]",
        value: "Freemium reminders",
        comment: "What's included in a free plan: reminders that the version is free")
    public static let planConditionCommunitySupport = NSLocalizedString(
        "[Premium/Price Plan/Conditions/community support]",
        value: "Customer support: Online forums",
        comment: "What's included in a free plan: support via forums (as opposed to email support)")
    public static let planConditionEmailSupport = NSLocalizedString(
        "[Premium/Price Plan/Conditions/email support]",
        value: "Customer support: Email",
        comment: "What's included in a price plan: support via email")
    public static let planConditionOneYearEmailSupport = NSLocalizedString(
        "[Premium/Price Plan/Conditions/1 year email support]",
        value: "One year of email support",
        comment: "What's included in a price plan: 1 year of support via email")
    public static let planConditionAllPremiumFeatures = NSLocalizedString(
        "[Premium/Price Plan/Conditions/all premium features]",
        value: "All premium features",
        comment: "What's included in a price plan")
    public static let planConditionCurrentPremiumFeatures = NSLocalizedString(
        "[Premium/Price Plan/Conditions/current premium features]",
        value: "Current premium features",
        comment: "What's included in a price plan: existing premium features only (as opposed to `current + future`)")
    public static let planConditionUpcomingPremiumFeatures = NSLocalizedString(
        "[Premium/Price Plan/Conditions/future premium features]",
        value: "Future premium features",
        comment: "What's included in a price plan: upcoming premium features (as opposed to `current only`)")
    public static let planConditionPerpetualFallback = NSLocalizedString(
        "[Premium/Price Plan/Conditions/perpetual fallback]",
        value: "Rent-to-own license (Perpetual fallback license)",
        comment: "What's included in a price plan. Please leave `perpetual fallback license` in English.")
    public static let planConditionSubscriptionAsPurchase = NSLocalizedString(
        "[Premium/Price Plan/Conditions/subscription as purchase]",
        value: "Subscription as a purchase",
        comment: "What's included in a subscription plan. By subscribing for a certain period, the user receives a permanent license for a version of the app. More info: https://keepassium.com/articles/perpetual-fallback-license/")
    public static let planConditionFamilySharing = NSLocalizedString(
        "[Premium/Price Plan/Conditions/family sharing]",
        value: "Family Sharing",
        comment: "Family Sharing programme. Translation must match Apple's: https://www.apple.com/family-sharing/")
    public static let planConditionFullPriceUpgrade = NSLocalizedString(
        "[Premium/Price Plan/Conditions/full price upgrade]",
        value: "Premium features added in the future would require a new purchase at full price.",
        comment: "Upgrade conditions for current-version premium purchase.")

    
    public static let premiumCallToActionFree = NSLocalizedString(
        "[Premium/CallToAction/free]",
        value: "Continue Testing",
        comment: "Call to action: continue using the free version")
    public static let premiumCallToActionStartTrial = NSLocalizedString(
        "[Premium/CallToAction/startTrial]",
        value: "Try it free",
        comment: "Call to action: start free trial")
    public static let premiumCallToActionUpgradeNow = NSLocalizedString(
        "[Premium/CallToAction/upgradeNow]",
        value: "Upgrade Now",
        comment: "Call to action: upgrade to premium")
    public static let premiumCallToActionBuyNow = NSLocalizedString(
        "[Premium/CallToAction/buyNow]",
        value: "Buy Now",
        comment: "Call to action")

    
    public static let statusContactingAppStore = NSLocalizedString(
        "[Premium/Upgrade/Progress] Contacting AppStore...",
        value: "Contacting AppStore...",
        comment: "Status message when downloading available in-app purchases")
    public static let statusPurchasing = NSLocalizedString(
        "[Premium/Upgrade/Progress] Purchasing...",
        value: "Purchasing...",
        comment: "Status: in-app purchase started")
    public static let statusDeferredPurchase = NSLocalizedString(
        "[Premium/Upgrade/Deferred/text] Thank you! You can use KeePassium while purchase is awaiting approval.",
        value: "Thank you! You can use KeePassium while purchase is awaiting approval.",
        comment: "Message shown when in-app purchase is deferred until approval (parental or corporate).")

    
    public static let titlePurchaseSuccess = NSLocalizedString(
        "[Premium/Upgrade/Success/thankYou]",
        value: "Thank you for the purchase!",
        comment: "Message shown after buying or subscribing.")
    public static let messageCancelOldSubscriptions = NSLocalizedString(
        "[Premium/Upgrade/cancelOngoingSubscription]",
        value: "Please check if you need to cancel your old subscription.",
        comment: "Message shown after buying a lifetime version.")

    
    public static let titlePurchaseRestored = NSLocalizedString(
        "[Premium/Upgrade/Restored/title] Purchase Restored",
        value: "Purchase Restored",
        comment: "Title of the message shown after in-app purchase was successfully restored")
    public static let purchaseRestored = NSLocalizedString(
        "[Premium/Upgrade/Restored/text] Upgrade successful, enjoy the app!",
        value: "Upgrade successful, enjoy the app!",
        comment: "Text of the message shown after in-app purchase was successfully restored")
    
    public static let titleRestorePurchaseError = NSLocalizedString(
        "[Premium/Upgrade/RestoreFailed/title] Sorry",
        value: "Sorry",
        comment: "Title of an error message: there were no in-app purchases that can be restored")
    public static let errorNoPreviousPurchaseToRestore = NSLocalizedString(
        "[Premium/Upgrade/RestoreFailed/text] No previous purchase could be restored.",
        value: "No previous purchase could be restored.",
        comment: "Text of an error message: there were no in-app purchases that can be restored")
    

    public static let perpetualLicense = NSLocalizedString(
        "[Premium/perpetualLicense]",
        value: "Perpetual license",
        comment: "Name of the permanent/never-ending license.")

    public static let perpetualLicenseStatus = NSLocalizedString(
        "[Premium/PerpetualLicense/status]",
        value: "You have a perpetual license for all the versions before %@.",
        comment: "[formattedDate: String]")

}
