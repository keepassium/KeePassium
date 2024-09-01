//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

final class OTPView: UILabel {
    private let warningInterval: TimeInterval = 10

    public var normalColor: UIColor = .primaryText {
        didSet { refresh() }
    }
    public var expiringColor: UIColor = .warningMessage {
        didSet { refresh() }
    }

    public var value: String = "" {
        didSet {
            formattedValue = OTPCodeFormatter.decorate(otpCode: value)
            refresh()
        }
    }

    public var remainingTime: TimeInterval = 0.0 {
        didSet { refresh() }
    }
    public var edgeInsets = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)

    public var tapHandler: (() -> Void)?

    private var formattedValue: String = ""

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: edgeInsets))
    }

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += edgeInsets.left + edgeInsets.right
        size.height += edgeInsets.top + edgeInsets.bottom
        return size
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
        font = UIFont.preferredFont(forTextStyle: .title3)
        textColor = normalColor
        text = nil
        contentMode = .center
        textAlignment = .center
        lineBreakMode = .byTruncatingTail

        let tapGestureRecognizer = UITapGestureRecognizer(
            target: self,
            action: #selector(didTapValue(gestureRecognizer:))
        )
        self.addGestureRecognizer(tapGestureRecognizer)
        self.isUserInteractionEnabled = true
    }

    public func refresh() {
        text = formattedValue
        guard remainingTime <= warningInterval else {
            layer.removeAnimation(forKey: "warning")
            layer.shadowRadius = 0
            layer.shadowOpacity = 0
            layer.opacity = 1
            textColor = normalColor
            return
        }

        let ticToc = remainingTime.truncatingRemainder(dividingBy: 2) - 1
        warningAnimation2(ticToc)
    }

    private func warningAnimation1(_ ticToc: Double) {
        let scale: Double
        if ticToc > 0 {
            scale = 1.0
        } else {
            scale = 0.9
        }

        let duration = (remainingTime / warningInterval) * 0.4 + 0.1
        let animation = CABasicAnimation(keyPath: "transform.scale")
        animation.autoreverses = true
        animation.repeatDuration = 1.0
        animation.duration = duration
        animation.toValue = scale
        layer.add(animation, forKey: "warning")
    }

    private func warningAnimation2(_ ticToc: Double) {
        let opacity: Float = ticToc > 0 ? 0.7 : 0

        textColor = expiringColor
        layer.shadowOffset = .zero
        layer.masksToBounds = false
        layer.shadowRadius = 2
        layer.shadowColor = expiringColor.cgColor
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { [weak self] in
                self?.layer.shadowOpacity = opacity
            },
            completion: nil
        )
    }

    @objc
    private func didTapValue(gestureRecognizer: UITapGestureRecognizer) {
        if gestureRecognizer.state == .ended {
            tapHandler?()
        }
    }
}
