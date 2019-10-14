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
class PremiumBenefitView: UIView {
    @IBInspectable
    public var title: String? {
        didSet { titleLabel.text = title }
    }
    @IBInspectable
    public var subtitle: String? {
        didSet { subtitleLabel.text = subtitle }
    }

    @IBInspectable
    public var image: UIImage? {
        didSet { imageView.image = image }
    }
    
    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var imageView: UIImageView!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupViews()
        setupLayout()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
    }
    
    private func setupViews() {
        if #available(iOS 13, *) {
            backgroundColor = UIColor.secondarySystemGroupedBackground
        } else {
            backgroundColor = UIColor.white
        }
        
        titleLabel = UILabel()
        titleLabel.text = "(Title)"
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.textColor = UIColor.primaryText
        titleLabel.backgroundColor = .clear
        addSubview(titleLabel)

        subtitleLabel = UILabel()
        subtitleLabel.text = "(Subtitle)"
        subtitleLabel.numberOfLines = 0
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.textColor = UIColor.primaryText
        subtitleLabel.backgroundColor = .clear
        addSubview(subtitleLabel)

        imageView = UIImageView(image: UIImage.kpIcon(forID: .apple))
        imageView.contentMode = .center
        addSubview(imageView)
    }
    
    private func setupLayout() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8.0).isActive = true
        imageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 0.0).isActive = true
        imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor, constant: 1.0).isActive = true
        imageView.widthAnchor.constraint(equalToConstant: 44.0).isActive = true
        
        titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8.0).isActive = true
        titleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8.0).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 8.0).isActive = true
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        subtitleLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8.0).isActive = true
        subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8.0).isActive = true
        subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8.0).isActive = true
        subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8.0).isActive = true
        subtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        let heightConstraint = heightAnchor.constraint(equalToConstant: 0.0)
        heightConstraint.priority = .defaultLow
        heightConstraint.isActive = true
    }
    
}
