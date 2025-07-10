//  KeePassium Password Manager
//  Copyright © 2018-2025 KeePassium Labs <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FieldCopiedViewDelegate: AnyObject {
    func didPressExport(for indexPath: IndexPath, from view: FieldCopiedView)
    func didPressCopyFieldReference(for indexPath: IndexPath, from view: FieldCopiedView)
    func didPressShowLargeType(for indexPath: IndexPath, from view: FieldCopiedView)
    func didPressShowQRCode(for indexPath: IndexPath, from view: FieldCopiedView)
}

final class FieldCopiedView: UIView {
    weak var delegate: FieldCopiedViewDelegate?

    private var indexPath: IndexPath!
    private weak var hidingTimer: Timer?
    private var wasUserInteractionEnabled: Bool?

    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        label.textColor = .actionText
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = LString.titleCopiedToClipboard
        label.textAlignment = .center
        return label
    }()

    private func actionButtonConfiguration(for action: ViewableFieldAction) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .actionText
        config.preferredSymbolConfigurationForImage = .init(textStyle: .body, scale: .large)
        config.imagePadding = 8
        config.image = action.icon
        return config
    }

    private lazy var exportButton: UIButton = {
        let button = UIButton(primaryAction: UIAction {[weak self] _ in
            guard let self else { return }
            self.delegate?.didPressExport(for: self.indexPath, from: self)
        })
        button.configuration = actionButtonConfiguration(for: .export)
        button.accessibilityLabel = LString.actionShare
        return button
    }()

    private lazy var copyFieldReferenceButton: UIButton = {
        let button = UIButton(primaryAction: UIAction {[weak self] _ in
            guard let self else { return }
            self.delegate?.didPressCopyFieldReference(for: self.indexPath, from: self)
        })
        button.configuration = actionButtonConfiguration(for: .copyReference)
        button.accessibilityLabel = LString.actionCopyFieldReference
        return button
    }()

    private lazy var showLargeTypeButton: UIButton = {
        let button = UIButton(primaryAction: UIAction {[weak self] _ in
            guard let self else { return }
            self.delegate?.didPressShowLargeType(for: self.indexPath, from: self)
        })
        button.configuration = actionButtonConfiguration(for: .showLargeType)
        button.tintColor = .actionText
        button.accessibilityLabel = LString.actionShowTextInLargeType
        return button
    }()

    private lazy var showQRCodeButton: UIButton = {
        let button = UIButton(primaryAction: UIAction {[weak self] _ in
            guard let self else { return }
            self.delegate?.didPressShowQRCode(for: self.indexPath, from: self)
        })
        button.configuration = actionButtonConfiguration(for: .showQRCode)
        button.tintColor = .actionText
        button.accessibilityLabel = LString.actionShowAsQRCode
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("Not implemented")
    }

    private func setupView() {
        backgroundColor = .actionTint
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(textLabel)
        addSubview(stackView)
        stackView.addArrangedSubview(copyFieldReferenceButton)
        stackView.addArrangedSubview(exportButton)
        stackView.addArrangedSubview(showLargeTypeButton)
        stackView.addArrangedSubview(showQRCodeButton)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
            stackView.topAnchor.constraint(lessThanOrEqualTo: topAnchor),
            stackView.bottomAnchor.constraint(greaterThanOrEqualTo: bottomAnchor),
            stackView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor, constant: -32),
            textLabel.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: 8),
            textLabel.topAnchor.constraint(lessThanOrEqualTo: topAnchor),
            textLabel.bottomAnchor.constraint(greaterThanOrEqualTo: bottomAnchor),
            textLabel.centerYAnchor.constraint(equalTo: layoutMarginsGuide.centerYAnchor),
        ])
        textLabel.centerXAnchor.constraint(equalTo: layoutMarginsGuide.centerXAnchor)
            .setPriority(.defaultHigh)
            .activate()
    }

    public func show(
        in cell: UITableViewCell,
        at indexPath: IndexPath,
        actions: any Collection<ViewableFieldAction>
    ) {
        self.indexPath = indexPath
        hide(animated: false)
        exportButton.isHidden = !actions.contains(.export)
        copyFieldReferenceButton.isHidden = !actions.contains(.copyReference)
        showLargeTypeButton.isHidden = !actions.contains(.showLargeType)
        showQRCodeButton.isHidden = !actions.contains(.showQRCode)

        wasUserInteractionEnabled = cell.accessoryView?.isUserInteractionEnabled
        cell.accessoryView?.isUserInteractionEnabled = false
        cell.addSubview(self)
        self.topAnchor.constraint(equalTo: cell.topAnchor).activate()
        self.bottomAnchor.constraint(equalTo: cell.bottomAnchor).activate()
        self.leadingAnchor.constraint(equalTo: cell.leadingAnchor).activate()
        self.trailingAnchor.constraint(equalTo: cell.trailingAnchor).activate()

        self.alpha = 0.0
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.9
            },
            completion: { [weak self] _ in
                guard let self else { return }
                self.hidingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    self?.hide(animated: true)
                }
            }
        )
    }

    public func hide(animated: Bool) {
        hidingTimer?.invalidate()
        hidingTimer = nil
        if let cell = superview as? UITableViewCell {
            cell.accessoryView?.isUserInteractionEnabled = wasUserInteractionEnabled ?? true
        }
        guard animated else {
            self.layer.removeAllAnimations()
            self.removeFromSuperview()
            return
        }
        UIView.animate(
            withDuration: 0.2,
            delay: 0.0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.0
            },
            completion: { [weak self] finished in
                if finished {
                    self?.removeFromSuperview()
                }
            }
        )
    }

    @IBAction private func didPressExport(_ sender: UIButton) {
        delegate?.didPressExport(for: indexPath, from: self)
    }

    @IBAction private func didPressCopyFieldReference(_ sender: UIButton) {
        delegate?.didPressCopyFieldReference(for: indexPath, from: self)
    }
}
