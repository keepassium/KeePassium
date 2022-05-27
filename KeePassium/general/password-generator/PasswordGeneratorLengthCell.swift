//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class PasswordGeneratorLengthCell: UITableViewCell {
    typealias ValueChangeHandler = (Int) -> Void
    
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var valueLabel: UILabel!
    @IBOutlet private weak var slider: UISlider!
    
    var title: String? {
        get { titleLabel.text }
        set {
            titleLabel.text = newValue
            slider.accessibilityLabel = newValue
        }
    }
    var minValue: Int {
        get { Int(slider.minimumValue) }
        set { slider.minimumValue = Float(newValue) }
    }
    var maxValue: Int {
        get { Int(slider.maximumValue) }
        set { slider.maximumValue = Float(newValue) }
    }
    var value: Int = 0 {
        didSet {
            slider.value = Float(value)
            valueLabel.text = String(value)
            slider.accessibilityValue = valueLabel.text
        }
    }
    var valueChanged: ValueChangeHandler?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        accessibilityElements = [slider as Any]
        slider.addTarget(self, action: #selector(sliderDidChangeValue), for: .valueChanged)
        selectionStyle = .none
    }
    
    @objc
    private func sliderDidChangeValue(_ sender: UISlider) {
        let value = Int(slider.value)
        guard value != self.value else {
            return
        }
        self.value = value
        valueChanged?(value)
    }
}
