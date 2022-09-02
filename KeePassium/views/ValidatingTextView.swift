//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol ValidatingTextViewDelegate {
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
    private let defaultBorderColor = UIColor.gray.withAlphaComponent(0.25).cgColor
    
    @IBInspectable var invalidBackgroundColor: UIColor? = UIColor.red.withAlphaComponent(0.2)
    
    @IBInspectable var validBackgroundColor: UIColor? = UIColor.clear

    var validityDelegate: ValidatingTextViewDelegate?
    var isValid: Bool {
        get { return validityDelegate?.validatingTextViewShouldValidate(self) ?? true }
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
        layer.borderColor = defaultBorderColor
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
        } else if (wasValid ?? true) { 
            backgroundColor = invalidBackgroundColor
        }
        if isValid != wasValid {
            validityDelegate?.validatingTextView(self, validityDidChange: isValid)
        }
        wasValid = isValid
    }
}

#if targetEnvironment(macCatalyst)
extension ValidatingTextView {
    @objc(_focusRingType)
    var focusRingType: UInt {
        return 1 
    }
    
    private func refreshFocusRing() {
        if isFirstResponder {
            borderWidth = 3
            borderColor = .systemBlue.withAlphaComponent(0.5)
        } else {
            setupDefaultBorder()
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        refreshFocusRing()
        return result
    }
    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        refreshFocusRing()
        return result
    }
}
#endif
