//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

class ProtectedTextField: ValidatingTextField {
    private let horizontalInsets = CGFloat(8.0)
    private let verticalInsets = CGFloat(2.0)

    private let unhideImage = UIImage.symbol(.eye)!
    private let hideImage = UIImage.symbol(.eyeFill)!

    private var toggleButton: UIButton! 
    private var originalContentType: UITextContentType?
    private var originalAutocorrectionType: UITextAutocorrectionType = .default

    override var isSecureTextEntry: Bool {
        didSet {
            toggleButton?.isSelected = !isSecureTextEntry
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        setupVisibilityAccessory()
        allowAutoFillPrompt(Settings.current.acceptAutoFillInput)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resetVisibility(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil)
    }

    private func setupVisibilityAccessory() {
        var buttonConfig = UIButton.Configuration.plain()
        buttonConfig.imagePadding = 2
        buttonConfig.imageReservation = 32
        buttonConfig.baseBackgroundColor = .clear
        buttonConfig.imagePlacement = .all
        buttonConfig.preferredSymbolConfigurationForImage = .init(textStyle: .body, scale: .medium)
        toggleButton = UIButton(configuration: buttonConfig)
        toggleButton.configurationUpdateHandler = { [self] button in
            if button.state.contains(.selected) {
                button.configuration?.image = hideImage
            } else {
                button.configuration?.image = unhideImage
            }
        }
        toggleButton.addTarget(self, action: #selector(toggleVisibility), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        toggleButton.isSelected = !isSecureTextEntry
        toggleButton.isAccessibilityElement = true
        toggleButton.accessibilityLabel = NSLocalizedString(
            "[ProtectedTextField] Show Password",
            value: "Show Password",
            comment: "Action/button to make password visible as plain-text")
        self.rightView = toggleButton
        self.rightViewMode = .always
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

    func allowAutoFillPrompt(_ allowed: Bool) {
        guard #available(iOS 12, *) else {
            return
        }
        if allowed {
            if textContentType == .oneTimeCode {
                textContentType = originalContentType
            }
            if autocorrectionType == .no {
                autocorrectionType = originalAutocorrectionType
            }
        } else {
            originalContentType = textContentType
            originalAutocorrectionType = autocorrectionType
            textContentType = .oneTimeCode
            autocorrectionType = .no
        }
    }
}
