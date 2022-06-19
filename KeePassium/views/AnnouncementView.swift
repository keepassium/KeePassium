//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

struct AnnouncementItem {
    var title: String?
    var body: String?
    var actionTitle: String?
    var image: UIImage?
    var canBeClosed: Bool
    var onDidPressAction: ((AnnouncementView) -> Void)?
    var onDidPressClose: ((AnnouncementView) -> Void)?
}

final class AnnouncementView: UIView {
    typealias ActionHandler = (AnnouncementView) -> Void
    
    var onDidPressActionButton: ActionHandler? {
        didSet {
            setupSubviews()
        }
    }
    
    var onDidPressClose: ActionHandler? {
        didSet {
            setupSubviews()
        }
    }

    var title: String? {
        get { titleLabel.text }
        set {
            titleLabel.text = newValue
            setupSubviews()
        }
    }
    var body: String? {
        get { bodyLabel.text }
        set {
            bodyLabel.text = newValue
            setupSubviews()
        }
    }
    var image: UIImage? {
        get { imageView.image }
        set {
            imageView.image = newValue
            setupSubviews()
        }
    }
    
    var actionTitle: String? {
        get { actionButton.currentTitle }
        set {
            actionButton.setTitle(newValue, for: .normal)
            setupSubviews()
        }
    }
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "info.circle")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 29).activate()
        imageView.heightAnchor.constraint(equalToConstant: 29).activate()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .callout)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .close, primaryAction: UIAction {[weak self] _ in
            guard let self = self else { return }
            self.onDidPressClose?(self)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 25).activate()
        button.heightAnchor.constraint(equalToConstant: 25).activate()
        return button
    }()
    
    private lazy var actionButton: UIButton = {
        let button = UIButton(primaryAction: UIAction() {[weak self] _ in
            guard let self = self else { return }
            self.onDidPressActionButton?(self)
        })
        button.contentHorizontalAlignment = UIControl.ContentHorizontalAlignment.leading
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        button.setTitleColor(.actionTint, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .quaternarySystemFill
        layer.cornerRadius = 10
        layer.borderColor = UIColor.secondarySystemFill.cgColor
        layer.borderWidth = 1

        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }
    
    public func apply(_ announcement: AnnouncementItem) {
        title = announcement.title
        body = announcement.body
        actionTitle = announcement.actionTitle
        image = announcement.image
        onDidPressClose = announcement.onDidPressClose
        onDidPressActionButton = announcement.onDidPressAction
    }
    
    private func setupSubviews() {
        let existingSubviews = subviews
        existingSubviews.forEach {
            $0.removeFromSuperview()
        }

        let hasImage = image != nil
        let hasTitle = !(title?.isEmpty ?? true)
        let hasBody = !(body?.isEmpty ?? true)
        let hasButton = !(actionButton.currentTitle?.isEmpty ?? true) && (onDidPressActionButton != nil)
        let canBeClosed = onDidPressClose != nil
        
        var stackedViews = [UIView]()
        
        let imageTrailingAnchor: NSLayoutXAxisAnchor
        let imageTrailingAnchorConstant: CGFloat
        if hasImage {
            addSubview(imageView)
            imageView.leadingAnchor
                .constraint(equalTo: layoutMarginsGuide.leadingAnchor, constant: 8)
                .activate()
            imageView.topAnchor
                .constraint(greaterThanOrEqualTo: layoutMarginsGuide.topAnchor)
                .activate()
            imageView.centerYAnchor
                .constraint(equalTo: layoutMarginsGuide.centerYAnchor)
                .setPriority(.defaultHigh)
                .activate()
            imageTrailingAnchor = imageView.trailingAnchor
            imageTrailingAnchorConstant = 16
        } else {
            imageTrailingAnchor = layoutMarginsGuide.leadingAnchor
            imageTrailingAnchorConstant = 8
        }
        
        let titleBottomAnchor: NSLayoutYAxisAnchor
        let titleBottomAnchorConstant: CGFloat
        if hasTitle {
            addSubview(titleLabel)
            stackedViews.append(titleLabel)
            titleLabel.topAnchor
                .constraint(equalTo: layoutMarginsGuide.topAnchor)
                .activate()
            titleLabel.leadingAnchor
                .constraint(equalTo: imageTrailingAnchor, constant: imageTrailingAnchorConstant)
                .activate()
            titleLabel.trailingAnchor
                .constraint(greaterThanOrEqualTo: layoutMarginsGuide.trailingAnchor, constant: -8)
                .setPriority(.defaultHigh)
                .activate()
            titleLabel.bottomAnchor
                .constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
                .activate()
            titleBottomAnchor = titleLabel.bottomAnchor
            titleBottomAnchorConstant = 8
        } else {
            titleBottomAnchor = layoutMarginsGuide.topAnchor
            titleBottomAnchorConstant = 0
        }
        
        let bodyBottomAnchor: NSLayoutYAxisAnchor
        let bodyBottomAnchorConstant: CGFloat
        if hasBody {
            addSubview(bodyLabel)
            stackedViews.append(bodyLabel)
            bodyLabel.topAnchor
                .constraint(equalTo: titleBottomAnchor, constant: titleBottomAnchorConstant)
                .activate()
            bodyLabel.leadingAnchor
                .constraint(equalTo: imageTrailingAnchor, constant: imageTrailingAnchorConstant)
                .activate()
            bodyLabel.trailingAnchor
                .constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor, constant: -8)
                .activate()
            bodyLabel.bottomAnchor
                .constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
                .activate()
            bodyBottomAnchor = bodyLabel.bottomAnchor
            bodyBottomAnchorConstant = 8
        } else {
            bodyBottomAnchor = titleBottomAnchor
            bodyBottomAnchorConstant = 0
        }
        
        if hasButton {
            addSubview(actionButton)
            stackedViews.append(actionButton)
            actionButton.topAnchor
                .constraint(equalTo: bodyBottomAnchor, constant: bodyBottomAnchorConstant)
                .activate()
            actionButton.leadingAnchor
                .constraint(equalTo: imageTrailingAnchor, constant: imageTrailingAnchorConstant)
                .activate()
            actionButton.trailingAnchor
                .constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -8)
                .activate()
            actionButton.bottomAnchor
                .constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
                .activate()
            actionButton.titleLabel?.numberOfLines = 0
        } else {
            bodyBottomAnchor
                .constraint(lessThanOrEqualTo: layoutMarginsGuide.bottomAnchor)
                .activate()
        }
    
        if canBeClosed {
            addSubview(closeButton)
            closeButton.topAnchor
                .constraint(equalTo: layoutMarginsGuide.topAnchor)
                .activate()
            closeButton.trailingAnchor
                .constraint(equalTo: layoutMarginsGuide.trailingAnchor)
                .activate()

            let closeButtonLeadingAnchor = stackedViews.first?.trailingAnchor ?? imageTrailingAnchor
            closeButton.leadingAnchor
                .constraint(equalTo: closeButtonLeadingAnchor, constant: 8)
                .activate()
            
            let closeButtonBottomGuide: NSLayoutYAxisAnchor
            if stackedViews.count > 1 {
                closeButtonBottomGuide = stackedViews[1].topAnchor
            } else {
                closeButtonBottomGuide = layoutMarginsGuide.bottomAnchor
            }
            closeButton.bottomAnchor
                .constraint(lessThanOrEqualTo: closeButtonBottomGuide)
                .activate()
        }
    }
}
