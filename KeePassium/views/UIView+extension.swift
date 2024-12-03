//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension UIView {
    @IBInspectable var borderColor: UIColor? {
        get {
            guard let cgColor = layer.borderColor else { return nil }
            return UIColor(cgColor: cgColor)
        }
        set {
            layer.borderColor = newValue?.cgColor
        }
    }

    @IBInspectable var borderWidth: CGFloat {
        get {
            return layer.borderWidth
        }
        set {
            layer.borderWidth = newValue
        }
    }

    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
        }
    }

    @IBInspectable var maskedCorners: CACornerMask {
        get {
            return layer.maskedCorners
        }
        set {
            layer.maskedCorners = newValue
        }
    }

    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.duration = 0.6
        animation.values = [-15.0, 15.0, -15.0, 15.0, -7.0, 7.0, -3.0, 3.0, 0.0 ]
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        layer.add(animation, forKey: "shake")
    }

    func becomeFirstResponderWhenSafe() {
        guard AppGroup.isAppExtension else {
            DispatchQueue.main.async { [weak self] in
                self?.becomeFirstResponder()
            }
            return
        }

        let delay = BiometricsHelper.delayBeforeKeyboardAvailable
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.becomeFirstResponder()
        }
    }

    func setVisible(_ visible: Bool) {
        let isAlreadyVisible = !isHidden
        guard visible != isAlreadyVisible else {
            return
        }
        self.isHidden = !visible
    }
}
