//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class PasswordGeneratorFixedSetCell: UITableViewCell {
    static let buttonSize = 29
    static let buttonSpacing = 8
    
    typealias ValueChangeHandler = (InclusionCondition) -> Void
    var valueChangeHandler: ValueChangeHandler?
    
    var value: InclusionCondition = .allowed {
        didSet {
            switch value {
            case .inactive:
                textLabel?.textColor = .disabledText
                detailTextLabel?.textColor = .disabledText
            case .excluded, .allowed, .required:
                textLabel?.textColor = .primaryText
                detailTextLabel?.textColor = .auxiliaryText
            }
            detailTextLabel?.text = value.description
            detailTextLabel?.accessibilityLabel = "" 
            selectorView.value = value
            imageView?.image = value.image
        }
    }
    
    override var isAccessibilityElement: Bool {
        set { /* no-op, read-only */ }
        get { true }
    }
    override var accessibilityTraits: UIAccessibilityTraits {
        set { /* no-op, read-only */ }
        get { .adjustable }
    }
    override var accessibilityValue: String? {
        set { /* no-op, read-only */ }
        get { value.description }
    }
    
    fileprivate var selectorView: ConditionSelectorView!
    var availableValues: [InclusionCondition] = [] {
        didSet {
            selectorView.setButtons(for: availableValues)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        detailTextLabel?.isAccessibilityElement = false
        selectionStyle = .none
        selectorView = ConditionSelectorView(
            frame: CGRect(x: 0, y: 0, width: 0, height: PasswordGeneratorFixedSetCell.buttonSize))
        selectorView.valueChangeHandler = { [weak self] newValue in
            self?.value = newValue
            self?.valueChangeHandler?(newValue)
        }
        accessoryView = selectorView
    }
    
    override func accessibilityIncrement() {
        guard var index = availableValues.firstIndex(of: value) else {
            assertionFailure("Current value is not among the available ones")
            return
        }
        index += 1
        if index >= availableValues.count {
            index = 0
        }
        value = availableValues[index]
        valueChangeHandler?(value)
    }
    
    override func accessibilityDecrement() {
        guard var index = availableValues.firstIndex(of: value) else {
            assertionFailure("Current value is not among the available ones")
            return
        }
        index -= 1
        if index < 0 {
            index = availableValues.count - 1
        }
        value = availableValues[index]
        valueChangeHandler?(value)
    }
}

extension PasswordGeneratorFixedSetCell {
    
    fileprivate class OptionButton: UIButton {
        override var isSelected: Bool {
            didSet {
                backgroundColor = isSelected ? .actionTint : .clear
            }
        }
    }
    fileprivate class ConditionSelectorView: UIStackView {
        var valueChangeHandler: ValueChangeHandler?
        
        private var buttons = [InclusionCondition: OptionButton]()
        var value: InclusionCondition? {
            didSet {
                buttons.values.forEach {
                    $0.isSelected = false
                }
                if let condition = value {
                    buttons[condition]?.isSelected = true
                }
            }
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            axis = .horizontal
            spacing = CGFloat(PasswordGeneratorFixedSetCell.buttonSpacing)
            alignment = .fill
            distribution = .fillEqually
            setButtons(for: [.excluded, .allowed, .required])
            value = .allowed
            isAccessibilityElement = false 
        }
        
        deinit {
            buttons.removeAll()
        }

        public func resetButtons() {
            buttons.removeAll()
            arrangedSubviews.forEach {
                $0.removeFromSuperview()
            }
        }
        
        public func setButtons(for conditions: [InclusionCondition]) {
            resetButtons()
            bounds = CGRect(
                x: 0,
                y: 0,
                width: PasswordGeneratorFixedSetCell.buttonSize * conditions.count +
                       PasswordGeneratorFixedSetCell.buttonSpacing * (conditions.count - 1),
                height: PasswordGeneratorFixedSetCell.buttonSize
            )
            conditions.forEach { condition in
                let button = OptionButton()
                button.setTitleColor(.actionTint, for: .normal)
                button.setTitleColor(.actionText, for: .selected)
                button.setTitle(condition.glyphSymbol, for: .normal)
                button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
                button.isAccessibilityElement = false 
                button.borderWidth = 1
                button.cornerRadius = CGFloat(PasswordGeneratorFixedSetCell.buttonSize / 2)
                button.borderColor = .actionTint
                button.contentMode = .scaleAspectFit
                button.addTarget(self, action: #selector(didPressButton(_:)), for: .touchUpInside)
                addArrangedSubview(button)
                buttons[condition] = button
            }
            value = conditions.first!
        }
        
        required init(coder aDecoder: NSCoder) {
            fatalError("Not implemented")
        }
        
        @objc
        private func didPressButton(_ button: UIButton) {
            guard let condition = buttons.first(where: { $1 === button })?.key else {
                assertionFailure("Unknown button pressed")
                return
            }
            value = condition
            valueChangeHandler?(condition)
        }
    }
}


final class PasswordGeneratorStepperCell: UITableViewCell {
    private let maxValue = 6
    
    typealias ValueChangeHandler = (Int?) -> Void
    var valueChangeHandler: ValueChangeHandler?
    
    var title: String? {
        get { textLabel?.text }
        set {
            textLabel?.text = newValue
            stepper.accessibilityLabel = newValue
        }
    }
    var value: Int? = nil {
        didSet {
            stepper.value = Double(value ?? maxValue)
            let description = getDescription(for: value)
            detailTextLabel?.text = description
            stepper.accessibilityValue = description
        }
    }
    
    fileprivate var stepper: UIStepper!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        selectionStyle = .none
        stepper = AccessibleStepper(frame: CGRect.zero)
        stepper.minimumValue = 1
        stepper.maximumValue = Double(maxValue)
        stepper.value = stepper.maximumValue
        stepper.addTarget(self, action: #selector(stepperDidChangeValue(_:)), for: .valueChanged)
        accessoryView = stepper
        
        isAccessibilityElement = false 
        accessibilityElements = [stepper as Any]
    }
    
    @objc private func stepperDidChangeValue(_ sender: UIStepper) {
        let senderValue = Int(sender.value)
        if senderValue == maxValue {
            self.value = nil
        } else {
            self.value = senderValue
        }
        valueChangeHandler?(self.value)
    }
    
    private func getDescription(for value: Int?) -> String {
        if let value = value {
            return String(value)
        } else {
            return "∞"
        }
    }
}
