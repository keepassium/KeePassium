//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class GroupViewerGroupCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
}

final class GroupViewerEntryCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    @IBOutlet private weak var hStack: UIStackView!
    @IBOutlet private weak var showOTPButton: UIButton!
    @IBOutlet private weak var otpView: OTPView!
    @IBOutlet private weak var attachmentIndicator: UIImageView!
    
    var hasAttachments: Bool = false {
        didSet {
            setVisible(attachmentIndicator, hasAttachments)
        }
    }
    
    var totpGenerator: TOTPGenerator? {
        didSet {
            refresh()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        attachmentIndicator.isHidden = true
        showOTPButton.isHidden = true
        otpView.isHidden = true
        showOTPButton.setTitle("", for: .normal)
        showOTPButton.accessibilityLabel = "OTP"
        showOTPButton.setImage(UIImage.get(.clock), for: .normal)
        otpView.tapHandler = { [weak self] in
            self?.animateOTPValue(visible: false)
        }
    }
    
    private func setVisible(_ view: UIView, _ visible: Bool) {
        let isViewAlreadyVisible = !view.isHidden
        guard visible != isViewAlreadyVisible else {
            return
        }
        view.isHidden = !visible
    }
    
    public func refresh() {
        guard let totpGenerator = totpGenerator else {
            setVisible(showOTPButton, false)
            setVisible(otpView, false)
            return
        }
        if otpView.isHidden {
            setVisible(showOTPButton, true)
            return
        }

        otpView.value = totpGenerator.generate()
        otpView.remainingTime = totpGenerator.remainingTime
        otpView.refresh()
        
        let justSwitched = !showOTPButton.isHidden
        if justSwitched {
            animateOTPValue(visible: true)
        }
    }
    
    private func animateOTPValue(visible: Bool) {
        let animateValue = (otpView.isHidden != !visible)
        let animateButton = (showOTPButton.isHidden != visible)
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .beginFromCurrentState,
            animations: { [weak self] in
                guard let self = self else { return }
                if animateValue {
                    self.otpView.isHidden = !visible
                }
                if animateButton {
                    self.showOTPButton.isHidden = visible
                }
                self.hStack.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    @IBAction private func didPressShowOTP(_ sender: UIButton) {
        setVisible(otpView, true)
        refresh()
    }
}
