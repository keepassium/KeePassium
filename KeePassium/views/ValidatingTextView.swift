//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol ValidatingTextViewDelegate: AnyObject {
    func validatingTextView(_ sender: ValidatingTextView, textDidChange text: String)
    func validatingTextViewShouldValidate(_ sender: ValidatingTextView) -> Bool
    func validatingTextView(_ sender: ValidatingTextView, validityDidChange: Bool)
}

extension ValidatingTextViewDelegate {
    func validatingTextView(_ sender: ValidatingTextView, textDidChange text: String) {}
    func validatingTextViewShouldValidate(_ sender: ValidatingTextView) -> Bool { return true }
    func validatingTextView(_ sender: ValidatingTextView, validityDidChange: Bool) {}
}

class ValidatingTextView: WatchdogAwareTextView {
    private let defaultBorderColor = UIColor.gray.withAlphaComponent(0.25)
    private let focusedBorderColor: UIColor = .tintColor.withAlphaComponent(0.5)

    @IBInspectable var invalidBackgroundColor: UIColor? = UIColor.red.withAlphaComponent(0.2)

    @IBInspectable var validBackgroundColor: UIColor? = UIColor.clear

    var validityDelegate: ValidatingTextViewDelegate?
    var isValid: Bool {
        return validityDelegate?.validatingTextViewShouldValidate(self) ?? true
    }

    override var text: String? {
        didSet { validate() }
    }

    private var wasValid: Bool?
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        validBackgroundColor = backgroundColor
        setupDefaultBorder()
    }

    private func setupDefaultBorder() {
        layer.cornerRadius = 5.0
        layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMinXMaxYCorner,
            .layerMaxXMinYCorner,
            .layerMaxXMaxYCorner]
        layer.borderWidth = 0.8
        layer.borderColor = defaultBorderColor.cgColor
    }

    @objc
    override func onTextChanged() {
        super.onTextChanged()
        validityDelegate?.validatingTextView(self, textDidChange: self.text ?? "")
        validate()
    }

    func validate() {
        let isValid = validityDelegate?.validatingTextViewShouldValidate(self) ?? true
        if isValid {
            backgroundColor = validBackgroundColor
        } else if wasValid ?? true { 
            backgroundColor = invalidBackgroundColor
        }
        if isValid != wasValid {
            validityDelegate?.validatingTextView(self, validityDidChange: isValid)
        }
        wasValid = isValid
    }
}


extension ValidatingTextView {
    #if targetEnvironment(macCatalyst)
    override var focusEffect: UIFocusEffect? {
        get {
            UIFocusHaloEffect(
                roundedRect: bounds,
                cornerRadius: cornerRadius,
                curve: .continuous)
        }
        set {
        }
    }

    @objc(_focusRingType)
    var focusRingType: UInt {
        return 1 
    }

    #endif
}
