//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

class ProtectedTextField: ValidatingTextField {
    private let horizontalInsets = CGFloat(8.0)
    private let verticalInsets = CGFloat(2.0)
    
    private let unhideImage = UIImage(asset: .unhideAccessory)
    private let hideImage = UIImage(asset: .hideAccessory)

    private var toggleButton: UIButton! 
    override var isSecureTextEntry: Bool {
        didSet {
            toggleButton?.isSelected = !isSecureTextEntry
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        toggleButton = UIButton(type: .custom)
        toggleButton.tintColor = UIColor.actionTint 
        toggleButton.addTarget(self, action: #selector(toggleVisibility), for: .touchUpInside)
        toggleButton.setImage(unhideImage, for: .normal)
        toggleButton.setImage(hideImage, for: .selected)
        toggleButton.imageEdgeInsets = UIEdgeInsets(
            top: verticalInsets,
            left: horizontalInsets,
            bottom: verticalInsets,
            right: horizontalInsets)
        toggleButton.frame = CGRect(
            x: 0.0,
            y: 0.0,
            width: hideImage.size.width + 2 * horizontalInsets,
            height: hideImage.size.height + 2 * verticalInsets)
        toggleButton.isSelected = !isSecureTextEntry
        toggleButton.isAccessibilityElement = true
        toggleButton.accessibilityLabel = NSLocalizedString(
            "[ProtectedTextField] Show Password",
            value: "Show Password",
            comment: "Action/button to make password visible as plain-text")
        self.rightView = toggleButton
        self.rightViewMode = .always
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetVisibility(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil)
    }

    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(
            x: bounds.maxX - hideImage.size.width - 2 * horizontalInsets,
            y: bounds.midY - hideImage.size.height / 2 - verticalInsets,
            width: hideImage.size.width + 2 * horizontalInsets,
            height: hideImage.size.height + 2 * verticalInsets)
    }
    
    @objc
    func resetVisibility(_ sender: Any) {
        isSecureTextEntry = true
    }
    
    @objc
    func toggleVisibility(_ sender: Any) {
        isSecureTextEntry = !isSecureTextEntry
    }
}
