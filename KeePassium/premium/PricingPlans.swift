//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
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
        title: LString.premiumBenefitMultipleDatabasesTitle,
        description: LString.premiumBenefitMultipleDatabasesDescription
    )
    static let longDatabaseTimeout = PricingPlanBenefit(
        image: .premiumBenefitDBTimeout,
        title:  LString.premiumBenefitLongDatabaseTimeoutsTitle,
        description: LString.premiumBenefitLongDatabaseTimeoutsDescription
    )
    static let yubikeyChallengeResponse = PricingPlanBenefit(
        image: .premiumBenefitHardwareKeys,
        title: LString.premiumBenefitHardwareKeysTitle,
        description: LString.premiumBenefitHardwareKeysDescription
    )
    static let customAppIcons = PricingPlanBenefit(
        image: .premiumBenefitCustomAppIcons,
        title: LString.premiumBenefitChangeAppIconTitle,
        description: LString.premiumBenefitChangeAppIconDescription
    )
    
    static let viewFieldReferences = PricingPlanBenefit(
        image: .premiumBenefitFieldReferences,
        title: LString.premiumBenefitFieldReferecesTitle,
        description: LString.premiumBenefitFieldReferencesDescription
    )
    static let quickAutoFill = PricingPlanBenefit(
        image: .premiumBenefitQuickAutoFill,
        title: LString.premiumBenefitQuickAutoFillTitle,
        description: LString.premiumBenefitQuickAutoFillDescription
    )
}

class PricingPlanFactory {
    static func make(for product: SKProduct) -> PricingPlan? {
        guard let iapProduct = InAppProduct(rawValue: product.productIdentifier) else {
            assertionFailure()
            Diag.error("IAP with unrecognized product ID [id: \(product.productIdentifier)]")
            return nil
        }
        assert(iapProduct.kind == .premium, "Wrong IAP product kind encountered")
        
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
        case .version88,
             .version96,
             .version99:
            return PricingPlanVersionPurchase(product)
        case .donationSmall,
             .donationMedium,
             .donationLarge:
            return nil
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
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.viewFieldReferences,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.customAppIcons,
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
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.viewFieldReferences,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.customAppIcons,
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
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.viewFieldReferences,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.customAppIcons,
        ]
        self.smallPrint = LString.subscriptionConditions
        self.maybeOfferTrial() 
    }
}

class PricingPlanVersionPurchase: RealPricingPlan {
    override init(_ product: SKProduct) {
        super.init(product)

        self.localizedPriceWithPeriod = localizedPrice
        self.callToAction = LString.premiumCallToActionBuyNow
        self.ctaSubtitle = LString.planConditionFullPriceUpgrade
        self.conditions = [
            PricingPlanCondition(kind: .currentPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .oneYearEmailSupport, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .upcomingPremiumFeatures, isIncluded: false, moreInfo: .none),
            PricingPlanCondition(kind: .familySharing, isIncluded: false, moreInfo: .familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.viewFieldReferences,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.customAppIcons,
        ]
        self.smallPrint = nil
    }
}

class PricingPlanPremiumForever: RealPricingPlan {
    override init(_ product: SKProduct) {
        super.init(product)
        
        self.localizedPriceWithPeriod = localizedPrice
        self.callToAction = LString.premiumCallToActionBuyNow
        self.ctaSubtitle = nil
        self.conditions = [
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .upcomingPremiumFeatures, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true, moreInfo: .none),
            PricingPlanCondition(kind: .familySharing, isIncluded: false, moreInfo: .familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.viewFieldReferences,
            PricingPlanBenefit.longDatabaseTimeout,
            PricingPlanBenefit.customAppIcons,
        ]
        self.smallPrint = nil
    }
}
