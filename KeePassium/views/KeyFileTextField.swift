//
//  KeyFileTextField.swift
//  KeePassium
//
//  Created by Andrei on 25/11/2019.
//  Copyright © 2019 Andrei Popleteev. All rights reserved.
//

import UIKit

typealias YubiHandler = ((KeyFileTextField)->Void)

class KeyFileTextField: ValidatingTextField {
    private let horizontalInsets = CGFloat(8.0)
    private let verticalInsets = CGFloat(2.0)
    
    private let yubiKeyOnImage = UIImage(asset: .yubikeyOnAccessory)
    private let yubiKeyOffImage = UIImage(asset: .yubikeyOffAccessory)
    
    private var yubiButton: UIButton! 
    public var isYubiKeyActive: Bool = false {
        didSet {
            guard let button = rightView as? UIButton else { return }
            button.isSelected = isYubiKeyActive
            setNeedsDisplay()
        }
    }
    
    public var yubikeyHandler: YubiHandler? = nil
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupYubiButton()
    }
    
    private func setupYubiButton() {
        let yubiButton = UIButton(type: .custom)
        yubiButton.tintColor = UIColor.actionTint
        yubiButton.addTarget(self, action: #selector(didPressYubiButton), for: .touchUpInside)
        yubiButton.setImage(yubiKeyOffImage, for: .normal)
        yubiButton.setImage(yubiKeyOnImage, for: .selected)
        
        let horizontalInsets = CGFloat(8.0)
        let verticalInsets = CGFloat(2.0)
        yubiButton.imageEdgeInsets = UIEdgeInsets(
            top: verticalInsets,
            left: horizontalInsets,
            bottom: verticalInsets,
            right: horizontalInsets)
        yubiButton.frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: yubiKeyOffImage.size.width + 2 * horizontalInsets,
            height: yubiKeyOffImage.size.height + 2 * verticalInsets)
        yubiButton.isAccessibilityElement = true
        yubiButton.accessibilityLabel = NSLocalizedString(
            "[Database/Unlock] YubiKey",
            value: "YubiKey",
            comment: "Action/button to setup YubiKey key component")
        self.yubiButton = yubiButton
        self.rightView = yubiButton
        self.rightViewMode = .always
    }
    
    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(
            x: bounds.maxX - yubiKeyOffImage.size.width - 2 * horizontalInsets,
            y: bounds.midY - yubiKeyOffImage.size.height / 2 - verticalInsets,
            width: yubiKeyOffImage.size.width + 2 * horizontalInsets,
            height: yubiKeyOffImage.size.height + 2 * verticalInsets)
    }
    
    @objc private func didPressYubiButton(_ sender: Any) {
        self.yubikeyHandler?(self)
    }
}
