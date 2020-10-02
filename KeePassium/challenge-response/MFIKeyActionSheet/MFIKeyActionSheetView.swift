// Copyright 2018-2019 Yubico AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit


class MFIKeyActionSheetViewConfiguration {
    
    let presentAnimationDuration = 0.3
    let dismissAnimationDuration = 0.2
    
    let presentAnimationDurationSlow = 0.5
    let dismissAnimationDurationSlow = 0.4
    
    var currentPresentAnimationDuration: TimeInterval {
        get {
            let cores = ProcessInfo.processInfo.processorCount
            return cores >= 4 ? presentAnimationDuration : presentAnimationDurationSlow
        }
    }
    
    var currentDismissAnimationDuration: TimeInterval {
        get {
            let cores = ProcessInfo.processInfo.processorCount
            return cores >= 4 ? dismissAnimationDuration : dismissAnimationDurationSlow
        }
    }
    
    let actionSheetViewFadeViewAlpha: CGFloat = 0.6
    
    let actionSheetViewBottomConstraintConstant: CGFloat = 5.0
    let keyImageViewTopConstraintDisconnectedConstant: CGFloat = 8
    let keyImageViewTopConstraintConnectedConstant: CGFloat = -19
}


protocol MFIKeyActionSheetViewDelegate: class {
    func mfiKeyActionSheetDidDismiss(_ actionSheet: MFIKeyActionSheetView)
}

class MFIKeyActionSheetView: UIView {
    
    weak var delegate: MFIKeyActionSheetViewDelegate?

    private let configuration = MFIKeyActionSheetViewConfiguration()    
    private static let viewNibName = String(describing: MFIKeyActionSheetView.self)
    
    private var isPresenting = false
    private var isDismissing = false
    
    
    @IBOutlet var actionSheetBottomConstraint: NSLayoutConstraint!
    @IBOutlet var actionSheetView: UIView!
    
    @IBOutlet var keyImageView: UIImageView!
    @IBOutlet var keyImageViewTopConstraint: NSLayoutConstraint!
    
    @IBOutlet var deviceImageView: UIImageView!
    
    @IBOutlet var keyActionContainerView: UIView!
    @IBOutlet var backgroundFadeView: UIView!
    @IBOutlet var borderView: UIView!
    
    @IBOutlet var cancelButton: UIButton!
    @IBOutlet var messageLabel: UILabel!
    
    
    class func loadViewFromNib() -> MFIKeyActionSheetView? {
        guard let nibs = Bundle.main.loadNibNamed(viewNibName, owner: nil, options: nil) else {
            return nil
        }
        guard let view = nibs.first as? MFIKeyActionSheetView else {
            return nil
        }
        return view
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    private func setupView() {
        if UIDevice.current.hasHomeButton() {
            deviceImageView.image = UIImage(asset: .yubikeyMFIPhone)
        } else {
            deviceImageView.image = UIImage(asset: .yubikeyMFIPhoneNew)
        }        
        resetState()
    }
    
    
    private func resetState() {
        borderView.backgroundColor = UIColor.mfiKeyActionSheetIdleColor
        messageLabel.text = nil
        
        layer.removeAllAnimations()
        keyImageView.layer.removeAllAnimations()
        cancelButton.isHidden = false
    }
    
    func animateProcessing(message: String) {
        resetState()
        
        borderView.backgroundColor = UIColor.mfiKeyActionSheetProcessingColor
        messageLabel.text = message
        
        animateKeyConnected()
        pulsateBorderView(duration: 1.5)
    }
    
    func animateInsertKey(message: String) {
        resetState()
        
        borderView.backgroundColor = UIColor.mfiKeyActionSheetIdleColor
        messageLabel.text = message
        
        animateConnectKey()
    }
    
    func animateKeyInserted(message: String) {
        resetState()
        
        borderView.backgroundColor = UIColor.mfiKeyActionSheetIdleColor
        messageLabel.text = message
        
        animateConnectKey()
    }
    
    func animateTouchKey(message: String) {
        resetState()

        cancelButton.isHidden = true
        
        borderView.backgroundColor = UIColor.mfiKeyActionSheetTouchColor
        messageLabel.text = message
        
        animateKeyConnected()
        pulsateBorderView(duration: 1)
    }
    
    
    func present(animated: Bool, delay: TimeInterval = 0.0, completion: @escaping ()->Void) {
        guard !isPresenting else {
            return
        }
        isPresenting = true
        
        actionSheetBottomConstraint.constant = -(actionSheetBottomConstraint.constant + actionSheetView.frame.size.height)
        backgroundFadeView.alpha = 0
        
        layoutIfNeeded()
        
        actionSheetBottomConstraint.constant = configuration.actionSheetViewBottomConstraintConstant

        let options: UIView.AnimationOptions = [.beginFromCurrentState, .curveEaseOut]
        
        UIView.animate(withDuration: configuration.currentPresentAnimationDuration, delay: delay, options:options, animations: { [weak self] in
            guard let self = self else {
                return
            }
            self.layoutIfNeeded()
            self.backgroundFadeView.alpha = self.configuration.actionSheetViewFadeViewAlpha
        }) { [weak self](_) in
            completion()
            self?.isPresenting = false
        }
    }
    
    func dismiss(animated: Bool, delayed: Bool = true, completion: @escaping ()->Void) {
        guard !isDismissing else {
            return
        }
        isDismissing = true
        
        actionSheetBottomConstraint.constant = configuration.actionSheetViewBottomConstraintConstant
        layoutIfNeeded()
        
        actionSheetBottomConstraint.constant = -(actionSheetBottomConstraint.constant + actionSheetView.frame.size.height)
        
        let delay = delayed ? 1.0 : 0
        let options: UIView.AnimationOptions = [.beginFromCurrentState, .curveEaseIn]
        
        UIView.animate(withDuration: configuration.currentDismissAnimationDuration, delay: delay, options:options, animations: { [weak self] in
            guard let self = self else {
                return
            }
            self.layoutIfNeeded()
            self.backgroundFadeView.alpha = 0
        }) { [weak self](_) in
            completion()
            self?.isDismissing = false
        }
    }
    
    
    private func animateConnectKey() {
        layoutIfNeeded()
        
        UIView.animateKeyframes(withDuration: 3, delay: 0, options: .repeat, animations: { [weak self] in
            guard let self = self else {
                return
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.2, animations: {
                self.keyImageViewTopConstraint.constant = self.configuration.keyImageViewTopConstraintConnectedConstant
                self.layoutIfNeeded()
            })
            UIView.addKeyframe(withRelativeStartTime: 0.2, relativeDuration: 0.4, animations: {
            })
            UIView.addKeyframe(withRelativeStartTime: 0.6, relativeDuration: 0.2, animations: {
                self.keyImageViewTopConstraint.constant = self.configuration.keyImageViewTopConstraintDisconnectedConstant
                self.layoutIfNeeded()
            })
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2, animations: {
            })
        }, completion: nil)
    }
    
    private func animateKeyConnected() {
        UIView.animateKeyframes(withDuration: 0.5, delay: 0, options: .beginFromCurrentState, animations: { [weak self] in
            guard let self = self else {
                return
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1, animations: {
                self.keyImageViewTopConstraint.constant = self.configuration.keyImageViewTopConstraintConnectedConstant
                self.layoutIfNeeded()
            })
        }, completion: nil)
    }
    
    private func pulsateBorderView(duration: TimeInterval) {
        borderView.alpha = 0
        
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: .repeat, animations: { [weak self] in
            guard let self = self else {
                return
            }
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1, animations: {
                self.borderView.alpha = 1
            })
            UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.8, animations: {
            })
            UIView.addKeyframe(withRelativeStartTime: 0.9, relativeDuration: 0.1, animations: {
                self.borderView.alpha = 0
            })
        }, completion: nil)
    }
    
    
    func updateInterfaceOrientation(orientation: UIInterfaceOrientation) {
        var rotationAngle: CGFloat = 0
        switch orientation {
        case .unknown:
            fallthrough
        case .portrait:
            break
        case .landscapeLeft:
            rotationAngle = CGFloat(Double.pi / 2)
        case .landscapeRight:
            rotationAngle = CGFloat(-Double.pi / 2)
        case .portraitUpsideDown:
            rotationAngle = CGFloat(Double.pi)
        @unknown default:
            fatalError()
        }
        keyActionContainerView.transform = CGAffineTransform(rotationAngle: rotationAngle)
    }
    
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        guard let delegate = delegate else {
            return
        }
        delegate.mfiKeyActionSheetDidDismiss(self)
    }
}
