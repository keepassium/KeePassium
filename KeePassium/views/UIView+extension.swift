//  KeePassium Password Manager
//  Copyright © 2018–2023 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

extension UIView {
    @IBInspectable var borderColor: UIColor? {
        set {
            layer.borderColor = newValue?.cgColor
        }
        get {
            guard let cgColor = layer.borderColor else { return nil }
            return UIColor(cgColor: cgColor)
        }
    }
    
    @IBInspectable var borderWidth: CGFloat {
        set {
            layer.borderWidth = newValue
        }
        get {
            return layer.borderWidth
        }
    }
    
    @IBInspectable var cornerRadius: CGFloat {
        set {
            layer.cornerRadius = newValue
        }
        get {
            return layer.cornerRadius
        }
    }
    
    @IBInspectable var maskedCorners: CACornerMask {
        set {
            layer.maskedCorners = newValue
        }
        get {
            return layer.maskedCorners
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
        guard #available(iOS 14, *) else {
            DispatchQueue.main.async { [weak self] in
                self?.becomeFirstResponder()
            }
            return
        }
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
}
