//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
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

final class TipBoxVC: UIViewController {
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
                guard let self else { return }
                if self.statusLabel.isHidden != shouldHideText {
                    self.statusLabel.isHidden = shouldHideText
                }
                if self.spinner.isHidden != shouldHideSpinner {
                    self.spinner.isHidden = shouldHideSpinner
                }
                self.rootStackView.layoutIfNeeded()
            },
            completion: { [weak self] _ in
                guard let self else { return }
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
                guard let self else { return }
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
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = title
        buttonConfig.titleLineBreakMode = .byWordWrapping
        buttonConfig.titlePadding = 8
        buttonConfig.background.cornerRadius = 10
        let button = UIButton(configuration: buttonConfig)
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
        let text = [LString.tipBoxDescription2, LString.tipBoxCallToAction2]
            .joined(separator: "\n")
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
        attributedText.addAttribute(
            .foregroundColor,
            value: UIColor.primaryText,
            range: NSRange(0..<attributedText.length)
        )
        return attributedText
    }
}
