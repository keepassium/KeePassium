//  KeePassium Password Manager
//  Copyright © 2018–2024 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class ErrorMessageView: UIView {

    public struct Action {
        typealias Handler = () -> Void

        let title: String
        let isLink: Bool
        let handler: Handler
        init(title: String, isLink: Bool = false, handler: @escaping Handler) {
            self.title = title
            self.isLink = isLink
            self.handler = handler
        }
    }

    var message: String? {
        get { messageLabel.text }
        set {
            messageLabel.text = newValue
            setupView()
        }
    }
    var action: Action? {
        didSet {
            setupView()
        }
    }

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = .symbol(.exclamationMarkTriangle)
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body, scale: .large)
        imageView.tintColor = .label
        imageView.contentMode = .center
        imageView.clipsToBounds = false
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .callout)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var actionButton: UIButton = {
        let button = UIButton(primaryAction: UIAction { [weak self] _ in
            self?.didPressActionButton()
        })
        button.contentHorizontalAlignment = UIControl.ContentHorizontalAlignment.leading

        var config = UIButton.Configuration.plain()
        config.titlePadding = 0
        config.contentInsets = .init(top: 8, leading: 0, bottom: 8, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var outgoing = $0
            outgoing.font = .preferredFont(forTextStyle: .callout)
            return outgoing
        }
        button.configuration = config

        button.setTitleColor(.actionTint, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var zeroHeightConstraint: NSLayoutConstraint = {
        return heightAnchor.constraint(equalToConstant: 0).setPriority(.defaultHigh)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .secondarySystemFill
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 1.0
        layer.cornerRadius = 5
        clipsToBounds = true

        let existingSubviews = subviews
        existingSubviews.forEach {
            $0.removeFromSuperview()
        }

        self.addSubview(imageView)
        imageView.centerYAnchor
            .constraint(equalTo: layoutMarginsGuide.centerYAnchor, constant: 0)
            .activate()
        imageView.leadingAnchor
            .constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 0)
            .activate()
        imageView.widthAnchor
            .constraint(greaterThanOrEqualToConstant: 36)
            .activate()
        imageView.heightAnchor
            .constraint(greaterThanOrEqualToConstant: 29)
            .activate()

        self.addSubview(messageLabel)
        self.accessibilityElements = [messageLabel]
        messageLabel.topAnchor
            .constraint(equalTo: layoutMarginsGuide.topAnchor, constant: 0)
            .activate()
        messageLabel.leadingAnchor
            .constraint(equalTo: imageView.trailingAnchor, constant: 8)
            .activate()
        messageLabel.trailingAnchor
            .constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor, constant: 0)
            .activate()

        if let action {
            self.addSubview(actionButton)
            actionButton.topAnchor
                .constraint(equalTo: messageLabel.bottomAnchor, constant: 0) 
                .activate()
            actionButton.leadingAnchor
                .constraint(equalTo: imageView.trailingAnchor, constant: 8)
                .activate()
            actionButton.trailingAnchor
                .constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor, constant: 0)
                .activate()
            actionButton.bottomAnchor
                .constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 8) 
                .activate()
            actionButton.setTitle(action.title, for: .normal)

            if action.isLink {
                var buttonConfig = actionButton.configuration
                buttonConfig?.imagePlacement = .trailing
                buttonConfig?.imagePadding = 4
                buttonConfig?.image = .symbol(.externalLink)
                buttonConfig?.preferredSymbolConfigurationForImage = .init(scale: .small)
                actionButton.configuration = buttonConfig
            } else {
                actionButton.configuration?.image = nil
            }
            self.accessibilityElements?.append(actionButton)
        } else {
            messageLabel.bottomAnchor
                .constraint(equalTo: layoutMarginsGuide.bottomAnchor, constant: 0)
                .activate()
        }
        self.isAccessibilityElement = false 
    }

    private func didPressActionButton() {
        action?.handler()
    }

    public func show(animated: Bool) {
        if animated {
            superview?.layoutIfNeeded()
            UIView.animate(withDuration: 0.3) { [self] in
                isHidden = false
                alpha = 1.0
                zeroHeightConstraint.isActive = false
                superview?.layoutIfNeeded()
            }
        } else {
            alpha = 1.0
            isHidden = false
            zeroHeightConstraint.isActive = false
        }
    }

    public func hide(animated: Bool) {
        if animated {
            superview?.layoutIfNeeded()
            UIView.animate(withDuration: 0.3) { [self] in
                isHidden = true
                alpha = 0
                zeroHeightConstraint.isActive = true
                superview?.layoutIfNeeded()
            }
        } else {
            isHidden = true
            alpha = 0
            zeroHeightConstraint.isActive = true
        }
    }
}
