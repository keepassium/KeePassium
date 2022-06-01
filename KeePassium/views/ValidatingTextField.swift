//  KeePassium Password Manager
//  Copyright © 2018–2022 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

protocol ValidatingTextFieldDelegate: AnyObject {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String)
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool)
}

extension ValidatingTextFieldDelegate {
    func validatingTextField(_ sender: ValidatingTextField, textDidChange text: String) {}
    func validatingTextFieldShouldValidate(_ sender: ValidatingTextField) -> Bool { return true }
    func validatingTextField(_ sender: ValidatingTextField, validityDidChange isValid: Bool) {}
}

class ValidatingTextField: UITextField {
    
    private weak var externalDelegate: UITextFieldDelegate?
    override var delegate: UITextFieldDelegate? {
        didSet {
            if delegate === self {
                return
            } else {
                externalDelegate = delegate
                delegate = self
            }
        }
    }
    
    weak var validityDelegate: ValidatingTextFieldDelegate?
    
    
    @IBInspectable var invalidBackgroundColor: UIColor? = UIColor.red.withAlphaComponent(0.2)
    
    @IBInspectable var validBackgroundColor: UIColor? = UIColor.clear
    
    @IBInspectable var isWatchdogAware = true
    
    @IBInspectable var leftTextInset: CGFloat = 0.0 {
        didSet {
            layoutIfNeeded()
        }
    }
    
    var isValid: Bool {
        get { return validityDelegate?.validatingTextFieldShouldValidate(self) ?? true }
    }

    override var text: String? {
        didSet { validate() }
    }
    
    private var wasValid: Bool?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        validBackgroundColor = backgroundColor
        delegate = self
        addTarget(self, action: #selector(onEditingChanged), for: .editingChanged)
    }
    
    @objc
    private func onEditingChanged(textField: UITextField) {
        if isWatchdogAware {
            Watchdog.shared.restart()
        }
        validityDelegate?.validatingTextField(self, textDidChange: textField.text ?? "")
        validate()
    }
    
    func validate() {
        let isValid = validityDelegate?.validatingTextFieldShouldValidate(self) ?? true
        if isValid {
            backgroundColor = validBackgroundColor
        } else if (wasValid ?? true) { 
            backgroundColor = invalidBackgroundColor
        }
        if (wasValid == nil) || (isValid != wasValid) {
            wasValid = isValid
            validityDelegate?.validatingTextField(self, validityDidChange: isValid)
        }
    }
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.textRect(forBounds: bounds)
        return rect.inset(by: .init(top: 0, left: leftTextInset, bottom: 0, right: 0))
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        let rect = super.editingRect(forBounds: bounds)
        return rect.inset(by: .init(top: 0, left: leftTextInset, bottom: 0, right: 0))
    }

    
    #if targetEnvironment(macCatalyst)
    @objc(_focusRingType)
    var focusRingType: UInt {
        return 1 
    }
    #endif
    
    private func refreshFocusRing() {
        #if targetEnvironment(macCatalyst)
        if isEditing {
            borderWidth = 3
            borderColor = .systemBlue.withAlphaComponent(0.5)
        } else {
            borderWidth = 0
            borderColor = .clear
        }
        #endif
    }
}

extension ValidatingTextField: UITextFieldDelegate {
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        refreshFocusRing()
        return externalDelegate?.textFieldShouldBeginEditing?(textField) ?? true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        refreshFocusRing()
        externalDelegate?.textFieldDidBeginEditing?(textField)
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        refreshFocusRing()
        return externalDelegate?.textFieldShouldEndEditing?(textField) ?? true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        refreshFocusRing()
        externalDelegate?.textFieldDidEndEditing?(textField, reason: reason)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        refreshFocusRing()
        externalDelegate?.textFieldDidEndEditing?(textField)
    }
    
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        DispatchQueue.main.async { [weak self] in
            self?.onEditingChanged(textField: textField)
        }
        let result = externalDelegate?.textField?(
            textField,
            shouldChangeCharactersIn: range,
            replacementString: string
        )
        return result ?? true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return externalDelegate?.textFieldShouldClear?(textField) ?? true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return externalDelegate?.textFieldShouldReturn?(textField) ?? true
    }
    
    @available(iOS 13, *)
    func textFieldDidChangeSelection(_ textField: UITextField) {
        externalDelegate?.textFieldDidChangeSelection?(textField)
    }
}

extension ValidatingTextField: TextInputEditMenuDelegate {
    func textInputDidRequestRandomizer(_ textInput: TextInputView) {
        guard let externalEditMenuDelegate = externalDelegate as? TextInputEditMenuDelegate else {
            assertionFailure("Randomizer requested from where it was not shown")
            return
        }
        return externalEditMenuDelegate.textInputDidRequestRandomizer(textInput)
    }
}
