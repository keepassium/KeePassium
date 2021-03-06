// The code below is from https://github.com/MengTo/Spring/blob/master/Spring/KeyboardLayoutConstraint.swift
// Modified by Andrei Popleteev for KeePassium
//
// The MIT License (MIT)
//
// Copyright (c) 2015 James Tang (j@jamztang.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

#if !os(tvOS)
@available(tvOS, unavailable)
public class KeyboardLayoutConstraint: NSLayoutConstraint {
    
    public var viewOffset: CGFloat = 0 {
        didSet {
            updateConstant()
        }
    }
    
    private var offset : CGFloat = 0
    private var keyboardVisibleHeight : CGFloat = 0

    @available(tvOS, unavailable)
    override public func awakeFromNib() {
        super.awakeFromNib()
        
        offset = constant
        
        let nc = NotificationCenter.default
        nc.addObserver(self,
                       selector: #selector(KeyboardLayoutConstraint.keyboardWillShowNotification(_:)),
                       name: UIResponder.keyboardWillShowNotification,
                       object: nil)
        nc.addObserver(self,
                       selector: #selector(KeyboardLayoutConstraint.keyboardWillHideNotification(_:)),
                       name: UIResponder.keyboardWillHideNotification,
                       object: nil)
    }
    
    deinit {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    
    @objc func keyboardWillShowNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        if let frameValue = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let frame = frameValue.cgRectValue
            keyboardVisibleHeight = frame.size.height
        }
        
        self.updateConstant()
        switch (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
                userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)
        {
        case let (.some(duration), .some(curve)):
            let options = UIView.AnimationOptions(rawValue: curve.uintValue)
            UIView.animate(
                withDuration: TimeInterval(duration.doubleValue),
                delay: 0,
                options: options,
                animations: {
                    UIApplication.shared.getKeyWindow()?.layoutIfNeeded()
                    return
                },
                completion: nil)
        default:
            break
        }
    }
    
    @objc func keyboardWillHideNotification(_ notification: NSNotification) {
        keyboardVisibleHeight = 0
        self.updateConstant()
        
        guard let userInfo = notification.userInfo else { return }
            
        switch (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber,
                userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)
        {
        case let (.some(duration), .some(curve)):
            let options = UIView.AnimationOptions(rawValue: curve.uintValue)
            UIView.animate(
                withDuration: TimeInterval(duration.doubleValue),
                delay: 0,
                options: options,
                animations: {
                    UIApplication.shared.getKeyWindow()?.layoutIfNeeded()
                    return
                },
                completion: nil)
        default:
            break
        }
    }
    
    func updateConstant() {
        self.constant = offset + max(0, keyboardVisibleHeight - viewOffset)
    }
    
}
#endif
