//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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

    var kind: Kind
    var isIncluded: Bool
    var infoURL: URL?

    init(kind: Kind, isIncluded: Bool, infoURL: URL? = nil) {
        self.kind = kind
        self.isIncluded = isIncluded
        self.infoURL = infoURL
    }

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
    var symbolName: SymbolName
    var title: String
    var description: String?

    static let multipleDatabases = PricingPlanBenefit(
        symbolName: .premiumBenefitMultiDB,
        title: LString.premiumBenefitMultipleDatabasesTitle,
        description: LString.premiumBenefitMultipleDatabasesDescription
    )
    static let yubikeyChallengeResponse = PricingPlanBenefit(
        symbolName: .premiumBenefitHardwareKeys,
        title: LString.premiumBenefitHardwareKeysTitle,
        description: LString.premiumBenefitHardwareKeysDescription
    )
    static let businessClouds = PricingPlanBenefit(
        symbolName: .premiumBenefitBusinessClouds,
        title: LString.premiumBenefitBusinessCloudsTitle,
        description: LString.premiumBenefitBusinessCloudsDescription
    )
    static let passwordAudit = PricingPlanBenefit(
        symbolName: .premiumBenefitPasswordAudit,
        title: LString.premiumBenefitPasswordAuditTitle,
        description: LString.premiumBenefitPasswordAuditDescription
    )
    static let quickAutoFill = PricingPlanBenefit(
        symbolName: .premiumBenefitQuickAutoFill,
        title: LString.premiumBenefitQuickAutoFillTitle,
        description: LString.premiumBenefitQuickAutoFillDescription
    )
    static let linkedDatabases = PricingPlanBenefit(
        symbolName: .premiumBenefitLinkedDatabases,
        title: LString.premiumBenefitLinkedDatabasesTitle,
        description: LString.premiumBenefitLinkedDatabasesDescription
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
             .version99,
             .version120,
             .version139,
             .version154:
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
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true),
            PricingPlanCondition(kind: .freemiumReminders, isIncluded: true),
            PricingPlanCondition(kind: .communitySupport, isIncluded: true),
            PricingPlanCondition(kind: .emailSupport, isIncluded: false),
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: false),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.passwordAudit,
            PricingPlanBenefit.businessClouds,
            PricingPlanBenefit.linkedDatabases,
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
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true),
            PricingPlanCondition(kind: .perpetualFallback, isIncluded: true, infoURL: URL.AppHelp.perpetualFallback),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true),
            PricingPlanCondition(kind: .familySharing, isIncluded: true, infoURL: URL.AppHelp.familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.passwordAudit,
            PricingPlanBenefit.businessClouds,
            PricingPlanBenefit.linkedDatabases,
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
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true),
            PricingPlanCondition(kind: .perpetualFallback, isIncluded: true, infoURL: URL.AppHelp.perpetualFallback),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true),
            PricingPlanCondition(kind: .familySharing, isIncluded: true, infoURL: URL.AppHelp.familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.passwordAudit,
            PricingPlanBenefit.businessClouds,
            PricingPlanBenefit.linkedDatabases,
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
            PricingPlanCondition(kind: .currentPremiumFeatures, isIncluded: true),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true),
            PricingPlanCondition(kind: .oneYearEmailSupport, isIncluded: true),
            PricingPlanCondition(kind: .upcomingPremiumFeatures, isIncluded: false),
            PricingPlanCondition(kind: .familySharing, isIncluded: false, infoURL: URL.AppHelp.familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.passwordAudit,
            PricingPlanBenefit.businessClouds,
            PricingPlanBenefit.linkedDatabases,
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
            PricingPlanCondition(kind: .allPremiumFeatures, isIncluded: true),
            PricingPlanCondition(kind: .upcomingPremiumFeatures, isIncluded: true),
            PricingPlanCondition(kind: .updatesAndFixes, isIncluded: true),
            PricingPlanCondition(kind: .emailSupport, isIncluded: true),
            PricingPlanCondition(kind: .familySharing, isIncluded: false, infoURL: URL.AppHelp.familySharing),
        ]
        self.benefits = [
            PricingPlanBenefit.quickAutoFill,
            PricingPlanBenefit.multipleDatabases,
            PricingPlanBenefit.yubikeyChallengeResponse,
            PricingPlanBenefit.passwordAudit,
            PricingPlanBenefit.businessClouds,
            PricingPlanBenefit.linkedDatabases,
        ]
        self.smallPrint = nil
    }
}
