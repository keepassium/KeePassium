//  KeePassium Password Manager
//  Copyright © 2018–2021 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib
import StoreKit

protocol TipBoxDelegate: AnyObject {
    func didFinishLoading(_ viewController: TipBoxVC)
    func didPressPurchase(product: SKProduct, in viewController: TipBoxVC)
}

final class TipBoxVC: NavViewController {
    @IBOutlet private weak var rootStackView: UIStackView!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var buttonsStackView: UIStackView!
    @IBOutlet private weak var spinner: UIActivityIndicatorView!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var thankYouLabel: UILabel!
    
    public weak var delegate: TipBoxDelegate?
    
    private var products = [SKProduct]()
    private var purchaseButtons = [UIButton]() 
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = LString.tipBoxTitle3
        descriptionLabel.attributedText = getDescription()
        thankYouLabel.text = LString.tipBoxThankYou
        setStatus(busy: false, text: nil, animated: false)
        
        updatePurchaseButtons()
        delegate?.didFinishLoading(self)
    }
    
    public func setStatus(busy: Bool, text: String?, animated: Bool) {
        view.isUserInteractionEnabled = !busy
        statusLabel.text = text
        let shouldHideText = (text == nil)
        let shouldHideSpinner = !busy
        UIView.animate(
            withDuration: animated ? 0.3 : 0,
            delay: 0,
            options: [.beginFromCurrentState],
            animations: { [weak self] in
                guard let self = self else { return }
                if self.statusLabel.isHidden != shouldHideText {
                    self.statusLabel.isHidden = shouldHideText
                }
                if self.spinner.isHidden != shouldHideSpinner {
                    self.spinner.isHidden = shouldHideSpinner
                }
                self.rootStackView.layoutIfNeeded()
            },
            completion: { [weak self] _ in
                guard let self = self else { return }
                if !self.statusLabel.isHidden {
                    UIAccessibility.post(notification: .layoutChanged, argument: self.statusLabel)
                }
            }
        )
    }
    
    public func setThankYou(visible: Bool) {
        let shouldHide = !visible
        guard thankYouLabel.isHidden != shouldHide else { 
            return
        }
        if visible {
            UIAccessibility.post(notification: .announcement, argument: thankYouLabel.text)
        }
        UIView.animate(
            withDuration: 0.3,
            delay: shouldHide ? 0 : 0.5, 
            options: [.curveEaseInOut],
            animations: { [weak self] in
                guard let self = self else { return }
                self.thankYouLabel.isHidden = shouldHide
                self.rootStackView.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    public func setProducts(_ products: [SKProduct]) {
        self.products = products
        if isViewLoaded {
            updatePurchaseButtons()
        }
    }
    
    private func updatePurchaseButtons() {
        buttonsStackView.arrangedSubviews.forEach {
            buttonsStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        purchaseButtons.removeAll()
        
        let buttonTitles = products.map { $0.localizedPrice }
        for buttonTitle in buttonTitles {
            let button = makePurchaseButton(buttonTitle)
            buttonsStackView.addArrangedSubview(button)
            purchaseButtons.append(button)
        }
    }
    
    private func makePurchaseButton(_ title: String) -> UIButton {
        let button = UIButton(frame: .zero)
        button.titleLabel?.font = UIFont.systemFont(forTextStyle: .headline)
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.numberOfLines = 1
        button.setTitleColor(UIColor.actionTint, for: .normal)
        button.borderColor = .actionTint
        button.borderWidth = 1
        button.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        button.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        button.widthAnchor
            .constraint(greaterThanOrEqualToConstant: 70)
            .setPriority(.required)
            .activate()
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: #selector(didPressPurchaseButton(_:)), for: .touchUpInside)
        return button
    }
    
    @objc
    private func didPressPurchaseButton(_ sender: UIButton) {
        guard let buttonIndex = purchaseButtons.firstIndex(of: sender) else {
            Diag.warning("No such button, aborting")
            assertionFailure()
            return
        }
        guard buttonIndex < products.count else {
            Diag.warning("Unexpected product index, aborting")
            assertionFailure()
            return
        }
        let selectedProduct = products[buttonIndex]
        delegate?.didPressPurchase(product: selectedProduct, in: self)
    }
}

extension TipBoxVC {    
    private func getDescription() -> NSAttributedString {
        let lines = TestHelper.getCurrent(from: [
            [LString.tipBoxDescription1, LString.tipBoxCallToAction1],
            [LString.tipBoxDescription2, LString.tipBoxCallToAction2],
            [LString.tipBoxDescription3, LString.tipBoxCallToAction3],
        ])
        let text = lines.joined(separator: "\n")
        return makeAttributedString(text: text)
    }
    
    private func makeAttributedString(text: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .natural
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = 1.2
        paragraphStyle.paragraphSpacing = 6.0
        paragraphStyle.paragraphSpacingBefore = 6.0
        
        let font = UIFont.preferredFont(forTextStyle: .body)
        
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                NSAttributedString.Key.font: font,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )
        if #available(iOS 13, *) {
            attributedText.addAttribute(
                .foregroundColor,
                value: UIColor.primaryText,
                range: NSRange(0..<attributedText.length)
            )
        }
        return attributedText
    }
}

extension LString {
    public static let tipBoxTitle1 = NSLocalizedString(
        "[TipBox/title/1]",
        value: "Tip Jar",
        comment: "Title of the tip box/donation screen."
    )
    public static let tipBoxTitle2 = NSLocalizedString(
        "[TipBox/title/2]",
        value: "Donations",
        comment: "Title of the tip box/donation screen."
    )
    public static let tipBoxTitle3 = NSLocalizedString(
        "[TipBox/title/3]",
        value: "Support KeePassium",
        comment: "Call to action, title of the tip box/donation screen."
    )

    public static let tipBoxDescription1 = NSLocalizedString(
        "[TipBox/description/1]",
        value: "Do you like KeePassium?",
        comment: "Text in the Donations screen."
    )
    public static let tipBoxDescription2 = NSLocalizedString(
        "[TipBox/description/2]",
        value: "KeePassium is a free open-source app. You trust it with your most sensitive information. There are no ads, no spying, no nonsense — we respect you.",
        comment: "Text in the Donations screen."
    )
    public static let tipBoxDescription3 = NSLocalizedString(
        "[TipBox/description/3]",
        value: "Do you like KeePassium but don't need the premium features?",
        comment: "Text in the Donations screen."
    )
    
    public static let tipBoxCallToAction1 = NSLocalizedString(
        "[TipBox/callToAction/1]",
        value: "Help us make KeePassium better!",
        comment: "Call to action in the Donations screen."
    )
    public static let tipBoxCallToAction2 = NSLocalizedString(
        "[TipBox/callToAction/2]",
        value: "Help us keep KeePassium shiny!",
        comment: "Call to action in the Donations screen."
    )
    public static let tipBoxCallToAction3 = NSLocalizedString(
        "[TipBox/callToAction/3]",
        value: "Help us keep KeePassium free!",
        comment: "Call to action in the Donations screen. (free = gratis)"
    )
    
    public static let tipBoxThankYou = NSLocalizedString(
        "[TipBox/thankYou]",
        value: "Thank you!",
        comment: "Notification after a successful donation."
    )
}
