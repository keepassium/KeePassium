//  KeePassium Password Manager
//  Copyright © 2018–2019 Andrei Popleteev <info@keepassium.com>
// 
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit
import KeePassiumLib

@IBDesignable
class ProgressOverlay: UIView {
    typealias UnresponsiveCancelHandler = () -> ()
    
    public var title: String? { 
        didSet { statusLabel.text = title }
    }
    
    public var isCancellable: Bool {
        get {
            return cancelButton.isEnabled
        }
        set {
            cancelButton.isEnabled = newValue
        }
    }
    
    public var isAnimating: Bool {
        get { return spinner.isAnimating }
        set {
            guard newValue != isAnimating else { return }
            if newValue {
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
            }
            updateSpinner()
        }
    }
    
    public var unresponsiveCancelHandler: UnresponsiveCancelHandler? 
    
    private var cancelPressCounter = 0
    private let cancelCountConsideredUnresponsive = 3
    
    private var spinner: UIActivityIndicatorView!
    private var statusLabel: UILabel!
    private var percentLabel: UILabel!
    private var progressView: UIProgressView!
    private var cancelButton: UIButton!
    private weak var progress: ProgressEx?
    
    private var animatingStatusConstraint: NSLayoutConstraint!
    private var staticStatusConstraint: NSLayoutConstraint!
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("ProgressOverlay.aDecoder not implemented")
    }
    
    static func addTo(_ parent: UIView, title: String, animated: Bool) -> ProgressOverlay {
        let overlay = ProgressOverlay(frame: parent.bounds)
        overlay.title = title
        if animated {
            overlay.alpha = 0.0
            parent.addSubview(overlay)
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
                overlay.alpha = 1.0
            }, completion: nil)
        } else {
            parent.addSubview(overlay)
        }
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.topAnchor.constraint(equalTo: parent.topAnchor, constant: 0).isActive = true
        overlay.bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: 0).isActive = true
        overlay.leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: 0).isActive = true
        overlay.trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: 0).isActive = true
        parent.layoutSubviews()
        return overlay
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
        updateSpinner()
        
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    
    func dismiss(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.alpha = 0.0
            },
            completion: completion)
    }
    
    private func setupViews() {
        if #available(iOS 13, *) {
            backgroundColor = UIColor.systemGroupedBackground
            spinner = UIActivityIndicatorView(style: .medium)
        } else {
            backgroundColor = UIColor.groupTableViewBackground
            spinner = UIActivityIndicatorView(style: .gray)
        }
        spinner.hidesWhenStopped = false
        spinner.isHidden = false
        spinner.alpha = 0.0
        addSubview(spinner)

        statusLabel = UILabel()
        statusLabel.text = ""
        statusLabel.numberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.font = UIFont.preferredFont(forTextStyle: .callout)
        addSubview(statusLabel)

        percentLabel = UILabel()
        percentLabel.text = ""
        percentLabel.numberOfLines = 1
        percentLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        addSubview(percentLabel)

        progressView = UIProgressView()
        progressView.progress = 0.0
        addSubview(progressView)
        
        cancelButton = UIButton(type: .system)
        cancelButton.setTitle(LString.actionCancel, for: .normal)
        cancelButton.addTarget(self, action: #selector(didPressCancel), for: .touchUpInside)
        addSubview(cancelButton)
    }
    
    private func setupLayout() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16.0).isActive = true
        progressView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16.0).isActive = true
        let widthConstraint = progressView.widthAnchor.constraint(equalToConstant: 400.0)
        widthConstraint.priority = .defaultHigh
        widthConstraint.isActive = true
        
        progressView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: 0).isActive = true
        progressView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0).isActive = true
        progressView.heightAnchor.constraint(equalToConstant: 2.0).isActive = true
        
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.leadingAnchor.constraint(equalTo: progressView.leadingAnchor, constant: 0).isActive = true
        spinner.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor).isActive = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -8.0).isActive = true
        statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: 8.0).isActive = true
        
        staticStatusConstraint = statusLabel.leadingAnchor.constraint(equalTo: progressView.leadingAnchor, constant: 8.0)
        staticStatusConstraint.priority = .defaultLow
        staticStatusConstraint.isActive = true
        animatingStatusConstraint = statusLabel.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 8.0)

        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.bottomAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 0).isActive = true
        percentLabel.trailingAnchor.constraint(equalTo: progressView.trailingAnchor, constant: -8.0).isActive = true

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8.0).isActive = true
        cancelButton.centerXAnchor.constraint(equalTo: progressView.centerXAnchor, constant: 0).isActive = true
    }
    
    private func updateSpinner() {
        let isConstraintActive = isAnimating
        let spinnerAlpha: CGFloat = isAnimating ? 1.0 : 0.0
        
        self.layoutIfNeeded()
        UIView.animate(
            withDuration: 0.3,
            delay: 0.0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: { [weak self] in
                guard let self = self else { return }
                self.spinner.alpha = spinnerAlpha
                self.animatingStatusConstraint.isActive = isConstraintActive
                self.setNeedsLayout()
                self.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    internal func update(with progress: ProgressEx) {
        statusLabel.text = progress.localizedDescription
        percentLabel.text = String(format: "%.0f%%", 100.0 * progress.fractionCompleted)
        progressView.setProgress(Float(progress.fractionCompleted), animated: true)
        cancelButton.isEnabled = cancelButton.isEnabled && progress.isCancellable && !progress.isCancelled
        isAnimating = progress.isIndeterminate
        self.progress = progress
    }
    
    @objc
    private func didPressCancel(_ sender: UIButton) {
        progress?.cancel()
        cancelPressCounter += 1
        if cancelPressCounter >= cancelCountConsideredUnresponsive {
            unresponsiveCancelHandler?()
            cancelPressCounter = 0
        }
    }
}
