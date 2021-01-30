//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit

struct PricingPlanCondition {
    enum Kind {
        case updatesAndFixes
        case freemiumReminders
        case communitySupport
        case emailSupport
        case oneYearEmailSupport
        case allPremiumFeatures
        case upcomingPremiumFeatures
        case currentPremiumFeatures
        case perpetualFallback
        case familySharing
    }
    
    enum HelpReference {
        case none
        case perpetualFallback
        case familySharing
        var articleKey: HelpArticle.Key {
            switch self {
            case .none:
                fatalError()
            case .perpetualFallback:
                return .perpetualFallbackLicense
            case .familySharing:
                return .appStoreFamilySharingProgramme
            }
        }
    }
    
    var kind: Kind
    var isIncluded: Bool
    var moreInfo: HelpReference
    
    var localizedTitle: String {
        switch kind {
        case .updatesAndFixes:
            return LString.planConditionUpdatesAndFixes
        case .freemiumReminders:
            return LString.planConditionFreemiumReminders
        case .communitySupport:
            return LString.planConditionCommunitySupport
        case .emailSupport:
            return LString.planConditionEmailSupport
        case .oneYearEmailSupport:
            return LString.planConditionOneYearEmailSupport
        case .allPremiumFeatures:
            return LString.planConditionAllPremiumFeatures
        case .upcomingPremiumFeatures:
            return LString.planConditionUpcomingPremiumFeatures
        case .currentPremiumFeatures:
            return LString.planConditionCurrentPremiumFeatures
        case .perpetualFallback:
            return LString.planConditionSubscriptionAsPurchase
        case .familySharing:
            return LString.planConditionFamilySharing
        }
    }
}

struct PricingPlanBenefit {
    var image: ImageAsset?
    var title: String
    var description: String?
        
    static let multipleDatabases = PricingPlanBenefit(
        image: .premiumBenefitMultiDB,
        title: NSLocalizedString(
            "[Premium/Benefits/MultiDB/title]",
            value: "Sync with the team",
            comment: "Title of a premium feature"),
        description: NSLocalizedString(
            "[Premium/Benefits/MultiDB/details]",
            value: "Add multiple databases and quickly switch between them.",
            comment: "Explanation of the premium feature")
    )
    static let longDatabaseTimeout = PricingPlanBenefit(
        image: .premiumBenefitDBTimeout,
        title:  NSLocalizedString(
            "[Premium/Benefits/DatabaseTimeout/title]",
            value: "Save your time",
            comment: "Title of a premium feature"),
        description: NSLocalizedString(
            "[Premium/Benefits/DatabaseTimeout/details]",
            value: "Tired of typing your master password? Keep your database open longer and unlock it with one tap.",
            comment: "Explanation of the premium feature")
    )
    static let yubikeyChallengeResponse = PricingPlanBenefit(
        image: .premiumBenefitHardwareKeys,
        title: NSLocalizedString(
            "[Premium/Benefits/HardwareKeys/title]",
            value: "Use hardware keys",
            comment: "Title of a premium feature"),
        description: NSLocalizedString(
            "[Premium/Benefits/HardwareKeys/details]",
            value: "Protect your secrets with a hardware key, such as YubiKey.",
            comment: "Explanation of the premium feature")
    )
    static let attachmentPreview = PricingPlanBenefit(
        image: .premiumBenefitPreview,
        title: NSLocalizedString(
            "[Premium/Benefits/AttachmentPreview/title]",
            value: "Preview without a trace",
            comment: "Title of a premium feature"),
        description: NSLocalizedString(
            "[Premium/Benefits/AttachmentPreview/details]",
            value: "Preview attached files directly in KeePassium and leave no traces in other apps. (Works with images, documents, archives and more.)",
            comment: "Explanation of the premium feature")
    )
    static let customAppIcons = PricingPlanBenefit(
        image: .premiumBenefitCustomAppIcons,
        title: NSLocalizedString(
            "[Premium/Benefits/CustomAppIcon/title]",
            value: "Change app icon",
            comment: "Title of a premium feature"),
        description: NSLocalizedString(
            "[Premium/Benefits/CustomAppIcon/details]",
            value: "Make KeePassium look unique, familiar, or disguise it as a calculator — the choice is yours.",
            comment: "Explanation of a premium feature")
    )
    
    static let viewFieldReferences = PricingPlanBenefit(
        image: .premiumBenefitFieldReferences,
        title: NSLocalizedString(
            "[Premium/Benefits/ViewFieldReferences/title]",
            value: "Show field references",
            comment: "Title of a premium feature"),
        description: NSLocalizedString(
            "[Premium/Benefits/ViewFieldReferences/details]",
            value: "Use field references to show information from other entries, instead of creating multiple copies of the same information.",
            comment: "Explanation of a premium feature")
    )
}

class PricingPlanFactory {
    static func make(for product: SKProduct) -> PricingPlan? {
        guard let iapProduct = InAppProduct(rawValue: product.productIdentifier) else {
            assertionFailure()
            Diag.error("IAP with unrecognized product ID [id: \(product.productIdentifier)]")
            return nil
        }
        
        switch iapProduct {
        case .betaForever:
            return nil
        case .forever,
             .forever2:
            return PricingPlanPremiumForever(product)
        case .montlySubscription:
            return PricingPlanPremiumMonthly(product)
        case .yearlySubscription:
            return PricingPlanPremiumYearly(product)
        }
    }
}


class PricingPlan {
    fileprivate(set) var title: String
    fileprivate(set) var isFree: Bool
    
    fileprivate(set) var isDefault: Bool
    fileprivate(set) var price: NSDecimalNumber
    fileprivate(set) var localizedPrice: String
    fileprivate(set) var localizedPriceWithPeriod: String?
    
    fileprivate(set) var callToAction: String
    fileprivate(set) var ctaSubtitle: String?
    
    fileprivate(set) var conditions: [PricingPlanCondition]
    fileprivate(set) var benefits: [PricingPlanBenefit]
    fileprivate(set) var smallPrint: String?
    
    init() {
        self.title = ""
        self.isFree = true
        self.isDefault = false
        self.price = 0
        self.localizedPrice = ""
        self.localizedPriceWithPeriod = nil
        self.callToAction = LString.premiumCallToActionUpgradeNow
        self.ctaSubtitle = nil
        self.conditions = []
        self.benefits = []
        self.smallPrint = nil
    }
}

class FreePricingPlan: PricingPlan {
    override init() {
        super.init()
        self.title = LString.premiumFreePlanTitle
        self.isFree = true
        self.localizedPrice = LString.premiumFreePlanPrice
        self.localizedPriceWithPeriod = nil
        self.callToAction = LString.premiumCallToActionFree
        self.conditions = [
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .freemiumReminders, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .communitySupport, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .emailSupport, isIncluded: false, moreInfo: .none),
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: false, moreInfo: .none),
        ]
        self.benefits = [
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.attachmentPreview,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.customAppIcons,
            PricingPlanBenefit.viewFieldReferences,
        ]
        self.smallPrint = nil
    }
}

class RealPricingPlan: PricingPlan {
    fileprivate(set) var product: SKProduct
    
    init(_ product: SKProduct) {
        self.product = product
        super.init()
        self.title = product.localizedTitle
        self.isFree = (product.price == 0)
        self.price = product.price
        self.localizedPrice = product.localizedPrice
        self.localizedPriceWithPeriod = nil
    }
    
    fileprivate func maybeOfferTrial() {
        guard #available(iOS 11.2, *) else {
            return
        }
        guard PremiumManager.shared.isTrialAvailable else {
            return
        }
        guard let localizedTrialDuration = product.localizedTrialDuration else {
            return
        }
        guard let localizedPriceWithPeriod = localizedPriceWithPeriod else {
            assertionFailure("Need a subscription price")
            return
        }
        ctaSubtitle = String.localizedStringWithFormat(
            LString.trialConditionsTemplate, // "%@ free, then %@",
            localizedTrialDuration,
            localizedPriceWithPeriod
        )
    }
}

class PricingPlanPremiumMonthly: RealPricingPlan {
    override init(_ product: SKProduct) {
        super.init(product)
        
        self.localizedPriceWithPeriod =
            String.localizedStringWithFormat(LString.priceTemplateMonthly, localizedPrice)
        self.callToAction = LString.premiumCallToActionUpgradeNow
        self.ctaSubtitle = nil
        self.conditions = [
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .perpetualFallback, isIncluded: true, moreInfo: .perpetualFallback),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .familySharing, isIncluded: true, moreInfo: .familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.attachmentPreview,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.customAppIcons,
            PricingPlanBenefit.viewFieldReferences,
        ]
        self.smallPrint = LString.subscriptionConditions
        self.maybeOfferTrial() 
    }
}

class PricingPlanPremiumYearly: RealPricingPlan {
    override init(_ product: SKProduct) {
        super.init(product)
        
        isDefault = true
        self.localizedPriceWithPeriod =
            String.localizedStringWithFormat(LString.priceTemplateYearly, localizedPrice)
        self.callToAction = LString.premiumCallToActionUpgradeNow
        self.ctaSubtitle = nil
        self.conditions = [
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .perpetualFallback, isIncluded: true, moreInfo: .perpetualFallback),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .familySharing, isIncluded: true, moreInfo: .familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.attachmentPreview,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.customAppIcons,
            PricingPlanBenefit.viewFieldReferences,
        ]
        self.smallPrint = LString.subscriptionConditions
        self.maybeOfferTrial() 
    }
}

class PricingPlanPremiumForever: RealPricingPlan {
    override init(_ product: SKProduct) {
        super.init(product)
        
        self.localizedPriceWithPeriod = localizedPrice
        self.callToAction = LString.premiumCallToActionUpgradeNow
        self.ctaSubtitle = nil
        self.conditions = [
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .upcomingPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .familySharing, isIncluded: false, moreInfo: .familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.attachmentPreview,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.customAppIcons,
            PricingPlanBenefit.viewFieldReferences,
        ]
        self.smallPrint = nil
    }
}
