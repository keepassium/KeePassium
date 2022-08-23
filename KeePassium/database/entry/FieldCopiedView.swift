//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import KeePassiumLib

protocol FieldCopiedViewDelegate: AnyObject {
    func didPressExport(for indexPath: IndexPath, from view: FieldCopiedView)
    func didPressCopyFieldReference(for indexPath: IndexPath, from view: FieldCopiedView)
}

final class FieldCopiedView: UIView {
    weak var delegate: FieldCopiedViewDelegate?
    
    private var indexPath: IndexPath!
    private weak var hidingTimer: Timer?
    
    private lazy var stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 32
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentCompressionResistancePriority(.defaultHigh + 1, for: .vertical)
        return stack
    }()
    
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .title3)
        label.textColor = .actionText
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.text = LString.titleCopiedToClipboard
        return label
    }()
    
    private lazy var exportButton: UIButton = {
        let button = UIButton(primaryAction: UIAction() {[weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressExport(for: self.indexPath, from: self)
        })
        button.tintColor = .actionText
        button.setImage(.get(.squareAndArrowUp), for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = LString.actionShare
        return button
    }()
    
    private lazy var copyFieldReferenceButton: UIButton = {
        let button = UIButton(primaryAction: UIAction() {[weak self] _ in
            guard let self = self else { return }
            self.delegate?.didPressCopyFieldReference(for: self.indexPath, from: self)
        })
        button.tintColor = .actionText
        button.setImage(.get(.arrowRightCircle), for: .normal)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .callout)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = LString.actionCopyFieldReference
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
        
        addSubview(stackView)
        stackView.addArrangedSubview(textLabel)
        stackView.addArrangedSubview(exportButton)
        stackView.addArrangedSubview(copyFieldReferenceButton)
        stackView.centerXAnchor
            .constraint(equalTo: layoutMarginsGuide.centerXAnchor)
            .activate()
        stackView.centerYAnchor
            .constraint(equalTo: layoutMarginsGuide.centerYAnchor)
            .activate()
        stackView.topAnchor
            .constraint(lessThanOrEqualTo: topAnchor)
            .activate()
        stackView.bottomAnchor
            .constraint(greaterThanOrEqualTo: bottomAnchor)
            .activate()
        stackView.trailingAnchor
            .constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor)
            .activate()
    }
    
    public func show(
        in tableView: UITableView,
        at indexPath: IndexPath,
        canReference: Bool
    ) {
        hide(animated: false)
        copyFieldReferenceButton.isHidden = !canReference
        
        guard let cell = tableView.cellForRow(at: indexPath) else { assertionFailure(); return }
        self.indexPath = indexPath
        
        cell.addSubview(self)
        self.topAnchor.constraint(equalTo: cell.topAnchor).activate()
        self.bottomAnchor.constraint(equalTo: cell.bottomAnchor).activate()
        self.leadingAnchor.constraint(equalTo: cell.leadingAnchor).activate()
        self.trailingAnchor.constraint(equalTo: cell.trailingAnchor).activate()

        self.alpha = 0.0
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: [.curveEaseOut, .allowUserInteraction] ,
            animations: { [weak self] in
                self?.backgroundColor = UIColor.actionTint
                self?.alpha = 0.9
            },
            completion: { [weak self] finished in
                guard let self = self else { return }
                tableView.deselectRow(at: indexPath, animated: false)
                self.hidingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) {
                    [weak self] _ in
                    self?.hide(animated: true)
                }
            }
        )
    }
    
    public func hide(animated: Bool) {
        hidingTimer?.invalidate()
        hidingTimer = nil
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
    
    @IBAction func didPressExport(_ sender: UIButton) {
        delegate?.didPressExport(for: indexPath, from: self)
    }
    
    @IBAction func didPressCopyFieldReference(_ sender: UIButton) {
        delegate?.didPressCopyFieldReference(for: indexPath, from: self)
    }
}
