//  KeePassium Password Manager
//  Copyright © 2018–2020 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit

protocol PricingPlanPickerDelegate: class {
    func getAvailablePlans() -> [PricingPlan]
    func didPressCancel(in viewController: PricingPlanPickerVC)
    func didPressRestorePurchases(in viewController: PricingPlanPickerVC)
    func didPressBuy(product: SKProduct, in viewController: PricingPlanPickerVC)
    func didPressHelpButton(
        for helpReference: PricingPlanCondition.HelpReference,
        at popoverAnchor: PopoverAnchor,
        in viewController: PricingPlanPickerVC)
}

class PricingPlanPickerVC: UIViewController {
    fileprivate let termsAndConditionsURL = URL(string: "https://keepassium.com/terms/app")!
    fileprivate let privacyPolicyURL = URL(string: "https://keepassium.com/privacy/app")!

    @IBOutlet weak var activityIndcator: UIActivityIndicatorView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var restorePurchasesButton: UIButton!
    @IBOutlet weak var termsButton: UIButton!
    @IBOutlet weak var privacyPolicyButton: UIButton!

    weak var delegate: PricingPlanPickerDelegate?
    
    private var pricingPlans = [PricingPlan]()
    
    var isPurchaseEnabled = false {
        didSet {
            refresh(animated: false)
        }
    }
    
    public static func create(delegate: PricingPlanPickerDelegate? = nil) -> PricingPlanPickerVC {
        let vc = PricingPlanPickerVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.decelerationRate = .fast
        
        statusLabel.text = LString.statusContactingAppStore
        activityIndcator.isHidden = false
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh(animated: animated)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        collectionView?.collectionViewLayout.invalidateLayout()
    }
    
    public func refresh(animated: Bool) {
        guard isViewLoaded else { return }
        restorePurchasesButton.isEnabled = isPurchaseEnabled
        
        if let unsortedPlans = delegate?.getAvailablePlans(), unsortedPlans.count > 0 {
            let sortedPlans = unsortedPlans.sorted {
                (plan1, plan2) -> Bool in
                let isP1BeforeP2 = plan1.price.doubleValue < plan2.price.doubleValue
                return isP1BeforeP2
            }
            self.pricingPlans = sortedPlans
            hideMessage()
        }

        collectionView.reloadData()
    }
    
    
    public func showMessage(_ message: String) {
        statusLabel.text = message
        activityIndcator.isHidden = true
        UIView.animate(withDuration: 0.3) {
            self.statusLabel.isHidden = false
        }
    }
    
    public func hideMessage() {
        UIView.animate(withDuration: 0.3) {
            self.activityIndcator.isHidden = true
            self.statusLabel.isHidden = true
        }
    }
    
    
    public func setPurchasing(_ isPurchasing: Bool) {
        isPurchaseEnabled = !isPurchasing
        if isPurchasing {
            showMessage(LString.statusContactingAppStore)
            UIView.animate(withDuration: 0.3) {
                self.activityIndcator.isHidden = false
            }
        } else {
            hideMessage()
            UIView.animate(withDuration: 0.3) {
                self.activityIndcator.isHidden = true
            }
        }
    }
    
    public func scrollToDefaultPlan(animated: Bool) {
        var targetPlanIndex = pricingPlans.count - 1
        if let promotedPlanIndex = pricingPlans.firstIndex(where: { $0.isDefault }) {
            targetPlanIndex = promotedPlanIndex
        }
        collectionView.scrollToItem(
            at: IndexPath(item: targetPlanIndex, section: 0),
            at: .centeredHorizontally,
            animated: animated)
    }
    
    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressRestorePurchases(_ sender: Any) {
        delegate?.didPressRestorePurchases(in: self)
    }
        
    @IBAction func didPressTerms(_ sender: Any) {
        AppGroup.applicationShared?.open(termsAndConditionsURL, options: [:])
    }
    @IBAction func didPressPrivacyPolicy(_ sender: Any) {
        AppGroup.applicationShared?.open(privacyPolicyURL, options: [:])
    }
}

extension PricingPlanPickerVC: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath)
        -> CGSize
    {
        let desiredAspectRatio = CGFloat(1.69)
        let frameWidth = collectionView.frame.width
        let width = min(
            max(350, frameWidth * 0.6), 
            frameWidth - 32) 
        
        let height = min(
            max(width * desiredAspectRatio, collectionView.frame.height * 0.6),
            collectionView.frame.height - 30)
        return CGSize(width: width, height: height)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int)
        -> CGSize
    {
        let cellSize = self.collectionView(
            collectionView,
            layout: collectionViewLayout,
            sizeForItemAt: IndexPath(item: 0, section: section)
        )
        let headerSize = (collectionView.frame.width - cellSize.width) / 2
        return CGSize(width: headerSize, height: 0)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int)
        -> CGSize
    {
        let cellSize = self.collectionView(
            collectionView,
            layout: collectionViewLayout,
            sizeForItemAt: IndexPath(item: 0, section: section)
        )
        let footerSize = (collectionView.frame.width - cellSize.width) / 2
        return CGSize(width: footerSize, height: 0)
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int)
        -> CGFloat
    {
        return 0
    }
    
    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int)
        -> CGFloat
    {
        let headerSize = self.collectionView(
            collectionView,
            layout: collectionViewLayout,
            referenceSizeForHeaderInSection: section
        )
        return 0.5 * headerSize.width
    }
}

extension PricingPlanPickerVC: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return pricingPlans.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView
            .dequeueReusableCell(
                withReuseIdentifier: PricingPlanCollectionCell.storyboardID,
                for: indexPath)
            as! PricingPlanCollectionCell
        cell.clipsToBounds = false
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowRadius = 5
        cell.layer.shadowOpacity = 0.5
        cell.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
        
        cell.isPurchaseEnabled = self.isPurchaseEnabled
        cell.pricingPlan = pricingPlans[indexPath.item]
        cell.delegate = self
        return cell
    }
}

extension PricingPlanPickerVC: PricingPlanCollectionCellDelegate {
    func didPressPurchaseButton(in cell: PricingPlanCollectionCell, with pricingPlan: PricingPlan) {
        guard let realPricingPlan = pricingPlan as? RealPricingPlan else {
            assert(pricingPlan.isFree)
            delegate?.didPressCancel(in: self)
            return
        }
        delegate?.didPressBuy(product: realPricingPlan.product, in: self)
    }
    
    func didPressHelpButton(
        in cell: PricingPlanConditionCell,
        with pricingPlan: PricingPlan)
    {
        let helpReference = cell.helpReference
        let popoverAnchor = PopoverAnchor(
            sourceView: cell.detailButton,
            sourceRect: cell.detailButton.bounds)
        delegate?.didPressHelpButton(
            for: helpReference,
            at: popoverAnchor,
            in: self)
    }
}
