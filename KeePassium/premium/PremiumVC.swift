//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib
import StoreKit

protocol PremiumDelegate: class {
    func getAvailableProducts() -> [SKProduct]
    func didPressCancel(in premiumController: PremiumVC)
    func didPressRestorePurchases(in premiumController: PremiumVC)
    func didPressBuy(product: SKProduct, in premiumController: PremiumVC)
}

class PremiumVC: UIViewController {

    fileprivate let termsAndConditionsURL = URL(string: "https://keepassium.com/terms/app")!
    fileprivate let privacyPolicyURL = URL(string: "https://keepassium.com/privacy/app")!
    
    weak var delegate: PremiumDelegate?
    
    var allowRestorePurchases: Bool = true {
        didSet {
            guard isViewLoaded else { return }
            restorePurchasesButton.isHidden = !allowRestorePurchases
        }
    }
    
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var benefitsStackView: UIStackView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var buttonStack: UIStackView!
    @IBOutlet weak var activityIndcator: UIActivityIndicatorView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var restorePurchasesButton: UIButton!
    @IBOutlet weak var termsButton: UIButton!
    @IBOutlet weak var privacyPolicyButton: UIButton!
    
    private var products: [SKProduct]?
    private var purchaseButtons = [UIButton]()
    
    
    public static func create(
        delegate: PremiumDelegate? = nil
        ) -> PremiumVC
    {
        let vc = PremiumVC.instantiateFromStoryboard()
        vc.delegate = delegate
        return vc
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        statusLabel.text = NSLocalizedString(
            "[Premium/Upgrade/Progress] Contacting AppStore...",
            value: "Contacting AppStore...",
            comment: "Status message when downloading available in-app purchases")
        activityIndcator.isHidden = false
        restorePurchasesButton.isHidden = !allowRestorePurchases
        footerView.isHidden = true
        
        setupBenefitsView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh(animated: false)
    }
    
    private func setupBenefitsView() {
        let multiDatabaseBenefit = PremiumBenefitView(frame: CGRect.zero) 
        multiDatabaseBenefit.image = UIImage(asset: .premiumBenefitMultiDB)
        multiDatabaseBenefit.title = NSLocalizedString(
            "[Premium/Benefits/MultiDB/title]",
            value: "Sync with the team",
            comment: "Title of a premium feature")
        multiDatabaseBenefit.subtitle = NSLocalizedString(
            "[Premium/Benefits/MultiDB/details]",
            value: "Add multiple databases and quickly switch between them.",
            comment: "Explanation of the premium feature")
        benefitsStackView.addArrangedSubview(multiDatabaseBenefit)
        
        let databaseTimeoutBenefit = PremiumBenefitView(frame: CGRect.zero)
        databaseTimeoutBenefit.image = UIImage(asset: .premiumBenefitDBTimeout)
        databaseTimeoutBenefit.title = NSLocalizedString(
            "[Premium/Benefits/DatabaseTimeout/title]",
            value: "Save your time",
            comment: "Title of a premium feature")
        databaseTimeoutBenefit.subtitle = NSLocalizedString(
            "[Premium/Benefits/DatabaseTimeout/details]",
            value: "Tired of typing your master password? Keep your database open longer and unlock it with one tap.",
            comment: "Explanation of the premium feature")
        benefitsStackView.addArrangedSubview(databaseTimeoutBenefit)

        let hardwareKeysBenefit = PremiumBenefitView(frame: CGRect.zero)
        hardwareKeysBenefit.image = UIImage(asset: .premiumBenefitHardwareKeys)
        hardwareKeysBenefit.title = NSLocalizedString(
            "[Premium/Benefits/HardwareKeys/title]",
            value: "Use hardware keys",
            comment: "Title of a premium feature")
        hardwareKeysBenefit.subtitle = NSLocalizedString(
            "[Premium/Benefits/HardwareKeys/details]",
            value: "Protect your secrets with a hardware key, such as YubiKey.",
            comment: "Explanation of the premium feature")
        benefitsStackView.addArrangedSubview(hardwareKeysBenefit)

        let previewBenefit = PremiumBenefitView(frame: CGRect.zero)
        previewBenefit.image = UIImage(asset: .premiumBenefitPreview)
        previewBenefit.title = NSLocalizedString(
            "[Premium/Benefits/AttachmentPreview/title]",
            value: "Preview without a trace",
            comment: "Title of a premium feature")
        previewBenefit.subtitle = NSLocalizedString(
            "[Premium/Benefits/AttachmentPreview/details]",
            value: "Preview attached files directly in KeePassium and leave no traces in other apps. (Works with images, documents, archives and more.)",
            comment: "Explanation of the premium feature")
        benefitsStackView.addArrangedSubview(previewBenefit)
        
        let supportBenefit = PremiumBenefitView(frame: CGRect.zero)
        supportBenefit.image = UIImage(asset: .premiumBenefitSupport)
        supportBenefit.title = NSLocalizedString(
            "[Premium/Benefits/Support/title]",
            value: "Talk to support that cares",
            comment: "Title of a premium feature")
        supportBenefit.subtitle = NSLocalizedString(
            "[Premium/Benefits/Support/details]",
            value: "Community support means no obligations. With premium, get answers and solutions directly from the developer.",
            comment: "Explanation of the premium feature")
        benefitsStackView.addArrangedSubview(supportBenefit)
        
        let maintenanceBenefit = PremiumBenefitView(frame: CGRect.zero)
        maintenanceBenefit.image = UIImage(asset: .premiumBenefitShiny)
        maintenanceBenefit.title = NSLocalizedString(
            "[Premium/Benefits/Maintenance/title]",
            value: "Keep it shiny",
            comment: "Title of a premium feature")
        maintenanceBenefit.subtitle = NSLocalizedString(
            "[Premium/Benefits/Maintenance/details]",
            value: "Keep KeePassium improved, maintained and without ads.",
            comment: "Explanation of the premium feature")
        benefitsStackView.addArrangedSubview(maintenanceBenefit)
    }
    
    public func refresh(animated: Bool) {
        guard let products = delegate?.getAvailableProducts(),
            !products.isEmpty
            else { return }
        setAvailableProducts(products, animated: animated)
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
    
    
    private func setAvailableProducts(_ unsortedProducts: [SKProduct], animated: Bool) {
        let products = unsortedProducts.sorted { (product1, product2) -> Bool in
            let isP1BeforeP2 = product1.price.doubleValue < product2.price.doubleValue
            return isP1BeforeP2
        }
        
        self.products = products
        purchaseButtons.forEach { button in
            buttonStack.removeArrangedSubview(button)
            button.removeFromSuperview()
        }
        purchaseButtons.removeAll()
        
        for index in 0..<products.count {
            let product = products[index]
            let title = getActionText(for: product)

            let button = makePurchaseButton()
            button.tag = index
            button.setAttributedTitle(title, for: .normal)
            button.addTarget(self, action: #selector(didPressPurchaseButton), for: .touchUpInside)
            button.isHidden = true 
            buttonStack.addArrangedSubview(button)
            purchaseButtons.append(button)
        }
        purchaseButtons.forEach { button in
            UIView.animate(withDuration: animated ? 0.5 : 0.0) {
                button.isHidden = false
            }
        }
        activityIndcator.isHidden = true
        statusLabel.isHidden = true
        
        if animated {
            UIView.animate(withDuration: 0.5) {
                self.footerView.isHidden = false
            }
        } else {
            self.footerView.isHidden = false
        }
    }
    
    private func getActionText(for product: SKProduct) -> NSAttributedString {
        guard let iap = InAppProduct(rawValue: product.productIdentifier) else {
            assertionFailure()
            return NSAttributedString(string: "")
        }
        
        let productPrice: String
        switch iap.period {
        case .oneTime:
            productPrice = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Premium/Upgrade/price] %@ once",
                    value: "%@ once",
                    comment: "Product price for once-and-forever premium. [localizedPrice: String]"),
                product.localizedPrice)
        case .yearly:
            productPrice = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Premium/Upgrade/price] %@ / year",
                    value: "%@ / year",
                    comment: "Product price for annual premium subscription. [localizedPrice: String]"),
                product.localizedPrice)
        case .monthly:
            productPrice = String.localizedStringWithFormat(
                NSLocalizedString(
                    "[Premium/Upgrade/price] %@ / month",
                    value: "%@ / month",
                    comment: "Product price for monthly premium subscription. [localizedPrice: String]"),
                product.localizedPrice)
        case .other:
            assertionFailure("Should not be here")
            productPrice = "\(product.localizedPrice)"
        }

        
        let buttonTitle = NSMutableAttributedString(string: "")
        
        let titleParagraphStyle = NSMutableParagraphStyle()
        titleParagraphStyle.paragraphSpacing = 0.0
        titleParagraphStyle.alignment = .center
        let attributedTitle = NSMutableAttributedString(
            string: product.localizedTitle,
            attributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline),
                NSAttributedString.Key.paragraphStyle: titleParagraphStyle
            ]
        )
        buttonTitle.append(attributedTitle)
        
        if iap.hasPrioritySupport {
            let prioritySupportDescription = NSLocalizedString(
                "[Premium/Upgrade/description] with priority support",
                value: "with priority support",
                comment: "Description of a premium option. Lowercase. For example 'Business Premium / with priority support'.")
            let descriptionParagraphStyle = NSMutableParagraphStyle()
            descriptionParagraphStyle.paragraphSpacingBefore = -3.0
            descriptionParagraphStyle.alignment = .center
            let attributedDescription = NSMutableAttributedString(
                string: "\n" + prioritySupportDescription,
                attributes: [
                    NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1),
                    NSAttributedString.Key.paragraphStyle: descriptionParagraphStyle
                ]
            )
            buttonTitle.append(attributedDescription)
        }
        
        let priceParagraphStyle = NSMutableParagraphStyle()
        priceParagraphStyle.paragraphSpacingBefore = 3.0
        priceParagraphStyle.alignment = .center
        let attributedPrice = NSMutableAttributedString(
            string: "\n" + productPrice,
            attributes: [
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .subheadline),
                NSAttributedString.Key.paragraphStyle: priceParagraphStyle
            ]
        )
        buttonTitle.append(attributedPrice)

        return buttonTitle
    }
    
    private func makePurchaseButton() -> UIButton {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 66).isActive = true
        button.setContentHuggingPriority(.required, for: .vertical)
        button.backgroundColor = UIColor.actionTint
        button.titleLabel?.textColor = UIColor.actionText
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.numberOfLines = 0
        button.cornerRadius = 10.0
        return button
    }
    
    
    public func setPurchasing(_ isPurchasing: Bool) {
        restorePurchasesButton.isEnabled = !isPurchasing
        purchaseButtons.forEach { button in
            button.isEnabled = !isPurchasing
            UIView.animate(withDuration: 0.3) {
                button.alpha = isPurchasing ? 0.5 : 1.0
            }
        }
        if isPurchasing {
            showMessage(NSLocalizedString(
                "[Premium/Upgrade/Progress] Contacting AppStore...",
                value: "Contacting AppStore...",
                comment: "Status message when downloading available in-app purchases")
            )
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

    
    @IBAction func didPressCancel(_ sender: Any) {
        delegate?.didPressCancel(in: self)
    }
    
    @IBAction func didPressRestorePurchases(_ sender: Any) {
        delegate?.didPressRestorePurchases(in: self)
    }
    
    @objc private func didPressPurchaseButton(_ sender: UIButton) {
        guard let products = products else { assertionFailure(); return }
        let productIndex = sender.tag
        delegate?.didPressBuy(product: products[productIndex], in: self)
    }
    
    @IBAction func didPressTerms(_ sender: Any) {
        AppGroup.applicationShared?.open(termsAndConditionsURL, options: [:])
    }
    @IBAction func didPressPrivacyPolicy(_ sender: Any) {
        AppGroup.applicationShared?.open(privacyPolicyURL, options: [:])
    }
}
