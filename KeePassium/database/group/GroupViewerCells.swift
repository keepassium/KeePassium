//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
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
    @IBOutlet private weak var smartGroupIndicator: UIImageView!

    var isSmartGroup: Bool = false {
        didSet {
            setVisible(subtitleLabel, !isSmartGroup)
            setVisible(smartGroupIndicator, isSmartGroup)
        }
    }
    private func setVisible(_ stackChild: UIView, _ visible: Bool) {
        let isAlreadyVisible = !stackChild.isHidden
        guard visible != isAlreadyVisible else {
            return
        }
        stackChild.isHidden = !visible
    }

     override func awakeFromNib() {
        super.awakeFromNib()
        multipleSelectionBackgroundView = UIView()
    }
}

final class GroupViewerEntryCell: UITableViewCell {
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!

    @IBOutlet private weak var hStack: UIStackView!
    @IBOutlet private weak var showOTPButton: UIButton!
    @IBOutlet private weak var otpView: OTPView!
    @IBOutlet private weak var attachmentIndicator: UIImageView!
    @IBOutlet private weak var passkeyIndicator: UIImageView!

    var hasAttachments: Bool = false {
        didSet {
            attachmentIndicator.setVisible(hasAttachments)
        }
    }
    var hasPasskey: Bool = false {
        didSet {
            passkeyIndicator.setVisible(hasPasskey)
        }
    }

    var totpGenerator: TOTPGenerator? {
        didSet {
            refresh()
        }
    }

    var shouldHighlightOTP: Bool = false {
        didSet {
            refresh()
        }
    }

    var otpCopiedHandler: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        resetView()
        multipleSelectionBackgroundView = UIView()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetView()
    }

    private func resetView() {
        attachmentIndicator.isHidden = true
        showOTPButton.isHidden = true
        otpView.isHidden = true
        showOTPButton.setTitle("", for: .normal)
        showOTPButton.accessibilityLabel = LString.fieldOTP
        showOTPButton.setImage(.symbol(.clock), for: .normal)
        otpView.tapHandler = { [weak self] in
            self?.animateOTPValue(visible: false)
        }
    }

    public func refresh() {
        guard let totpGenerator = totpGenerator else {
            showOTPButton.setVisible(false)
            otpView.setVisible(false)
            return
        }

        if shouldHighlightOTP {
            otpView.normalColor = .actionTint
            showOTPButton.setVisible(false)
            otpView.setVisible(true)
        } else {
            otpView.normalColor = .primaryText
            if otpView.isHidden {
                showOTPButton.setVisible(true)
                return
            }
        }

        let otpValue = totpGenerator.generate()
        otpView.value = otpValue
        otpView.remainingTime = totpGenerator.remainingTime
        otpView.refresh()

        otpView.tapHandler = { [weak self] in
            guard let self else { return }
            if shouldHighlightOTP {
                copyOTP(otpValue)
            } else {
                animateOTPValue(visible: false)
            }
        }

        let justSwitched = !showOTPButton.isHidden
        if justSwitched {
            animateOTPValue(visible: true)
            copyOTP(otpValue)
        }
    }

    private func copyOTP(_ otpValue: String) {
        Clipboard.general.copyWithTimeout(otpValue)
        HapticFeedback.play(.copiedToClipboard)
        otpCopiedHandler?()
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
        otpView.setVisible(true)
        refresh()
    }
}
