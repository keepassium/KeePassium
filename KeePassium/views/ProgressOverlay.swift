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
    
    public var unresponsiveCancelHandler: UnresponsiveCancelHandler? 
    
    private var cancelPressCounter = 0
    private let cancelCountConsideredUnresponsive = 3
    
    private var statusLabel: UILabel!
    private var percentLabel: UILabel!
    private var progressView: UIProgressView!
    private var cancelButton: UIButton!
    private weak var progress: ProgressEx?
    
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
        return overlay
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
        
        translatesAutoresizingMaskIntoConstraints = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    
    func dismiss(animated: Bool, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.alpha = 0.0
            },
            completion: completion)
    }
    
    private func setupViews() {
        backgroundColor = UIColor.groupTableViewBackground

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
        
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.leftAnchor.constraint(equalTo: progressView.leftAnchor, constant: 0).isActive = true
        statusLabel.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -8.0).isActive = true
        statusLabel.rightAnchor.constraint(lessThanOrEqualTo: progressView.rightAnchor, constant: 0).isActive = true

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.leftAnchor.constraint(equalTo: progressView.leftAnchor, constant: 0).isActive = true
        statusLabel.bottomAnchor.constraint(equalTo: progressView.topAnchor, constant: -8.0).isActive = true
        statusLabel.rightAnchor.constraint(lessThanOrEqualTo: percentLabel.leftAnchor, constant: 8.0).isActive = true

        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.bottomAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 0).isActive = true
        percentLabel.rightAnchor.constraint(equalTo: progressView.rightAnchor, constant: -8.0).isActive = true

        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 8.0).isActive = true
        cancelButton.centerXAnchor.constraint(equalTo: progressView.centerXAnchor, constant: 0).isActive = true
    }
    
    internal func update(with progress: ProgressEx) {
        percentLabel.text = String(format: "%.0f%%", 100.0 * progress.fractionCompleted)
        progressView.setProgress(Float(progress.fractionCompleted), animated: true)
        cancelButton.isEnabled = cancelButton.isEnabled && progress.isCancellable && !progress.isCancelled
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
