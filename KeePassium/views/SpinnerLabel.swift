//  KeePassium Password Manager
//  Copyright © 2018-2022 Andrei Popleteev <info@keepassium.com>
//
//  This program is free software: you can redistribute it and/or modify it
//  under the terms of the GNU General Public License version 3 as published
//  by the Free Software Foundation: https://www.gnu.org/licenses/).
//  For commercial licensing, please contact the author.

import UIKit

final class SpinnerLabel: UIStackView {
    public var isAnimating: Bool {
        get { !spinner.isHidden }
        set {
            showSpinner(newValue, animated: false)
        }
    }
    
    public func showSpinner(_ visible: Bool, animated: Bool) {
        let alreadyVisible = !spinner.isHidden
        guard visible != alreadyVisible else {
            return
        }
        
        guard animated else {
            spinner.isHidden = !visible
            return
        }
        
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: .curveLinear,
            animations: {
                self.spinner.isHidden = !visible
                self.layoutIfNeeded()
            },
            completion: nil
        )
    }
    
    public lazy var spinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = false
        spinner.isHidden = true
        return spinner
    }()
    
    public lazy var label: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .primaryText
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        axis = .horizontal
        alignment = .center
        distribution = .fill
        spacing = 8
        addArrangedSubview(spinner)
        addArrangedSubview(label)
    }
}
