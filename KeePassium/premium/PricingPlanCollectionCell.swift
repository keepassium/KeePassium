//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit



class PricingPlanTitleCell: UITableViewCell {
    static let storyboardID = "TitleCell"
    
    @IBOutlet weak var highlightLabel: UILabel!
    @IBOutlet weak var highlightPanel: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var subpriceLabel: UILabel!
}

protocol PricingPlanConditionCellDelegate: class {
    func didPressDetailButton(in cell: PricingPlanConditionCell)
}
class PricingPlanConditionCell: UITableViewCell {
    static let storyboardID = "ConditionCell"
    weak var delegate: PricingPlanConditionCellDelegate?
    
    @IBOutlet weak var checkmarkImage: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var detailButton: UIButton!
    var helpReference: PricingPlanCondition.HelpReference = .none
    
    var isChecked: Bool = false {
        didSet {
            if isChecked {
                checkmarkImage?.image = UIImage(asset: .premiumConditionCheckedListitem)
                checkmarkImage?.tintColor = .primaryText
                titleLabel?.textColor = .primaryText
                accessibilityTraits.remove(.notEnabled)
            } else {
                checkmarkImage?.image = UIImage(asset: .premiumConditionUncheckedListitem)
                checkmarkImage?.tintColor = .disabledText
                titleLabel?.textColor = .disabledText
                accessibilityTraits.insert(.notEnabled)
            }
        }
    }
    @IBAction func didPressDetailButton(_ sender: UIButton) {
        assert(helpReference != .none)
        delegate?.didPressDetailButton(in: self)
    }
}

class PricingPlanBenefitCell: UITableViewCell {
    static let storyboardID = "BenefitCell"
    
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}


protocol PricingPlanCollectionCellDelegate: class {
    func didPressPurchaseButton(in cell: PricingPlanCollectionCell, with pricePlan: PricingPlan)
    func didPressHelpButton(in cell: PricingPlanConditionCell, with pricePlan: PricingPlan)
}

class PricingPlanCollectionCell: UICollectionViewCell {
    static let storyboardID = "PricingPlanCollectionCell"
    private enum Section: Int {
        static let allValues = [Section]([.title, .conditions, .benefits, .smallprint])
        case title = 0
        case conditions = 1
        case benefits = 2
        case smallprint = 3
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var purchaseButton: UIButton!
    @IBOutlet weak var footerLabel: UILabel!
    
    weak var delegate: PricingPlanCollectionCellDelegate?
    
    var isPurchaseEnabled: Bool = false {
        didSet {
            refresh()
        }
    }
    var pricingPlan: PricingPlan! {
        didSet { refresh() }
    }
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44
    }
    
    func refresh() {
        guard pricingPlan != nil else { return }
        purchaseButton.borderColor = .actionTint
        purchaseButton.borderWidth = 1
        if pricingPlan.isFree {
            purchaseButton.backgroundColor = .clear
            purchaseButton.tintColor = .actionTint
        } else {
            purchaseButton.backgroundColor = .actionTint
            purchaseButton.tintColor = .actionText
        }
        purchaseButton.setTitle(pricingPlan.callToAction, for: .normal)
        purchaseButton.isEnabled = isPurchaseEnabled

        footerLabel.text = pricingPlan.ctaSubtitle
        footerLabel.isHidden = (pricingPlan.ctaSubtitle?.isEmpty ?? true)
        tableView.dataSource = self
        tableView.reloadData()
    }
    
    
    @IBAction func didPressPurchaseButton(_ sender: Any) {
        delegate?.didPressPurchaseButton(in: self, with: pricingPlan)
    }
}


extension PricingPlanCollectionCell: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .title:
            return 0.1 
        case .conditions:
            return 0.1 
        case .benefits:
            return UITableView.automaticDimension
        case .smallprint:
            return UITableView.automaticDimension
        }
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .title:
            return 0.1 
        case .conditions:
            return 8 
        case .benefits:
            return 0.1 
        case .smallprint:
            return UITableView.automaticDimension
        }
    }
}


extension PricingPlanCollectionCell: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allValues.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .title:
            return 1
        case .conditions:
            return pricingPlan.conditions.count
        case .benefits:
            return pricingPlan.benefits.count
        case .smallprint:
            return 0 
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard Section(rawValue: section)! == .benefits else {
            return nil
        }
        
        if pricingPlan.isFree {
            return LString.premiumWhatYouMiss
        } else {
            return LString.premiumWhatYouGet
        }
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard Section(rawValue: section)! == .smallprint else {
            return nil
        }
        return pricingPlan.smallPrint
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .title:
            return dequeueTitleCell(tableView, cellForRowAt: indexPath)
        case .conditions:
            return dequeueConditionCell(tableView, cellForRowAt: indexPath)
        case .benefits:
            return dequeueBenefitCell(tableView, cellForRowAt: indexPath)
        case .smallprint:
            fatalError()
        }
    }
    
    func dequeueTitleCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> PricingPlanTitleCell
    {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: PricingPlanTitleCell.storyboardID, for: indexPath)
            as! PricingPlanTitleCell
        if pricingPlan.isFree {
            cell.titleLabel?.text = nil
            cell.titleLabel.isHidden = true
        } else {
            cell.titleLabel?.text = pricingPlan.title
            cell.titleLabel.isHidden = false
        }
        cell.highlightPanel.isHidden = !pricingPlan.isDefault
        cell.highlightLabel.text = LString.premiumPopularPlan
        cell.priceLabel?.attributedText = makeAttributedPrice(for: pricingPlan)
        cell.subpriceLabel?.text = getSubpriceText(for: pricingPlan)
        return cell
    }
    
    func dequeueConditionCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> PricingPlanConditionCell
    {
        let condition = pricingPlan.conditions[indexPath.row]
        let cell = tableView
            .dequeueReusableCell(withIdentifier: PricingPlanConditionCell.storyboardID, for: indexPath)
            as! PricingPlanConditionCell
        cell.delegate = self
        cell.titleLabel?.text = condition.localizedTitle
        cell.isChecked = condition.isIncluded
        
        cell.helpReference = condition.moreInfo
        cell.detailButton.isHidden = (condition.moreInfo == .none)
        return cell
    }
    
    func dequeueBenefitCell(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath)
        -> PricingPlanBenefitCell
    {
        let cell = tableView
            .dequeueReusableCell(withIdentifier: PricingPlanBenefitCell.storyboardID, for: indexPath)
            as! PricingPlanBenefitCell
        let benefit = pricingPlan.benefits[indexPath.row]
        cell.titleLabel?.text = benefit.title
        cell.subtitleLabel?.text = benefit.description
        if let imageAsset = benefit.image {
            cell.iconView?.image = UIImage(asset: imageAsset)
        } else {
            cell.iconView.image = nil
        }

        if pricingPlan.isFree {
            cell.titleLabel.textColor = .disabledText
            cell.subtitleLabel.textColor = .disabledText
            cell.iconView?.tintColor = .disabledText
        } else {
            cell.titleLabel.textColor = .primaryText
            cell.subtitleLabel.textColor = .auxiliaryText
            cell.iconView?.tintColor = .actionTint
        }
        return cell
    }
    
    
    
    private func makeAttributedPrice(for pricingPlan: PricingPlan) -> NSAttributedString {
        let priceWithPeriod = pricingPlan.localizedPriceWithPeriod ?? pricingPlan.localizedPrice
        let price = pricingPlan.localizedPrice

        assert(priceWithPeriod.contains(price))
        guard priceWithPeriod.count > 0 else {
            assertionFailure()
            return NSAttributedString()
        }
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let mainAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .callout),
        ]
        let priceAttributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
            NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .title1),
        ]
        
        let result = NSMutableAttributedString(string: priceWithPeriod, attributes: mainAttributes)
        if let priceRange = priceWithPeriod.range(of: price) {
            let nsPriceRange = NSRange(priceRange, in: priceWithPeriod)
            result.addAttributes(priceAttributes, range: nsPriceRange)
        }
        return result
    }
    
    private func getSubpriceText(for pricingPlan: PricingPlan) -> String? {
        guard let pricingPlan = pricingPlan as? RealPricingPlan,
            let iapProduct = InAppProduct(rawValue: pricingPlan.product.productIdentifier),
            iapProduct.period == .yearly
            else { return nil }
        
        let yearlyPrice = pricingPlan.product.price
        let monthlyPrice = yearlyPrice.dividing(by: 12)
        let localizedMonthlyPrice = SKProduct.localizePrice(
            price: monthlyPrice,
            locale: pricingPlan.product.priceLocale)
        let result =  String.localizedStringWithFormat(
            LString.priceTemplateEquivalentMonthly,
            localizedMonthlyPrice)
        return result
    }
}

extension PricingPlanCollectionCell: PricingPlanConditionCellDelegate {
    func didPressDetailButton(in cell: PricingPlanConditionCell) {
        delegate?.didPressHelpButton(in: cell, with: pricingPlan)
    }
}
